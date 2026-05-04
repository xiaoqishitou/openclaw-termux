import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_pty/flutter_pty.dart';
import '../app.dart';

/// Termux 风格终端工具栏 — ESC/CTRL/ALT/TAB/方向键等
class TerminalToolbar extends StatefulWidget {
  final Pty? pty;
  final ValueNotifier<bool> ctrlNotifier;
  final ValueNotifier<bool> altNotifier;

  const TerminalToolbar({super.key, required this.pty, required this.ctrlNotifier, required this.altNotifier});

  @override
  State<TerminalToolbar> createState() => _TerminalToolbarState();
}

class _TerminalToolbarState extends State<TerminalToolbar> {
  bool get _ctrlActive => widget.ctrlNotifier.value;
  bool get _altActive => widget.altNotifier.value;

  @override
  void initState() { super.initState(); widget.ctrlNotifier.addListener(_onModifierChanged); widget.altNotifier.addListener(_onModifierChanged); }
  @override
  void dispose() { widget.ctrlNotifier.removeListener(_onModifierChanged); widget.altNotifier.removeListener(_onModifierChanged); super.dispose(); }

  void _onModifierChanged() => setState(() {});

  void _send(String data) {
    final pty = widget.pty; if (pty == null) return;
    if (_ctrlActive) { widget.ctrlNotifier.value = false; if (data.length == 1) { final code = data.toLowerCase().codeUnitAt(0); if (code >= 97 && code <= 122) { pty.write(Uint8List.fromList([code - 96])); return; } }
      const ctrlSeqMap = <String,String>{'\x1b[A':'\x1b[1;5A','\x1b[B':'\x1b[1;5B','\x1b[D':'\x1b[1;5D','\x1b[C':'\x1b[1;5C','\x1b[H':'\x1b[1;5H','\x1b[F':'\x1b[1;5F','\x1b[5~':'\x1b[5;5~','\x1b[6~':'\x1b[6;5~'};
      final cv = ctrlSeqMap[data]; if (cv != null) { pty.write(utf8.encode(cv)); return; }
      pty.write(utf8.encode(data)); return;
    }
    if (_altActive) { widget.altNotifier.value = false; pty.write(utf8.encode('\x1b$data')); return; }
    pty.write(utf8.encode(data));
  }

  void _toggleCtrl() { widget.ctrlNotifier.value = !_ctrlActive; if (_ctrlActive) widget.altNotifier.value = false; }
  void _toggleAlt() { widget.altNotifier.value = !_altActive; if (_altActive) widget.ctrlNotifier.value = false; }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF2F2F2);
    final btnColor = isDark ? AppColors.darkSurfaceAlt : Colors.grey.shade200;
    const activeColor = AppColors.accent;
    final textColor = isDark ? Colors.white70 : Colors.black87;
    final inactiveColor = textColor.withAlpha(180);

    Widget keyBtn(String label, {VoidCallback? onTap, String? sendData, bool active = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: active ? activeColor : btnColor,
          borderRadius: BorderRadius.circular(8),
          elevation: active ? 2 : 0,
          shadowColor: active ? activeColor.withAlpha(80) : Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap ?? () => _send(sendData ?? label),
            child: Container(
              constraints: const BoxConstraints(minWidth: 38, minHeight: 36),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? Colors.white : (active ? Colors.white : inactiveColor), fontFamily: 'monospace')),
            ),
          ),
        ),
      );
    }

    Widget arrowBtn(IconData icon, String seq) {
      return Padding(padding: const EdgeInsets.symmetric(horizontal: 1.5), child: Material(color: btnColor, borderRadius: BorderRadius.circular(8), child: InkWell(borderRadius: BorderRadius.circular(8), onTap: () => _send(seq), child: Container(constraints: const BoxConstraints(minWidth: 36, minHeight: 36), alignment: Alignment.center, child: Icon(icon, size: 17, color: textColor)))));
    }

    return Container(
      color: bgColor,
      child: SafeArea(top: false, child: SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5), child: Row(children: [
        // 第一组：修饰键
        keyBtn('ESC', sendData: '\x1b'),
        Container(width: 1, height: 28, margin: const EdgeInsets.symmetric(horizontal: 4), color: isDark ? Colors.white24 : Colors.black12),
        keyBtn('Ctrl', onTap: _toggleCtrl, active: _ctrlActive),
        keyBtn('Alt', onTap: _toggleAlt, active: _altActive),
        keyBtn('Tab', sendData: '\t'),
        keyBtn('↵', sendData: '\r'),
        const SizedBox(width: 6),

        // 方向键
        arrowBtn(Icons.keyboard_arrow_up, '\x1b[A'),
        arrowBtn(Icons.keyboard_arrow_down, '\x1b[B'),
        arrowBtn(Icons.keyboard_arrow_left, '\x1b[D'),
        arrowBtn(Icons.keyboard_arrow_right, '\x1b[C'),
        const SizedBox(width: 6),

        // 导航键
        keyBtn('Home', sendData: '\x1b[H'),
        keyBtn('End', sendData: '\x1b[F'),
        keyBtn('PgUp', sendData: '\x1b[5~'),
        keyBtn('PgDn', sendData: '\x1b[6~'),
        const SizedBox(width: 6),

        // 符号键
        keyBtn('-', sendData: '-'),
        keyBtn('/', sendData: '/'),
        keyBtn('|', sendData: '|'),
        keyBtn('~', sendData: '~'),
        keyBtn('_', sendData: '_'),
      ]))),
    );
  }
}
