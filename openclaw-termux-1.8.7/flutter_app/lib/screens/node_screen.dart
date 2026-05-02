import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app.dart';
import '../providers/node_provider.dart';
import '../services/preferences_service.dart';
import '../widgets/node_controls.dart';

/// 节点配置 — 连接网关、设备能力、配对状态
class NodeScreen extends StatefulWidget {
  const NodeScreen({super.key});

  @override
  State<NodeScreen> createState() => _NodeScreenState();
}

class _NodeScreenState extends State<NodeScreen> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _isLocal = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = PreferencesService();
    await prefs.init();
    final host = prefs.nodeGatewayHost ?? '127.0.0.1';
    final port = prefs.nodeGatewayPort ?? 18789;
    final token = prefs.nodeGatewayToken ?? '';
    setState(() {
      _isLocal = host == '127.0.0.1' || host == 'localhost';
      _hostController.text = _isLocal ? '' : host;
      _portController.text = _isLocal ? '' : '$port';
      _tokenController.text = _isLocal ? '' : token;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('节点配置'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<NodeProvider>(
              builder: (context, provider, _) {
                final state = provider.state;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const NodeControls(),
                    const SizedBox(height: 16),

                    // 网关连接
                    _sectionHeader(theme, '网关连接'),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isDark ? AppColors.darkElevated.withAlpha(80) : Colors.grey.shade200),
                        color: isDark ? AppColors.darkElevated : Colors.white,
                      ),
                      child: Column(
                        children: [
                          RadioListTile<bool>(
                            title: const Text('本地网关', style: TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: const Text('与本机网关自动配对'),
                            value: true, groupValue: _isLocal, activeColor: AppColors.accent,
                            onChanged: (v) => setState(() => _isLocal = v!),
                          ),
                          RadioListTile<bool>(
                            title: const Text('远程网关', style: TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: const Text('连接到其他设备的网关'),
                            value: false, groupValue: _isLocal, activeColor: AppColors.accent,
                            onChanged: (v) => setState(() => _isLocal = v!),
                          ),
                          if (!_isLocal) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: TextField(controller: _hostController, decoration: const InputDecoration(labelText: '网关地址', hintText: '192.168.1.100')),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                              child: TextField(controller: _portController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '端口', hintText: '18789')),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                              child: TextField(
                                controller: _tokenController, obscureText: true,
                                decoration: InputDecoration(
                                  labelText: '网关令牌', hintText: '从仪表盘 URL 中粘贴',
                                  helperText: '位于仪表盘 URL 的 #token= 之后',
                                  prefixIcon: const Icon(Icons.key_outlined, size: 20),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: FilledButton.icon(
                                onPressed: () {
                                  final host = _hostController.text.trim();
                                  final port = int.tryParse(_portController.text.trim()) ?? 18789;
                                  final token = _tokenController.text.trim();
                                  if (host.isNotEmpty) provider.connectRemote(host, port, token: token.isNotEmpty ? token : null);
                                },
                                icon: const Icon(Icons.link), label: const Text('连接', style: TextStyle(fontWeight: FontWeight.w600)),
                                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 配对状态
                    if (state.pairingCode != null) ...[
                      _sectionHeader(theme, '配对码'),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [AppColors.statusAmber.withAlpha(25), AppColors.statusAmber.withAlpha(8)]),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.statusAmber.withAlpha(50)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(children: [
                            const Icon(Icons.qr_code_2, size: 48, color: AppColors.statusAmber),
                            const SizedBox(height: 12),
                            Text('请在网关上批准此配对码：', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                            const SizedBox(height: 12),
                            SelectableText(state.pairingCode!, style: theme.textTheme.headlineMedium?.copyWith(fontFamily: 'monospace', fontWeight: FontWeight.w900, letterSpacing: 4, color: theme.colorScheme.primary)),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 设备能力
                    _sectionHeader(theme, '设备能力'),
                    _capabilityTile(theme, '相机', '拍照和录制视频', Icons.camera_alt, available: true, iconColor: AppColors.iconNode),
                    _capabilityTile(theme, '画布', '移动端不可用', Icons.web, available: false, iconColor: Colors.grey),
                    _capabilityTile(theme, '位置', '获取 GPS 坐标', Icons.location_on, available: true, iconColor: AppColors.iconNode),
                    _capabilityTile(theme, '屏幕录制', '录制屏幕（需每次授权）', Icons.screen_share, available: true, iconColor: AppColors.iconNode),
                    _capabilityTile(theme, '闪光灯', '开关手电筒', Icons.flashlight_on, available: true, iconColor: AppColors.iconNode),
                    _capabilityTile(theme, '震动', '触觉反馈与震动模式', Icons.vibration, available: true, iconColor: AppColors.iconNode),
                    _capabilityTile(theme, '传感器', '加速度计、陀螺仪、气压计等', Icons.sensors, available: true, iconColor: AppColors.iconNode),
                    _capabilityTile(theme, '串口', '蓝牙与 USB 串口通信', Icons.usb, available: true, iconColor: AppColors.iconNode),
                    const SizedBox(height: 16),

                    // 设备信息
                    if (state.deviceId != null) ...[
                      _sectionHeader(theme, '设备信息'),
                      Container(
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? AppColors.darkElevated.withAlpha(80) : Colors.grey.shade200), color: isDark ? AppColors.darkElevated : Colors.white),
                        child: ListTile(
                          leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.iconNode.withAlpha(15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.fingerprint, size: 20, color: AppColors.iconNode)),
                          title: const Text('设备 ID', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: SelectableText(state.deviceId!, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // 节点日志
                    _sectionHeader(theme, '节点日志'),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? AppColors.darkElevated.withAlpha(80) : Colors.grey.shade200),
                        color: isDark ? AppColors.darkBg : const Color(0xFFFAFAFA),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: state.logs.isEmpty
                          ? Center(child: Text('暂无日志', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)))
                          : ListView.builder(
                              reverse: true,
                              itemCount: state.logs.length,
                              itemBuilder: (context, index) {
                                final log = state.logs[state.logs.length - 1 - index];
                                return Text(log, style: const TextStyle(fontFamily: 'monospace', fontSize: 11));
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      child: Text(title, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w800, letterSpacing: 1.5, fontSize: 12)),
    );
  }

  Widget _capabilityTile(ThemeData theme, String title, String subtitle, IconData icon, {bool available = true, required Color iconColor}) {
    final isDark = theme.brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? AppColors.darkElevated.withAlpha(60) : Colors.grey.shade200),
            color: isDark ? AppColors.darkElevated.withAlpha(60) : Colors.white,
          ),
          child: ListTile(
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: iconColor.withAlpha(15), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: available ? iconColor : Colors.grey.shade400, size: 22),
            ),
            title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: available ? null : Colors.grey)),
            subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: available ? theme.colorScheme.onSurfaceVariant : Colors.grey.shade400)),
            trailing: available
                ? Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppColors.statusGreen.withAlpha(15), shape: BoxShape.circle), child: const Icon(Icons.check_circle, color: AppColors.statusGreen, size: 18))
                : Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppColors.statusAmber.withAlpha(15), shape: BoxShape.circle), child: const Icon(Icons.block, color: AppColors.statusAmber, size: 18)),
          ),
        ),
      ),
    );
  }
}
