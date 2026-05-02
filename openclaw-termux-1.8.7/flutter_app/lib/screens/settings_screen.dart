import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app.dart';
import '../constants.dart';
import '../providers/node_provider.dart';
import '../services/native_bridge.dart';
import '../services/preferences_service.dart';
import '../services/update_service.dart';
import 'node_screen.dart';
import 'setup_wizard_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _prefs = PreferencesService();
  bool _autoStart = false;
  bool _nodeEnabled = false;
  bool _batteryOptimized = true;
  String _arch = '';
  String _prootPath = '';
  Map<String, dynamic> _status = {};
  bool _loading = true;
  bool _goInstalled = false;
  bool _brewInstalled = false;
  bool _sshInstalled = false;
  bool _storageGranted = false;
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _prefs.init();
    _autoStart = _prefs.autoStartGateway;
    _nodeEnabled = _prefs.nodeEnabled;

    try {
      final arch = await NativeBridge.getArch();
      final prootPath = await NativeBridge.getProotPath();
      final status = await NativeBridge.getBootstrapStatus();
      final batteryOptimized = await NativeBridge.isBatteryOptimized();
      final storageGranted = await NativeBridge.hasStoragePermission();

      final filesDir = await NativeBridge.getFilesDir();
      final rootfs = '$filesDir/rootfs/ubuntu';
      final goInstalled = File('$rootfs/usr/bin/go').existsSync();
      final brewInstalled =
          File('$rootfs/home/linuxbrew/.linuxbrew/bin/brew').existsSync();
      final sshInstalled = File('$rootfs/usr/bin/ssh').existsSync();

      setState(() {
        _batteryOptimized = batteryOptimized;
        _storageGranted = storageGranted;
        _arch = arch;
        _prootPath = prootPath;
        _status = status;
        _goInstalled = goInstalled;
        _brewInstalled = brewInstalled;
        _sshInstalled = sshInstalled;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('设置', centerTitle: true)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _sectionHeader(context, '通用', Icons.tune_rounded),
                _buildSettingsCard([
                  SwitchListTile(
                    title: const Text('自动启动网关'),
                    subtitle: const Text('打开应用时自动启动网关'),
                    value: _autoStart,
                    onChanged: (value) {
                      setState(() => _autoStart = value);
                      _prefs.autoStartGateway = value;
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('电池优化'),
                    subtitle: Text(_batteryOptimized
                        ? '已优化 — 可能会杀死后台进程'
                        : '已关闭（推荐）'),
                    leading: const Icon(Icons.battery_alert_rounded),
                    trailing: _batteryOptimized
                        ? _statusChip('警告', AppColors.statusAmber)
                        : _statusChip('正常', AppColors.statusGreen),
                    onTap: () async {
                      await NativeBridge.requestBatteryOptimization();
                      final optimized = await NativeBridge.isBatteryOptimized();
                      setState(() => _batteryOptimized = optimized);
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('存储权限'),
                    subtitle: Text(_storageGranted
                        ? '已授权 — proot 可访问 /sdcard'
                        : '未授权（推荐）'),
                    leading: const Icon(Icons.sd_storage_rounded),
                    trailing: _storageGranted
                        ? _statusChip('活跃', AppColors.statusAmber)
                        : _statusChip('安全', AppColors.statusGreen),
                    onTap: () async {
                      await NativeBridge.requestStoragePermission();
                      final granted = await NativeBridge.hasStoragePermission();
                      setState(() => _storageGranted = granted);
                    },
                  ),
                ]),

                _sectionHeader(context, '节点', Icons.devices_rounded),
                _buildSettingsCard([
                  SwitchListTile(
                    title: const Text('启用节点'),
                    subtitle: const Text('向网关提供设备能力'),
                    value: _nodeEnabled,
                    onChanged: (value) {
                      setState(() => _nodeEnabled = value);
                      _prefs.nodeEnabled = value;
                      final nodeProvider = context.read<NodeProvider>();
                      if (value) {
                        nodeProvider.enable();
                      } else {
                        nodeProvider.disable();
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('节点配置'),
                    subtitle: const Text('连接、配对与设备能力'),
                    leading: const Icon(Icons.settings_ethernet_rounded),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const NodeScreen()),
                    ),
                  ),
                ]),

                _sectionHeader(context, '系统信息', Icons.info_outline_rounded),
                _buildSettingsCard([
                  _infoTile('CPU 架构', _arch, Icons.memory_rounded),
                  const Divider(height: 1),
                  _infoTile('PRoot 路径', _prootPath, Icons.folder_rounded),
                  const Divider(height: 1),
                  _installStatusTile('Rootfs', _status['rootfsExists'] == true),
                  const Divider(height: 1),
                  _installStatusTile('Node.js', _status['nodeInstalled'] == true),
                  const Divider(height: 1),
                  _installStatusTile('OpenClaw', _status['openclawInstalled'] == true),
                  const Divider(height: 1),
                  _installStatusTile('Go (Golang)', _goInstalled),
                  const Divider(height: 1),
                  _installStatusTile('Homebrew', _brewInstalled),
                  const Divider(height: 1),
                  _installStatusTile('OpenSSH', _sshInstalled),
                ]),

                _sectionHeader(context, '维护工具', Icons.build_rounded),
                _buildSettingsCard([
                  ListTile(
                    title: const Text('导出快照'),
                    subtitle: const Text('备份配置到下载目录'),
                    leading: const Icon(Icons.upload_file_rounded),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: _exportSnapshot,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('导入快照'),
                    subtitle: const Text('从备份恢复配置'),
                    leading: const Icon(Icons.download_rounded),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: _importSnapshot,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('重新安装'),
                    subtitle: const Text('重新安装或修复环境'),
                    leading: const Icon(Icons.refresh_rounded),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const SetupWizardScreen(),
                      ),
                    ),
                  ),
                ]),

                _sectionHeader(context, '关于', Icons.openclaw_rounded),
                _buildSettingsCard([
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.hub, color: AppColors.accent, size: 20),
                    ),
                    title: const Text('OpenClaw'),
                    subtitle: Text(
                      'AI 网关 for Android\n版本 ${AppConstants.version}',
                    ),
                    isThreeLine: true,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('检查更新'),
                    subtitle: const Text('检查 GitHub 是否有新版本'),
                    leading: _checkingUpdate
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.system_update_rounded),
                    onTap: _checkingUpdate ? null : _checkForUpdates,
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    title: Text('Developer'),
                    subtitle: Text(AppConstants.authorName),
                    leading: Icon(Icons.person_rounded),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('GitHub'),
                    subtitle: const Text('mithun50/openclaw-termux'),
                    leading: const Icon(Icons.code_rounded),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 16),
                    onTap: () => launchUrl(
                      Uri.parse(AppConstants.githubUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Contact'),
                    subtitle: const Text(AppConstants.authorEmail),
                    leading: const Icon(Icons.email_rounded),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 16),
                    onTap: () => launchUrl(
                      Uri.parse('mailto:${AppConstants.authorEmail}'),
                    ),
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    title: Text('License'),
                    subtitle: Text(AppConstants.license),
                    leading: Icon(Icons.description_rounded),
                  ),
                ]),

                _sectionHeader(context, AppConstants.orgName, Icons.business_rounded),
                _buildSettingsCard([
                  ListTile(
                    title: const Text('Instagram'),
                    subtitle: const Text('@nexgenxplorer_nxg'),
                    leading: const Icon(Icons.camera_alt_rounded),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 16),
                    onTap: () => launchUrl(
                      Uri.parse(AppConstants.instagramUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('YouTube'),
                    subtitle: const Text('@nexgenxplorer'),
                    leading: const Icon(Icons.play_circle_fill_rounded),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 16),
                    onTap: () => launchUrl(
                      Uri.parse(AppConstants.youtubeUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Play Store'),
                    subtitle: const Text('NextGenX Apps'),
                    leading: const Icon(Icons.shop_rounded),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 16),
                    onTap: () => launchUrl(
                      Uri.parse(AppConstants.playStoreUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Email'),
                    subtitle: const Text(AppConstants.orgEmail),
                    leading: const Icon(Icons.email_outlined),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 16),
                    onTap: () => launchUrl(
                      Uri.parse('mailto:${AppConstants.orgEmail}'),
                    ),
                  ),
                ]),
              ],
            ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.mutedText),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _infoTile(String title, String value, IconData icon) {
    return ListTile(
      title: Text(title),
      subtitle: Text(value, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
      leading: Icon(icon),
    );
  }

  Widget _installStatusTile(String name, bool installed) {
    return ListTile(
      title: Text(name),
      leading: Icon(
        installed ? Icons.check_circle_rounded : Icons.cancel_outlined,
        color: installed ? AppColors.statusGreen : AppColors.statusGrey,
        size: 22,
      ),
      trailing: _statusChip(
        installed ? '已安装' : '未安装',
        installed ? AppColors.statusGreen : AppColors.statusGrey,
      ),
    );
  }

  Future<String> _getSnapshotPath() async {
    final hasPermission = await NativeBridge.hasStoragePermission();
    if (hasPermission) {
      final sdcard = await NativeBridge.getExternalStoragePath();
      final downloadDir = Directory('$sdcard/Download');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      return '$sdcard/Download/openclaw-snapshot.json';
    }
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/openclaw-snapshot.json';
  }

  Future<void> _exportSnapshot() async {
    try {
      final openclawJson = await NativeBridge.readRootfsFile('root/.openclaw/openclaw.json');
      final snapshot = {
        'version': AppConstants.version,
        'timestamp': DateTime.now().toIso8601String(),
        'openclawConfig': openclawJson,
        'dashboardUrl': _prefs.dashboardUrl,
        'autoStart': _prefs.autoStartGateway,
        'nodeEnabled': _prefs.nodeEnabled,
        'nodeDeviceToken': _prefs.nodeDeviceToken,
        'nodeGatewayHost': _prefs.nodeGatewayHost,
        'nodeGatewayPort': _prefs.nodeGatewayPort,
        'nodeGatewayToken': _prefs.nodeGatewayToken,
      };

      final path = await _getSnapshotPath();
      final file = File(path);
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(snapshot));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('快照已保存到 $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：$e')),
      );
    }
  }

  Future<void> _importSnapshot() async {
    try {
      final path = await _getSnapshotPath();
      final file = File(path);

      if (!await file.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('在 $path 未找到快照文件')),
        );
        return;
      }

      final content = await file.readAsString();
      final snapshot = jsonDecode(content) as Map<String, dynamic>;

      final openclawConfig = snapshot['openclawConfig'] as String?;
      if (openclawConfig != null) {
        await NativeBridge.writeRootfsFile('root/.openclaw/openclaw.json', openclawConfig);
      }

      if (snapshot['dashboardUrl'] != null) {
        _prefs.dashboardUrl = snapshot['dashboardUrl'] as String;
      }
      if (snapshot['autoStart'] != null) {
        _prefs.autoStartGateway = snapshot['autoStart'] as bool;
      }
      if (snapshot['nodeEnabled'] != null) {
        _prefs.nodeEnabled = snapshot['nodeEnabled'] as bool;
      }
      if (snapshot['nodeDeviceToken'] != null) {
        _prefs.nodeDeviceToken = snapshot['nodeDeviceToken'] as String;
      }
      if (snapshot['nodeGatewayHost'] != null) {
        _prefs.nodeGatewayHost = snapshot['nodeGatewayHost'] as String;
      }
      if (snapshot['nodeGatewayPort'] != null) {
        _prefs.nodeGatewayPort = snapshot['nodeGatewayPort'] as int;
      }
      if (snapshot['nodeGatewayToken'] != null) {
        _prefs.nodeGatewayToken = snapshot['nodeGatewayToken'] as String;
      }

      await _loadSettings();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('快照已恢复。重启网关以生效。')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：$e')),
      );
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() => _checkingUpdate = true);
    try {
      final result = await UpdateService.check();
      if (!mounted) return;
      if (result.available) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('更新可用'),
            content: Text(
              '发现新版本。\n\n'
              '当前：${AppConstants.version}\n'
              '最新：${result.latest}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('稍后'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  launchUrl(
                    Uri.parse(result.url),
                    mode: LaunchMode.externalApplication,
                  );
                },
                child: const Text('下载'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前已是最新版本')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法检查更新')),
      );
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }
}
