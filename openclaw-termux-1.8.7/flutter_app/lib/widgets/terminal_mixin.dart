import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:url_launcher/url_launcher.dart';

/// 终端屏幕的共享逻辑 Mixin
mixin TerminalMixin<T extends StatefulWidget> on State<T> {
  static final _anyUrlRegex = RegExp(r'https?://[^\s<>\[\]"' "'" r'\)]+');
  static final boxDrawingPattern = RegExp(r'[│┤├┬┴┼╮╯╰╭─╌╴╶┌┐└┘◇◆]+');
  static const _fontFallback = [
    'monospace', 'Noto Sans Mono', 'Noto Sans Mono CJK SC',
    'Noto Sans Mono CJK TC', 'Noto Sans Mono CJK JP', 'Noto Color Emoji',
    'Noto Sans Symbols', 'Noto Sans Symbols 2', 'sans-serif',
  ];

  late final Terminal terminal;
  late final TerminalController controller;
  Pty? pty;
  bool loading = true;
  String? error;
  final ctrlNotifier = ValueNotifier<bool>(false);
  final altNotifier = ValueNotifier<bool>(false);
  final screenshotKey = GlobalKey();

  void initTerminal() {
    terminal = Terminal(maxLines: 10000);
    controller = TerminalController();
  }

  void disposeTerminal() {
    ctrlNotifier.dispose();
    altNotifier.dispose();
    controller.dispose();
    pty?.kill();
  }

  void bindPty(Pty newPty) {
    pty = newPty;
    pty!.output.cast<List<int>>().listen((data) {
      terminal.write(utf8.decode(data, allowMalformed: true));
    });
    pty!.exitCode.then((code) {
      terminal.write('\r\n[进程退出，代码：$code]\r\n');
    });

    terminal.onOutput = (data) {
      if (ctrlNotifier.value && data.length == 1) {
        final code = data.toLowerCase().codeUnitAt(0);
        if (code >= 97 && code <= 122) {
          pty?.write(Uint8List.fromList([code - 96]));
          ctrlNotifier.value = false;
          return;
        }
      }
      if (altNotifier.value && data.isNotEmpty) {
        pty?.write(utf8.encode('\x1b$data'));
        altNotifier.value = false;
        return;
      }
      pty?.write(utf8.encode(data));
    };

    terminal.onResize = (w, h, pw, ph) => pty?.resize(h, w);
  }

  String? getSelectedText() {
    final selection = controller.selection;
    if (selection == null || selection.isCollapsed) return null;
    final range = selection.normalized;
    final sb = StringBuffer();
    for (int y = range.begin.y; y <= range.end.y; y++) {
      if (y >= terminal.buffer.lines.length) break;
      final line = terminal.buffer.lines[y];
      final from = (y == range.begin.x) ? range.begin.x : 0;
      final to = (y == range.end.y) ? range.end.x : null;
      sb.write(line.getText(from, to));
      if (y < range.end.y) sb.writeln();
    }
    final result = sb.toString().trim();
    return result.isEmpty ? null : result;
  }

  String? extractUrl(String text) {
    final clean = text.replaceAll(boxDrawingPattern, '').replaceAll(RegExp(r'\s+'), '');
    final parts = clean.split(RegExp(r'(?=https?://)'));
    String? best;
    for (final part in parts) {
      final match = _anyUrlRegex.firstMatch(part);
      if (match != null) {
        final url = match.group(0)!;
        if (best == null || url.length > best.length) best = url;
      }
    }
    return best;
  }

  void copySelection(BuildContext context) {
    final text = getSelectedText();
    if (text == null) return;
    Clipboard.setData(ClipboardData(text: text));
    final url = extractUrl(text);
    if (url != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('已复制到剪贴板'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: '打开',
          onPressed: () {
            final uri = Uri.tryParse(url);
            if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
          },
        ),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已复制到剪贴板'), duration: Duration(seconds: 1)),
      );
    }
  }

  void openSelection(BuildContext context) {
    final text = getSelectedText();
    if (text == null) return;
    final url = extractUrl(text);
    if (url != null) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('选中内容未包含 URL'), duration: Duration(seconds: 1)),
    );
  }

  Future<void> paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      pty?.write(utf8.encode(data.text!));
    }
  }

  void handleTap(CellOffset offset) {
    final totalLines = terminal.buffer.lines.length;
    final startRow = (offset.y - 2).clamp(0, totalLines - 1);
    final endRow = (offset.y + 2).clamp(0, totalLines - 1);
    final sb = StringBuffer();
    for (int row = startRow; row <= endRow; row++) {
      sb.write(_getLineText(row).trimRight());
    }
    final url = extractUrl(sb.toString());
    if (url != null) _openUrl(url);
  }

  String _getLineText(int row) {
    try {
      final line = terminal.buffer.lines[row];
      final sb = StringBuffer();
      for (int i = 0; i < line.length; i++) {
        final char = line.getCodePoint(i);
        if (char != 0) sb.writeCharCode(char);
      }
      return sb.toString();
    } catch (_) {
      return '';
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('打开链接'),
        content: Text(url),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('链接已复制')));
              Navigator.pop(ctx, false);
            },
            child: const Text('复制'),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('打开')),
        ],
      ),
    );
    if (shouldOpen == true) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static TerminalStyle get terminalStyle => const TerminalStyle(
    fontSize: 11,
    height: 1.0,
    fontFamily: 'DejaVuSansMono',
    fontFamilyFallback: _fontFallback,
  );
}
