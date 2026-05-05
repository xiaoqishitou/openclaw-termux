import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../constants.dart';
import '../services/preferences_service.dart';

class WebDashboardScreen extends StatefulWidget {
  final String? url;

  const WebDashboardScreen({super.key, this.url});

  @override
  State<WebDashboardScreen> createState() => _WebDashboardScreenState();
}

class _WebDashboardScreenState extends State<WebDashboardScreen> with WidgetsBindingObserver {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;
  String? _currentUrl;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..enableZoom(false)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() {
                _loading = false;
                _error = null;
                _retryCount = 0;
              });
            }
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _loading = false;
                _error = _formatError(error.errorCode, error.description);
              });
              _autoRetry();
            }
          },
          onNavigationRequest: (request) {
            return NavigationDecision.navigate;
          },
        ),
      );
    _loadUrl();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && _error != null) {
      _retry();
    }
  }

  String _formatError(int code, String desc) {
    if (code == -2) return '网络连接失败，请检查网络';
    if (code == -6) return '连接超时，网关可能未启动';
    if (code == -8) return '连接超时，请稍后重试';
    if (code == -11) return '资源加载失败';
    if (code == -100) return '服务器无响应';
    if (code == -101) return '连接被重置';
    if (code == -102) return '连接被拒绝，网关可能未启动';
    if (code == -105) return 'DNS 解析失败';
    if (code == -109) return '地址不可达';
    return '加载失败 ($code)：$desc';
  }

  Future<void> _loadUrl() async {
    var url = widget.url;
    if (url == null || url.isEmpty) {
      final prefs = PreferencesService();
      await prefs.init();
      url = prefs.dashboardUrl;
    }
    _currentUrl = url ?? AppConstants.gatewayUrl;
    _controller.loadRequest(Uri.parse(_currentUrl!));
  }

  void _autoRetry() {
    if (_retryCount >= _maxRetries) return;
    _retryCount++;
    Future.delayed(Duration(seconds: 2 * _retryCount), () {
      if (mounted && _error != null) {
        _controller.reload();
      }
    });
  }

  Future<void> _retry() async {
    setState(() {
      _error = null;
      _loading = true;
      _retryCount = 0;
    });
    await _loadUrl();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('对话'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _retry,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.wifi_off_rounded,
                      size: 56,
                      color: theme.colorScheme.error.withAlpha(150),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_retryCount > 0)
                      Text(
                        '已自动重试 $_retryCount 次',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
                        ),
                      ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('重新加载'),
                    ),
                  ],
                ),
              ),
            )
          else
            WebViewWidget(controller: _controller),
          if (_loading && _error == null)
            const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
