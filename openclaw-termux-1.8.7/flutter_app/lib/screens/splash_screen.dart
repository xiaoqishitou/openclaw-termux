import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app.dart';
import '../constants.dart';
import '../services/native_bridge.dart';
import '../services/preferences_service.dart';
import 'setup_wizard_screen.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  String _status = '正在加载...';
  late final AnimationController _fadeController;
  late final AnimationController _scaleController;
  late final AnimationController _pulseController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _scaleController.forward();
    _pulseController.repeat(reverse: true);
    _checkAndRoute();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkAndRoute() async {
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      setState(() => _status = '正在检查安装状态...');

      // Ensure directories and resolv.conf exist on every app open.
      // 使用 Future.wait 并行执行 + 超时保护
      await Future.any([
        Future.wait([
          NativeBridge.setupDirs().timeout(const Duration(seconds: 10), onTimeout: () => throw TimeoutException('')),
          NativeBridge.writeResolv().timeout(const Duration(seconds: 10), onTimeout: () => throw TimeoutException('')),
        ]).then((_) => true),
        Future.delayed(const Duration(seconds: 12)).then((_) => false),
      ]).catchError((_) => false);

      // Direct Dart fallback: create resolv.conf if native calls failed (#40).
      try {
        final filesDir = await NativeBridge.getFilesDir().timeout(const Duration(seconds: 5));
        if (filesDir == null) throw Exception('filesDir is null');
        const resolvContent = 'nameserver 8.8.8.8\nnameserver 8.8.4.4\n';
        final configDir = '$filesDir/config';
        final resolvFile = File('$configDir/resolv.conf');
        if (!resolvFile.existsSync()) {
          Directory(configDir).createSync(recursive: true);
          resolvFile.writeAsStringSync(resolvContent);
        }
        final rootfsResolv = File('$filesDir/rootfs/ubuntu/etc/resolv.conf');
        if (!rootfsResolv.existsSync()) {
          rootfsResolv.parent.createSync(recursive: true);
          rootfsResolv.writeAsStringSync(resolvContent);
        }
      } catch (_) {}

      final prefs = PreferencesService();
      await prefs.init();

      // Auto-export snapshot when app version changes (#55)
      try {
        final oldVersion = prefs.lastAppVersion;
        if (oldVersion != null && oldVersion != AppConstants.version) {
          final hasPermission = await NativeBridge.hasStoragePermission().timeout(const Duration(seconds: 3));
          if (hasPermission) {
            final sdcard = await NativeBridge.getExternalStoragePath().timeout(const Duration(seconds: 3));
            final downloadDir = Directory('$sdcard/Download');
            if (!await downloadDir.exists()) {
              await downloadDir.create(recursive: true);
            }
            final snapshotPath = '$sdcard/Download/openclaw-snapshot-$oldVersion.json';
            final openclawJson = await NativeBridge.readRootfsFile('root/.openclaw/openclaw.json').timeout(const Duration(seconds: 5));
            final snapshot = {
              'version': oldVersion,
              'timestamp': DateTime.now().toIso8601String(),
              'openclawConfig': openclawJson,
              'dashboardUrl': prefs.dashboardUrl,
              'autoStart': prefs.autoStartGateway,
              'nodeEnabled': prefs.nodeEnabled,
              'nodeDeviceToken': prefs.nodeDeviceToken,
              'nodeGatewayHost': prefs.nodeGatewayHost,
              'nodeGatewayPort': prefs.nodeGatewayPort,
              'nodeGatewayToken': prefs.nodeGatewayToken,
            };
            await File(snapshotPath).writeAsString(
              const JsonEncoder.withIndent('  ').convert(snapshot),
            );
          }
        }
        prefs.lastAppVersion = AppConstants.version;
      } catch (_) {}

      bool setupComplete;
      try {
        setupComplete = await NativeBridge.isBootstrapComplete().timeout(const Duration(seconds: 10));
      } catch (_) {
        setupComplete = false;
      }

      // Auto-repair
      if (!setupComplete) {
        try {
          final status = await NativeBridge.getBootstrapStatus().timeout(const Duration(seconds: 15));
          final rootfsOk = status['rootfsExists'] == true;
          final bashOk = status['binBashExists'] == true;
          final nodeOk = status['nodeInstalled'] == true;
          final openclawOk = status['openclawInstalled'] == true;
          final bypassOk = status['bypassInstalled'] == true;

          if (rootfsOk && bashOk) {
            if (!bypassOk) {
              setState(() => _status = '正在修复 Bionic 补丁...');
              await NativeBridge.installBionicBypass().timeout(const Duration(seconds: 60));
            }
            if (!nodeOk) {
              setState(() => _status = '正在重装 Node.js...');
              try {
                final arch = await NativeBridge.getArch().timeout(const Duration(seconds: 5));
                final nodeTarUrl = AppConstants.getNodeTarballUrl(arch);
                final filesDir = await NativeBridge.getFilesDir().timeout(const Duration(seconds: 5));
                final nodeTarPath = '$filesDir/tmp/nodejs.tar.xz';
                final dio = Dio();
                await dio.download(nodeTarUrl, nodeTarPath);
                await NativeBridge.extractNodeTarball(nodeTarPath).timeout(const Duration(seconds: 120));
              } catch (_) {}
            }
            if (!openclawOk && nodeOk) {
              setState(() => _status = '正在重装 OpenClaw...');
              try {
                const wrapper = '/root/.openclaw/node-wrapper.js';
                const nodeRun = 'node $wrapper';
                const npmCli = '/usr/local/lib/node_modules/npm/bin/npm-cli.js';
                await NativeBridge.runInProot(
                  '$nodeRun $npmCli install -g openclaw',
                  timeout: 1800,
                );
                await NativeBridge.createBinWrappers('openclaw');
              } catch (_) {}
            }
            setupComplete = await NativeBridge.isBootstrapComplete().timeout(const Duration(seconds: 10));
          }
        } catch (_) {}
      }

      if (!mounted) return;

      if (setupComplete) {
        prefs.setupComplete = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SetupWizardScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        // 即使出错也跳转到 Dashboard 或 Setup 页面，不要卡在空白页
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SetupWizardScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: isDark
            ? const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0D0D0D), Color(0xFF1A1A2E), Color(0xFF0D0D0D)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              )
            : null,
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated logo
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.accent, AppColors.accentLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withAlpha(40),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/ic_launcher.png',
                        width: 64,
                        height: 64,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'OpenClaw',
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withAlpha(15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'AI 网关 · Android',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'by ${AppConstants.authorName} | ${AppConstants.orgName}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.accent.withAlpha(180),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _status,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
