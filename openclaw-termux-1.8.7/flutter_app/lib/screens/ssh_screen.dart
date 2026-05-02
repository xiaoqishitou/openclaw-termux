import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app.dart';
import '../services/ssh_service.dart';
import 'packages_screen.dart';

/// SSH 服务管理 — 启动/停止 sshd、设置密码、显示连接信息
class SshScreen extends StatefulWidget {
  const SshScreen({super.key});

  @override
  State<SshScreen> createState() => _SshScreenState();
}

class _SshScreenState extends State<SshScreen> {
  bool _loading = true;
  bool _installed = false;
  bool _running = false;
  bool _toggling = false;
  bool _settingPassword = false;

  final _portController = TextEditingController(text: '8022');
  final _passwordController = TextEditingController();
  List<String> _ips = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _portController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final installed = await SshService.isInstalled();
    bool running = false;
    List<String> ips = [];
    if (installed) {
      running = await SshService.isSshdRunning();
      ips = await SshService.getIpAddresses();
      if (running) {
        final port = await SshService.getPort();
        if (mounted) _portController.text = port.toString();
      }
    }
    if (mounted) {
      setState(() {
        _installed = installed;
        _running = running;
        _ips = ips;
        _loading = false;
      });
    }
  }

  Future<void> _toggleSshd() async {
    setState(() => _toggling = true);
    try {
      if (_running) {
        await SshService.stopSshd();
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        final port = int.tryParse(_portController.text.trim()) ?? 8022;
        await SshService.startSshd(port: port);
        await Future.delayed(const Duration(seconds: 2));
      }
      await _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('错误：$e')));
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _setPassword() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('密码不能为空')));
      return;
    }
    setState(() => _settingPassword = true);
    try {
      await SshService.setPassword(password);
      if (mounted) {
        _passwordController.clear();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Root 密码已更新')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('设置失败：$e')));
    } finally {
      if (mounted) setState(() => _settingPassword = false);
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('SSH 远程访问'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _installed ? _buildInstalledView(theme) : _buildNotInstalledView(theme),
    );
  }

  Widget _buildNotInstalledView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: AppColors.iconSsh.withAlpha(15), shape: BoxShape.circle),
              child: Icon(Icons.vpn_key, size: 56, color: AppColors.iconSsh),
            ),
            const SizedBox(height: 20),
            Text('未安装 OpenSSH', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text('请先从"可选软件包"页面安装 OpenSSH。', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PackagesScreen()));
                _refresh();
              },
              icon: const Icon(Icons.extension),
              label: const Text('前往软件包', style: TextStyle(fontWeight: FontWeight.w600)),
              style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstalledView(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final port = _portController.text.trim();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 服务控制区
        _sectionHeader(theme, '服务控制'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? AppColors.darkElevated.withAlpha(80) : Colors.grey.shade200),
            color: isDark ? AppColors.darkElevated : Colors.white,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (_running ? AppColors.statusGreen : AppColors.statusGrey).withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_running ? Icons.check_circle : Icons.cancel, color: _running ? AppColors.statusGreen : AppColors.statusGrey, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Text(_running ? 'SSH 服务运行中' : 'SSH 服务已停止', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    if (_running) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.statusGreen.withAlpha(25), borderRadius: BorderRadius.circular(20)),
                        child: const Text('在线', style: TextStyle(fontSize: 11, color: AppColors.statusGreen, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                if (!_running)
                  TextField(controller: _portController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: '端口', hintText: '8022')),
                if (!_running) const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: _running
                      ? OutlinedButton(
                          onPressed: _toggling ? null : _toggleSshd,
                          style: OutlinedButtonStyleFrom(side: BorderSide(color: Colors.redAccent.withAlpha(150)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: _toggling ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('停止服务', style: TextStyle(fontWeight: FontWeight.w600))
                        )
                      : FilledButton(
                          onPressed: _toggling ? null : _toggleSshd,
                          style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: _toggling ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('启动服务', style: TextStyle(fontWeight: FontWeight.w700))
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Root 密码
        _sectionHeader(theme, 'Root 密码'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? AppColors.darkElevated.withAlpha(80) : Colors.grey.shade200),
            color: isDark ? AppColors.darkElevated : Colors.white,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('设置 SSH 登录的 Root 密码', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 14),
                TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: '新密码', hintText: '输入密码')),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    onPressed: _settingPassword ? null : _setPassword,
                    style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: _settingPassword ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('设置密码', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 连接信息（运行时）
        if (_running) ...[
          const SizedBox(height: 24),
          _sectionHeader(theme, '连接信息'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.darkElevated.withAlpha(80) : Colors.grey.shade200),
              color: isDark ? AppColors.darkElevated : Colors.white,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow(theme, '用户名', 'root'),
                  const Divider(height: 28),
                  _infoRow(theme, '端口', port),
                  if (_ips.isNotEmpty) ...[
                    const Divider(height: 28),
                    _infoRow(theme, 'IP 地址', _ips.join(', ')),
                  ],
                  const Divider(height: 28),
                  Text('从其他设备连接：', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 10),
                  for (final ip in _ips) ...[_commandRow(theme, isDark, 'ssh root@$ip -p $port'), const SizedBox(height: 8)],
                  if (_ips.isEmpty) _commandRow(theme, isDark, 'ssh root@<设备IP> -p $port'),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(title, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w800, letterSpacing: 1.5, fontSize: 12)),
    );
  }

  Widget _infoRow(ThemeData theme, String label, String value) {
    return Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 3),
        Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontFamily: 'monospace')),
      ])),
    ]);
  }

  Widget _commandRow(ThemeData theme, bool isDark, String command) {
    final bg = isDark ? AppColors.darkBg : const Color(0xFFF0F0F0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.statusBlue.withAlpha(40))),
      child: Row(
        children: [
          Expanded(child: Text(command, style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace', fontWeight: FontWeight.w500, color: AppColors.statusBlue))),
          IconButton(icon: const Icon(Icons.copy_all, size: 18, color: AppColors.statusBlue), onPressed: () => _copyToClipboard(command), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        ],
      ),
    );
  }
}
