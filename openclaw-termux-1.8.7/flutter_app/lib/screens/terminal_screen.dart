import 'dart:io';
import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';
import 'package:flutter_pty/flutter_pty.dart';
import '../services/native_bridge.dart';
import '../services/screenshot_service.dart';
import '../services/terminal_service.dart';
import '../widgets/terminal_toolbar.dart';
import '../widgets/terminal_mixin.dart';

/// 终端屏幕 — 完整的 proot shell 环境
class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> with TerminalMixin {
  @override
  void initState() {
    super.initState();
    initTerminal();
    NativeBridge.startTerminalService();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startPty());
  }

  @override
  void dispose() {
    NativeBridge.stopTerminalService();
    disposeTerminal();
    super.dispose();
  }

  Future<void> _startPty() async {
    pty?.kill();
    pty = null;

    try {
      await _ensureResolvConf();

      final config = await TerminalService.getProotShellConfig();
      final args = TerminalService.buildProotArgs(
        config,
        columns: terminal.viewWidth,
        rows: terminal.viewHeight,
      );

      final newPty = Pty.start(
        config['executable']!,
        arguments: args,
        environment: TerminalService.buildHostEnv(config),
        columns: terminal.viewWidth,
        rows: terminal.viewHeight,
      );

      bindPty(newPty);
      setState(() => loading = false);
    } catch (e) {
      setState(() {
        loading = false;
        error = '终端启动失败：$e';
      });
    }
  }

  Future<void> _ensureResolvConf() async {
    try { await NativeBridge.setupDirs(); } catch (_) {}
    try { await NativeBridge.writeResolv(); } catch (_) {}
    try {
      final filesDir = await NativeBridge.getFilesDir();
      const resolvContent = 'nameserver 8.8.8.8\nnameserver 8.8.4.4\n';
      final resolvFile = File('$filesDir/config/resolv.conf');
      if (!resolvFile.existsSync()) {
        Directory('$filesDir/config').createSync(recursive: true);
        resolvFile.writeAsStringSync(resolvContent);
      }
      final rootfsResolv = File('$filesDir/rootfs/ubuntu/etc/resolv.conf');
      if (!rootfsResolv.existsSync()) {
        rootfsResolv.parent.createSync(recursive: true);
        rootfsResolv.writeAsStringSync(resolvContent);
      }
    } catch (_) {}
  }

  Future<void> _takeScreenshot() async {
    final path = await ScreenshotService.capture(screenshotKey);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(path != null ? '截图已保存：${path.split('/').last}' : '截图失败'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('终端'),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            tooltip: '截图',
            onPressed: _takeScreenshot,
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: '复制',
            onPressed: () => copySelection(context),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            tooltip: '打开 URL',
            onPressed: () => openSelection(context),
          ),
          IconButton(
            icon: const Icon(Icons.paste),
            tooltip: '粘贴',
            onPressed: paste,
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: '重启',
            onPressed: () {
              pty?.kill();
              setState(() {
                loading = true;
                error = null;
              });
              _startPty();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RepaintBoundary(
              key: screenshotKey,
              child: TerminalView(
                terminal,
                controller: controller,
                textStyle: TerminalMixin.terminalStyle,
                onTapUp: (_, offset) => handleTap(offset),
              ),
            ),
          ),
          TerminalToolbar(
            pty: pty,
            ctrlNotifier: ctrlNotifier,
            altNotifier: altNotifier,
          ),
        ],
      ),
    );
  }
}
