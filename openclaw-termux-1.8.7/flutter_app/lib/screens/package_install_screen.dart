import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import 'package:flutter_pty/flutter_pty.dart';
import '../models/optional_package.dart';
import '../services/native_bridge.dart';
import '../services/screenshot_service.dart';
import '../services/terminal_service.dart';
import '../widgets/terminal_toolbar.dart';

/// 软件包安装/卸载终端页面
class PackageInstallScreen extends StatefulWidget {
  final OptionalPackage package;
  final bool isUninstall;

  const PackageInstallScreen({super.key, required this.package, this.isUninstall = false});

  @override
  State<PackageInstallScreen> createState() => _PackageInstallScreenState();
}

class _PackageInstallScreenState extends State<PackageInstallScreen> {
  late final Terminal _terminal;
  late final TerminalController _controller;
  Pty? _pty;
  bool _loading = true;
  bool _finished = false;
  String? _error;
  final _ctrlNotifier = ValueNotifier<bool>(false);
  final _altNotifier = ValueNotifier<bool>(false);
  final _screenshotKey = GlobalKey();

  static const _fontFallback = ['monospace','Noto Sans Mono','Noto Sans Mono CJK SC','Noto Sans Mono CJK TC','Noto Sans Mono CJK JP','Noto Color Emoji','Noto Sans Symbols','Noto Sans Symbols 2','sans-serif'];

  @override
  void initState() { super.initState(); _terminal = Terminal(maxLines: 10000); _controller = TerminalController(); NativeBridge.startTerminalService(); WidgetsBinding.instance.addPostFrameCallback((_) => _startProcess()); }

  Future<void> _startProcess() async {
    _pty?.kill(); _pty = null;
    try {
      try { await NativeBridge.setupDirs(); } catch (_) {}
      try { await NativeBridge.writeResolv(); } catch (_) {}
      try {
        final filesDir = await NativeBridge.getFilesDir();
        const resolvContent = 'nameserver 8.8.8.8\nnameserver 8.8.4.4\n';
        final resolvFile = File('$filesDir/config/resolv.conf');
        if (!resolvFile.existsSync()) { Directory('$filesDir/config').createSync(recursive: true); resolvFile.writeAsStringSync(resolvContent); }
        final rootfsResolv = File('$filesDir/rootfs/ubuntu/etc/resolv.conf');
        if (!rootfsResolv.existsSync()) { rootfsResolv.parent.createSync(recursive: true); rootfsResolv.writeAsStringSync(resolvContent); }
      } catch (_) {}
      final config = await TerminalService.getProotShellConfig();
      final args = TerminalService.buildProotArgs(config, columns: _terminal.viewWidth, rows: _terminal.viewHeight);
      final command = widget.isUninstall ? widget.package.uninstallCommand : widget.package.installCommand;
      final cmdArgs = List<String>.from(args); cmdArgs.removeLast(); cmdArgs.removeLast(); cmdArgs.addAll(['/bin/bash', '-lc', command]);
      _pty = Pty.start(config['executable']!, arguments: cmdArgs, environment: TerminalService.buildHostEnv(config), columns: _terminal.viewWidth, rows: _terminal.viewHeight);

      final sentinel = widget.isUninstall ? widget.package.uninstallSentinel : widget.package.completionSentinel;
      _pty!.output.cast<List<int>>().listen((data) {
        final text = utf8.decode(data, allowMalformed: true); _terminal.write(text);
        if (!_finished && text.contains(sentinel)) { if (mounted) setState(() => _finished = true); }
      });
      _pty!.exitCode.then((code) { _terminal.write('\r\n[进程退出，代码：$code]\r\n'); if (mounted && !_finished) setState(() => _finished = true); });

      _terminal.onOutput = (data) {
        if (_ctrlNotifier.value && data.length == 1) { final code = data.toLowerCase().codeUnitAt(0); if (code >= 97 && code <= 122) { _pty?.write(Uint8List.fromList([code - 96])); _ctrlNotifier.value = false; return; } }
        if (_altNotifier.value && data.isNotEmpty) { _pty?.write(utf8.encode('\x1b$data')); _altNotifier.value = false; return; }
        _pty?.write(utf8.encode(data));
      };
      _terminal.onResize = (w, h, pw, ph) => _pty?.resize(h, w);
      setState(() => _loading = false);
    } catch (e) { setState(() { _loading = false; _error = '启动失败：$e'; }); }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain); if (data?.text != null && data!.text!.isNotEmpty) _pty?.write(utf8.encode(data.text!));
  }

  Future<void> _takeScreenshot() async {
    final path = await ScreenshotService.capture(_screenshotKey, prefix: 'package'); if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(path != null ? '截图已保存：${path.split('/').last}' : '截图失败')));
  }

  @override
  void dispose() { _ctrlNotifier.dispose(); _altNotifier.dispose(); _controller.dispose(); _pty?.kill(); NativeBridge.stopTerminalService(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final action = widget.isUninstall ? '卸载' : '安装';
    return Scaffold(
      appBar: AppBar(title: Text('$action ${widget.package.name}', centerTitle: true), automaticallyImplyLeading: false, actions: [
        IconButton(icon: const Icon(Icons.camera_alt_outlined), tooltip: '截图', onPressed: _takeScreenshot),
        IconButton(icon: const Icon(Icons.paste), tooltip: '粘贴', onPressed: _paste),
      ]),
      body: Column(children: [
        if (_loading)
          Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const CircularProgressIndicator(), const SizedBox(height: 16), Text('正在启动...', style: TextStyle(color: Colors.grey.shade400))]))))
        else if (_error != null)
          Expanded(child: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error), const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error)), const SizedBox(height: 16),
            FilledButton.icon(onPressed: () { setState(() {_loading=true; _error=null; _finished=false;}); _startProcess(); }, icon: const Icon(Icons.refresh), label: const Text('重试')),
          ]))))
        else ...[
          Expanded(child: RepaintBoundary(key: _screenshotKey, child: TerminalView(_terminal, controller: _controller, textStyle: const TerminalStyle(fontSize: 11, height: 1.0, fontFamily: 'DejaVuSansMono', fontFamilyFallback: _fontFallback)))),
          TerminalToolbar(pty: _pty, ctrlNotifier: _ctrlNotifier, altNotifier: _altNotifier),
        ],
        if (_finished)
          Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true), icon: const Icon(Icons.check),
            label: const Text('完成'), style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
          ))),
      ]),
    );
  }
}
