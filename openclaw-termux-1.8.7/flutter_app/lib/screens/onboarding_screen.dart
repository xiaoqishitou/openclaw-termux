import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import 'package:flutter_pty/flutter_pty.dart';
import '../constants.dart';
import '../services/native_bridge.dart';
import '../services/screenshot_service.dart';
import '../services/terminal_service.dart';
import '../services/preferences_service.dart';
import '../widgets/terminal_toolbar.dart';
import '../widgets/terminal_mixin.dart';
import 'dashboard_screen.dart';

/// OpenClaw 初始配置向导（终端模式）
class OnboardingScreen extends StatefulWidget {
  final bool isFirstRun;

  const OnboardingScreen({super.key, this.isFirstRun = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TerminalMixin {
  bool _finished = false;
  String _outputBuffer = '';

  static final _tokenUrlRegex = RegExp(
    r'https?://(?:localhost|127\.0\.0\.1):18789/#token=[0-9a-f]+',
  );
  static final _ansiEscape = AppConstants.ansiEscape;
  static final _completionPattern = RegExp(
    r'onboard(ing)?\s+(is\s+)?complete|successfully\s+onboarded|setup\s+complete',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    initTerminal();
    NativeBridge.startTerminalService();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startOnboarding());
  }

  @override
  void dispose() {
    NativeBridge.stopTerminalService();
    disposeTerminal();
    super.dispose();
  }

  Future<void> _startOnboarding() async {
    pty?.kill();
    pty = null;
    _outputBuffer = '';

    try {
      await _ensureResolvConf();

      final config = await TerminalService.getProotShellConfig();
      final args = TerminalService.buildProotArgs(
        config,
        columns: terminal.viewWidth,
        rows: terminal.viewHeight,
      );

      // 替换最后两个参数为 onboarding 命令
      final onboardingArgs = List<String>.from(args)
        ..removeLast()
        ..removeLast()
        ..addAll([
          '/bin/bash', '-lc',
          'echo "=== OpenClaw 初始配置 ===" && '
          'echo "配置 API 密钥和绑定设置" && '
          'echo "提示：选择 Loopback (127.0.0.1) 作为绑定地址！" && '
          'echo "" && '
          'openclaw onboard; '
          'echo "" && echo "配置完成！您可以关闭此页面。"',
        ]);

      final newPty = Pty.start(
        config['executable']!,
        arguments: onboardingArgs,
        environment: TerminalService.buildHostEnv(config),
        columns: terminal.viewWidth,
        rows: terminal.viewHeight,
      );

      _bindOnboardingPty(newPty);
      setState(() => loading = false);
    } catch (e) {
      setState(() {
        loading = false;
        error = '启动配置失败：$e';
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

  void _bindOnboardingPty(Pty newPty) {
    pty = newPty;

    pty!.output.cast<List<int>>().listen((data) {
      final text = utf8.decode(data, allowMalformed: true);
      terminal.write(text);
      _outputBuffer += text;
      if (_outputBuffer.length > 4096) {
        _outputBuffer = _outputBuffer.substring(_outputBuffer.length - 2048);
      }

      final cleanText = _outputBuffer.replaceAll(_ansiEscape, '');
      final cleanForUrl = cleanText
          .replaceAll(TerminalMixin.boxDrawingPattern, '')
          .replaceAll(RegExp(r'\s+'), '');

      final tokenMatch = _tokenUrlRegex.firstMatch(cleanForUrl);
      if (tokenMatch != null) _saveTokenUrl(tokenMatch.group(0)!);

      if (!_finished && _completionPattern.hasMatch(cleanText)) {
        if (mounted) setState(() => _finished = true);
      }
    });

    pty!.exitCode.then((code) {
      terminal.write('\r\n[配置程序退出，代码：$code]\r\n');
      if (mounted) setState(() => _finished = true);
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

  Future<void> _saveTokenUrl(String url) async {
    final prefs = PreferencesService();
    await prefs.init();
    prefs.dashboardUrl = url;
  }

  Future<void> _takeScreenshot() async {
    final path = await ScreenshotService.capture(screenshotKey, prefix: 'onboarding');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(path != null ? '截图已保存：${path.split('/').last}' : '截图失败'),
      ),
    );
  }

  Future<void> _goToDashboard() async {
    final navigator = Navigator.of(context);
    final prefs = PreferencesService();
    await prefs.init();
    prefs.setupComplete = true;
    prefs.isFirstRun = false;
    if (mounted) {
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('初始配置'),
        leading: widget.isFirstRun
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
        automaticallyImplyLeading: false,
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
        ],
      ),
      body: Column(
        children: [
          if (loading)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      '正在启动配置...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else if (error != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            loading = true;
                            error = null;
                            _finished = false;
                          });
                          _startOnboarding();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
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
          if (_finished)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.isFirstRun ? _goToDashboard : () => Navigator.of(context).pop(),
                  icon: Icon(widget.isFirstRun ? Icons.arrow_forward : Icons.check),
                  label: Text(widget.isFirstRun ? '进入仪表盘' : '完成'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
