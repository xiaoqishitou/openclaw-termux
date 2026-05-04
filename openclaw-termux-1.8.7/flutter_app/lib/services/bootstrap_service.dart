import 'dart:io';
import 'package:dio/dio.dart';
import '../constants.dart';
import '../models/setup_state.dart';
import 'native_bridge.dart';

class BootstrapService {
  final Dio _dio = Dio();

  void _updateSetupNotification(String text, {int progress = -1}) {
    try {
      NativeBridge.updateSetupNotification(text, progress: progress);
    } catch (_) {}
  }

  void _stopSetupService() {
    try {
      NativeBridge.stopSetupService();
    } catch (_) {}
  }

  Future<SetupState> checkStatus() async {
    try {
      final complete = await NativeBridge.isBootstrapComplete();
      if (complete) {
        return const SetupState(
          step: SetupStep.complete,
          progress: 1.0,
          message: 'Setup complete',
        );
      }
      return const SetupState(
        step: SetupStep.checkingStatus,
        progress: 0.0,
        message: 'Setup required',
      );
    } catch (e) {
      return SetupState(
        step: SetupStep.error,
        error: 'Failed to check status: $e',
      );
    }
  }

  Future<void> runFullSetup({
    required void Function(SetupState) onProgress,
  }) async {
    try {
      // 检测是否在模拟器上运行
      final isEmulator = await NativeBridge.isEmulator();
      if (isEmulator) {
        onProgress(const SetupState(
          step: SetupStep.error,
          error: '模拟器不支持 PRoot\n\n'
              'OpenClaw 依赖 PRoot 运行 Linux 环境，而模拟器（尤其是 x86/x86_64 架构）'
              '通常禁用了 ptrace 系统调用，导致 PRoot 无法工作。\n\n'
              '解决方案：\n'
              '1. 使用真机（ARM64 设备）运行此应用\n'
              '2. 如果使用 Android Studio 模拟器，尝试使用 ARM64 镜像\n'
              '3. 在模拟器设置中启用 "Emulated Performance" 的 "Auto" 或 "Hardware" 选项',
        ));
        return;
      }

      // Start foreground service to keep app alive during setup
      try {
        await NativeBridge.startSetupService();
      } catch (_) {} // Non-fatal if service fails to start

      // Step 0: Setup directories
      onProgress(const SetupState(
        step: SetupStep.checkingStatus,
        progress: 0.0,
        message: 'Setting up directories...',
      ));
      _updateSetupNotification('Setting up directories...', progress: 2);
      try { await NativeBridge.setupDirs(); } catch (_) {}
      try { await NativeBridge.writeResolv(); } catch (_) {}

      // Step 1: Download rootfs
      final arch = await NativeBridge.getArch();
      final rootfsUrl = AppConstants.getRootfsUrl(arch);
      final filesDir = await NativeBridge.getFilesDir();

      // Direct Dart fallback: ensure config dir + resolv.conf exist (#40).
      const resolvContent = 'nameserver 8.8.8.8\nnameserver 8.8.4.4\n';
      try {
        final configDir = '$filesDir/config';
        final resolvFile = File('$configDir/resolv.conf');
        if (!resolvFile.existsSync()) {
          Directory(configDir).createSync(recursive: true);
          resolvFile.writeAsStringSync(resolvContent);
        }
        // Also write into rootfs /etc/ so DNS works even if bind-mount fails
        final rootfsResolv = File('$filesDir/rootfs/ubuntu/etc/resolv.conf');
        if (!rootfsResolv.existsSync()) {
          rootfsResolv.parent.createSync(recursive: true);
          rootfsResolv.writeAsStringSync(resolvContent);
        }
      } catch (_) {}
      final tarPath = '$filesDir/tmp/ubuntu-rootfs.tar.gz';

      // Try to use bundled rootfs asset first (offline-friendly)
      final rootfsAssetName = _getBundledRootfsAsset(arch);
      bool usedBundledRootfs = false;
      try {
        _updateSetupNotification('Preparing Ubuntu rootfs...', progress: 5);
        onProgress(const SetupState(
          step: SetupStep.downloadingRootfs,
          progress: 0.0,
          message: 'Preparing Ubuntu rootfs (bundled)...',
        ));
        final copied = await NativeBridge.copyBundledAsset(rootfsAssetName, tarPath);
        if (copied) {
          usedBundledRootfs = true;
          onProgress(const SetupState(
            step: SetupStep.downloadingRootfs,
            progress: 1.0,
            message: 'Ubuntu rootfs ready (from bundle)',
          ));
        }
      } catch (_) {}

      if (!usedBundledRootfs) {
        _updateSetupNotification('Downloading Ubuntu rootfs...', progress: 5);
        onProgress(const SetupState(
          step: SetupStep.downloadingRootfs,
          progress: 0.0,
          message: 'Downloading Ubuntu rootfs...',
        ));

        await _dio.download(
        rootfsUrl,
        tarPath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            final mb = (received / 1024 / 1024).toStringAsFixed(1);
            final totalMb = (total / 1024 / 1024).toStringAsFixed(1);
            // Map download to 5-30% of overall progress
            final notifProgress = 5 + (progress * 25).round();
            _updateSetupNotification('Downloading rootfs: $mb / $totalMb MB', progress: notifProgress);
            onProgress(SetupState(
              step: SetupStep.downloadingRootfs,
              progress: progress,
              message: 'Downloading: $mb MB / $totalMb MB',
            ));
          }
        },
      );
      } // end if !usedBundledRootfs

      // Step 2: Extract rootfs (30-45%)
      _updateSetupNotification('Extracting rootfs...', progress: 30);
      onProgress(const SetupState(
        step: SetupStep.extractingRootfs,
        progress: 0.0,
        message: 'Extracting rootfs (this takes a while)...',
      ));
      await NativeBridge.extractRootfs(tarPath);
      onProgress(const SetupState(
        step: SetupStep.extractingRootfs,
        progress: 1.0,
        message: 'Rootfs extracted',
      ));

      // Install bionic bypass + cwd-fix + node-wrapper BEFORE using node.
      // The wrapper patches process.cwd() which returns ENOSYS in proot.
      await NativeBridge.installBionicBypass();

      // Step 3: Install Node.js (45-80%)
      // Fix permissions inside proot (Java extraction may miss execute bits)
      _updateSetupNotification('Fixing rootfs permissions...', progress: 45);
      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.0,
        message: 'Fixing rootfs permissions...',
      ));
      // Blanket recursive chmod on all bin/lib directories.
      // Java tar extraction loses execute bits; dpkg needs tar, xz,
      // gzip, rm, mv, etc. — easier to fix everything than enumerate.
      await NativeBridge.runInProot(
        'chmod -R 755 /usr/bin /usr/sbin /bin /sbin '
        '/usr/local/bin /usr/local/sbin 2>/dev/null; '
        'chmod -R +x /usr/lib/apt/ /usr/lib/dpkg/ /usr/libexec/ '
        '/var/lib/dpkg/info/ /usr/share/debconf/ 2>/dev/null; '
        'chmod 755 /lib/*/ld-linux-*.so* /usr/lib/*/ld-linux-*.so* 2>/dev/null; '
        'mkdir -p /var/lib/dpkg/updates /var/lib/dpkg/triggers; '
        'echo permissions_fixed',
      );

      // --- Install base packages via apt-get (like Termux proot-distro) ---
      // Now that our proot matches Termux exactly (env -i, clean host env,
      // proper flags), dpkg works normally. No need for Java-side deb
      // extraction — let dpkg+tar handle it inside proot like Termux does.
      _updateSetupNotification('Updating package lists...', progress: 48);
      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.1,
        message: 'Updating package lists...',
      ));
      await NativeBridge.runInProot('apt-get update -y');

      _updateSetupNotification('Installing base packages...', progress: 52);
      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.15,
        message: 'Installing base packages...',
      ));
      // ca-certificates: HTTPS for npm/git
      // git: openclaw has git deps (@whiskeysockets/libsignal-node)
      // python3, make, g++: node-gyp needs these to compile native addons
      //   (npm's bundled node-gyp runs as a JS module, not a spawned process,
      //    so proot-compat.js spawn mock can't intercept it)
      // dpkg extracts via tar inside proot — permissions are correct.
      // Post-install scripts (update-ca-certificates) run automatically.
      // Pre-configure tzdata to avoid interactive continent/timezone prompt
      // (tzdata is a dependency of python3 and ignores DEBIAN_FRONTEND on
      // first install if no timezone is pre-set).
      await NativeBridge.runInProot(
        'ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime && '
        'echo "Etc/UTC" > /etc/timezone',
      );
      await NativeBridge.runInProot(
        'apt-get install -y --no-install-recommends '
        'ca-certificates git python3 make g++ curl wget',
      );

      // Git config (.gitconfig) is written by installBionicBypass() on the
      // Java side — directly to $rootfsDir/root/.gitconfig — rewrites
      // SSH→HTTPS for npm git deps (no SSH keys in proot).

      // --- Install Node.js via binary tarball ---
      // Download directly from nodejs.org (bypasses curl/gpg/NodeSource
      // which fail inside proot). Includes node + npm + corepack.
      final nodeTarUrl = AppConstants.getNodeTarballUrl(arch);
      final nodeTarPath = '$filesDir/tmp/nodejs.tar.xz';

      // Try to use bundled Node.js asset first (offline-friendly)
      final nodeAssetName = _getBundledNodeAsset(arch);
      bool usedBundledNode = false;
      try {
        onProgress(const SetupState(
          step: SetupStep.installingNode,
          progress: 0.3,
          message: 'Preparing Node.js ${AppConstants.nodeVersion} (bundled)...',
        ));
        _updateSetupNotification('Preparing Node.js...', progress: 55);
        final copied = await NativeBridge.copyBundledAsset(nodeAssetName, nodeTarPath);
        if (copied) {
          usedBundledNode = true;
          onProgress(const SetupState(
            step: SetupStep.installingNode,
            progress: 0.7,
            message: 'Node.js ready (from bundle)',
          ));
        }
      } catch (_) {}

      if (!usedBundledNode) {
        onProgress(const SetupState(
          step: SetupStep.installingNode,
          progress: 0.3,
          message: 'Downloading Node.js ${AppConstants.nodeVersion}...',
        ));
        _updateSetupNotification('Downloading Node.js...', progress: 55);
        await _dio.download(
          nodeTarUrl,
          nodeTarPath,
          onReceiveProgress: (received, total) {
            if (total > 0) {
              final progress = 0.3 + (received / total) * 0.4;
              final mb = (received / 1024 / 1024).toStringAsFixed(1);
              final totalMb = (total / 1024 / 1024).toStringAsFixed(1);
              // Map Node download to 55-70% of overall
              final notifProgress = 55 + ((received / total) * 15).round();
              _updateSetupNotification('Downloading Node.js: $mb / $totalMb MB', progress: notifProgress);
              onProgress(SetupState(
                step: SetupStep.installingNode,
                progress: progress,
                message: 'Downloading Node.js: $mb MB / $totalMb MB',
              ));
            }
          },
        );
      } // end if !usedBundledNode

      _updateSetupNotification('Extracting Node.js...', progress: 72);
      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.75,
        message: 'Extracting Node.js...',
      ));
      await NativeBridge.extractNodeTarball(nodeTarPath);

      _updateSetupNotification('Verifying Node.js...', progress: 78);
      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.9,
        message: 'Verifying Node.js...',
      ));
      // node-wrapper.js patches broken proot syscalls before loading npm.
      // /usr/local/bin is on PATH, so node finds the tarball's npm.
      const wrapper = '/root/.openclaw/node-wrapper.js';
      const nodeRun = 'node $wrapper';
      // npm from nodejs.org tarball is at /usr/local/lib/node_modules/npm
      const npmCli = '/usr/local/lib/node_modules/npm/bin/npm-cli.js';
      await NativeBridge.runInProot(
        'node --version && $nodeRun $npmCli --version',
      );
      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 1.0,
        message: 'Node.js installed',
      ));

      // Step 4: Install OpenClaw (80-98%)
      _updateSetupNotification('Installing OpenClaw...', progress: 82);
      onProgress(const SetupState(
        step: SetupStep.installingOpenClaw,
        progress: 0.0,
        message: 'Installing OpenClaw (this may take a few minutes)...',
      ));

      // Try to use bundled openclaw tarball first (offline-friendly)
      final openclawTarPath = '$filesDir/tmp/openclaw-2026.5.2.tgz';
      bool usedBundledOpenclaw = false;
      try {
        _updateSetupNotification('Preparing OpenClaw...', progress: 82);
        final copied = await NativeBridge.copyBundledAsset('assets/bundle/openclaw-2026.5.2.tgz', openclawTarPath);
        if (copied) {
          usedBundledOpenclaw = true;
          onProgress(const SetupState(
            step: SetupStep.installingOpenClaw,
            progress: 0.1,
            message: 'Installing OpenClaw from bundle...',
          ));
        }
      } catch (_) {}

      // Install openclaw — fork/exec works now with our Termux-matching proot.
      if (usedBundledOpenclaw) {
        await NativeBridge.runInProot(
          '$nodeRun $npmCli install -g "$openclawTarPath"',
          timeout: 1800,
        );
      } else {
        await NativeBridge.runInProot(
          '$nodeRun $npmCli install -g openclaw',
          timeout: 1800,
        );
      }

      _updateSetupNotification('Creating bin wrappers...', progress: 92);
      onProgress(const SetupState(
        step: SetupStep.installingOpenClaw,
        progress: 0.7,
        message: 'Creating bin wrappers...',
      ));
      // npm global install creates symlinks for bin entries, but symlinks
      // can fail silently in proot. Create shell wrappers from Java side
      // (reads package.json directly from rootfs filesystem — no escaping).
      await NativeBridge.createBinWrappers('openclaw');

      _updateSetupNotification('Verifying OpenClaw...', progress: 96);
      onProgress(const SetupState(
        step: SetupStep.installingOpenClaw,
        progress: 0.9,
        message: 'Verifying OpenClaw...',
      ));
      await NativeBridge.runInProot('openclaw --version || echo openclaw_installed');
      onProgress(const SetupState(
        step: SetupStep.installingOpenClaw,
        progress: 1.0,
        message: 'OpenClaw installed',
      ));

      // Step 5: Bionic Bypass already installed (before node verification)
      _updateSetupNotification('Setup complete!', progress: 100);
      onProgress(const SetupState(
        step: SetupStep.configuringBypass,
        progress: 1.0,
        message: 'Bionic Bypass configured',
      ));

      // Done
      _stopSetupService();
      onProgress(const SetupState(
        step: SetupStep.complete,
        progress: 1.0,
        message: 'Setup complete! Ready to start the gateway.',
      ));
    } on DioException catch (e) {
      _stopSetupService();
      onProgress(SetupState(
        step: SetupStep.error,
        error: 'Download failed: ${e.message}. Check your internet connection.',
      ));
    } catch (e) {
      _stopSetupService();
      onProgress(SetupState(
        step: SetupStep.error,
        error: 'Setup failed: $e',
      ));
    }
  }

  static String _getBundledRootfsAsset(String arch) {
    switch (arch) {
      case 'aarch64':
        return 'assets/bundle/ubuntu-base-24.04-arm64.tar.gz';
      case 'arm':
        return 'assets/bundle/ubuntu-base-24.04-armhf.tar.gz';
      case 'x86_64':
        return 'assets/bundle/ubuntu-base-24.04-amd64.tar.gz';
      default:
        return 'assets/bundle/ubuntu-base-24.04-arm64.tar.gz';
    }
  }

  static String _getBundledNodeAsset(String arch) {
    switch (arch) {
      case 'aarch64':
        return 'assets/bundle/node-v${AppConstants.nodeVersion}-linux-arm64.tar.xz';
      case 'arm':
        return 'assets/bundle/node-v${AppConstants.nodeVersion}-linux-armv7l.tar.xz';
      case 'x86_64':
        return 'assets/bundle/node-v${AppConstants.nodeVersion}-linux-x64.tar.xz';
      default:
        return 'assets/bundle/node-v${AppConstants.nodeVersion}-linux-arm64.tar.xz';
    }
  }
}
