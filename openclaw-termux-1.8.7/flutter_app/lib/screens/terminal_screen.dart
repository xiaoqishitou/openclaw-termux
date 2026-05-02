import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/native_bridge.dart';
import '../services/screenshot_service.dart';
import '../services/terminal_service.dart';
import '../widgets/terminal_toolbar.dart';

/// 终端屏幕 — 完整的 proot shell 环境
class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  late final Terminal _terminal;
  late final TerminalController _controller;
  Pty? _pty;
  bool _loading = true;
  String? _error;
  final _ctrlNotifier = ValueNotifier<bool>(false);
  final _altNotifier = ValueNotifier<bool>(false);
  final _screenshotKey = GlobalKey();
  static final _anyUrlRegex = RegExp(r'https?://[^\s<>\[\]"' "'" r'\)]+');
  static final _boxDrawing = RegExp(r'[│┤├┬┴┼╮╯╰╭─╌╴╶┌┐└┘◇◆]+');

  static const _fontFallback = ['monospace','Noto Sans Mono','Noto Sans Mono CJK SC','Noto Sans Mono CJK TC','Noto Sans Mono CJK JP','Noto Color Emoji','Noto Sans Symbols','Noto Sans Symbols 2','sans-serif'];

  @override
  void initState() {
    super.initState(); _terminal = Terminal(maxLines: 10000); _controller = TerminalController();
    NativeBridge.startTerminalService();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startPty());
  }

  Future<void> _startPty() async {
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
      _pty = Pty.start(config['executable']!, arguments: args, environment: TerminalService.buildHostEnv(config), columns: _terminal.viewWidth, rows: _terminal.viewHeight);
      _pty!.output.cast<List<int>>().listen((data) => _terminal.write(utf8.decode(data, allowMalformed: true)));
      _pty!.exitCode.then((code) => _terminal.write('\r\n[进程退出，代码：$code]\r\n'));

      _terminal.onOutput = (data) {
        if (_ctrlNotifier.value && data.length == 1) { final code = data.toLowerCase().codeUnitAt(0); if (code >= 97 && code <= 122) { _pty?.write(Uint8List.fromList([code - 96])); _ctrlNotifier.value = false; return; } }
        if (_altNotifier.value && data.isNotEmpty) { _pty?.write(utf8.encode('\x1b$data')); _altNotifier.value = false; return; }
        _pty?.write(utf8.encode(data));
      };
      _terminal.onResize = (w, h, pw, ph) => _pty?.resize(h, w);
      setState(() => _loading = false);
    } catch (e) { setState(() { _loading = false; _error = '终端启动失败：$e'; }); }
  }

  @override
  void dispose() {
    _ctrlNotifier.dispose(); _altNotifier.dispose(); _controller.dispose(); _pty?.kill();
    NativeBridge.stopTerminalService(); super.dispose();
  }

  String? _getSelectedText() {
    final selection = _controller.selection; if (selection == null || selection.isCollapsed) return null;
    final range = selection.normalized; final sb = StringBuffer();
    for (int y = range.begin.y; y <= range.end.y; y++) {
      if (y >= _terminal.buffer.lines.length) break;
      final line = _terminal.buffer.lines[y]; final from = (y == range.begin.x) ? range.begin.x : 0; final to = (y == range.end.y) ? range.end.x : null;
      sb.write(line.getText(from, to)); if (y < range.end.y) sb.writeln();
    }
    return sb.toString().trim().isEmpty ? null : sb.toString().trim();
  }

  String? _extractUrl(String text) {
    final clean = text.replaceAll(_boxDrawing, '').replaceAll(RegExp(r'\s+'), ''); final parts = clean.split(RegExp(r'(?=https?://)'));
    String? best;
    for (final part in parts) { final match = _anyUrlRegex.firstMatch(part); if (match != null) { final url = match.group(0)!; if (best == null || url.length > best.length) best = url; } }
    return best;
  }

  void _copySelection() {
    final text = _getSelectedText(); if (text == null) return; Clipboard.setData(ClipboardData(text: text));
    final url = _extractUrl(text);
    if (url != null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('已复制到剪贴板'), duration: const Duration(seconds: 3), action: SnackBarAction(label: '打开', onPressed: () { final uri = Uri.tryParse(url); if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication); }))); }
    else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制到剪贴板'), duration: Duration(seconds: 1))); }
  }

  void _openSelection() {
    final text = _getSelectedText(); if (text == null) return;
    final url = _extractUrl(text); if (url != null) { final uri = Uri.tryParse(url); if (uri != null) { launchUrl(uri, mode: LaunchMode.externalApplication); return; } }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('选中内容未包含 URL'), duration: Duration(seconds: 1)));
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain); if (data?.text != null && data!.text!.isNotEmpty) _pty?.write(utf8.encode(data.text!));
  }

  Future<void> _takeScreenshot() async {
    final path = await ScreenshotService.capture(_screenshotKey); if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(path != null ? '截图已保存：${path.split('/').last}' : '截图失败')));
  }

  void _handleTap(TapUpDetails details, CellOffset offset) {
    final totalLines = _terminal.buffer.lines.length;
    final startRow = (offset.y - 2).clamp(0, totalLines - 1); final endRow = (offset.y + 2).clamp(0, totalLines - 1);
    final sb = StringBuffer(); for (int row = startRow; row <= endRow; row++) sb.write(_getLineText(row).trimRight());
    final url = _extractUrl(sb.toString()); if (url != null) _openUrl(url);
  }

  String _getLineText(int row) {
    try { final line = _terminal.buffer.lines[row]; final sb = StringBuffer();
      for (int i = 0; i < line.length; i++) { final char = line.getCodePoint(i); if (char != 0) sb.writeCharCode(char); }
      return sb.toString(); } catch (_) { return ''; }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url); if (uri == null) return;
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(title: const Text('打开链接'), content: Text(url), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
        TextButton(onPressed: () { Clipboard.setData(ClipboardData(text: url)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('链接已复制'))); Navigator.pop(ctx, false); }, child: const Text('复制')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('打开')),
      ]),
    );
    if (shouldOpen == true) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('终端', centerTitle: true), actions: [
        IconButton(icon: const Icon(Icons.camera_alt_outlined), tooltip: '截图', onPressed: _takeScreenshot),
        IconButton(icon: const Icon(Icons.copy), tooltip: '复制', onPressed: _copySelection),
        IconButton(icon: const Icon(Icons.open_in_browser), tooltip: '打开 URL', onPressed: _openSelection),
        IconButton(icon: const Icon(Icons.paste), tooltip: '粘贴', onPressed: _paste),
        IconButton(icon: const Icon(Icons.restart_alt), tooltip: '重启', onPressed: () { _pty?.kill(); setState(() { _loading = true; _error = null; }); _startPty(); }),
      ]),
      body: Column(children: [
        Expanded(child: RepaintBoundary(key: _screenshotKey, child: TerminalView(_terminal, controller: _controller, textStyle: const TerminalStyle(fontSize: 11, height: 1.0, fontFamily: 'DejaVuSansMono', fontFamilyFallback: _fontFallback), onTapUp: _handleTap))),
        TerminalToolbar(pty: _pty, ctrlNotifier: _ctrlNotifier, altNotifier: _altNotifier),
      ]),
    );
  }
}
