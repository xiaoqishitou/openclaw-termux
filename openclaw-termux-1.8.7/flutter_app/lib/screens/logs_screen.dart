import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app.dart';
import '../providers/gateway_provider.dart';
import '../services/screenshot_service.dart';

/// 网关日志页面
class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _screenshotKey = GlobalKey();
  bool _autoScroll = true;
  String _filter = '';

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('网关日志'),
        actions: [
          IconButton(icon: const Icon(Icons.camera_alt_outlined), tooltip: '截图', onPressed: _takeScreenshot),
          IconButton(
            icon: Icon(_autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_top),
            tooltip: _autoScroll ? '自动滚动：开' : '自动滚动：关',
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
          IconButton(icon: const Icon(Icons.copy_all), tooltip: '复制全部日志', onPressed: () => _copyLogs(context)),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceAlt : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? AppColors.darkElevated.withAlpha(80) : Colors.grey.shade200),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索日志...',
                hintStyle: TextStyle(color: isDark ? AppColors.mutedText : Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: InputBorder.none,
                suffixIcon: _filter.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () { _searchController.clear(); setState(() => _filter = ''); },
                      )
                    : null,
              ),
              onChanged: (value) => setState(() => _filter = value),
            ),
          ),

          // 日志列表
          Expanded(
            child: RepaintBoundary(
              key: _screenshotKey,
              child: Consumer<GatewayProvider>(
                builder: (context, provider, _) {
                  final logs = provider.state.logs;
                  final filtered = _filter.isEmpty
                      ? logs
                      : logs.where((l) => l.toLowerCase().contains(_filter.toLowerCase())).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.article_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant.withAlpha(150)),
                          const SizedBox(height: 12),
                          Text(
                            logs.isEmpty ? '暂无日志，请先启动网关' : '没有匹配的日志',
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    );
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_autoScroll && _scrollController.hasClients) {
                      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                    }
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final line = filtered[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1.5),
                        child: SelectableText(line, style: TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: _logColor(line, theme))),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _logColor(String line, ThemeData theme) {
    if (line.contains('[ERR]') || line.contains('ERROR')) return theme.colorScheme.error;
    if (line.contains('[WARN]') || line.contains('WARNING')) return AppColors.statusAmber;
    if (line.contains('[INFO]')) return AppColors.mutedText;
    return theme.colorScheme.onSurface;
  }

  Future<void> _takeScreenshot() async {
    final path = await ScreenshotService.capture(_screenshotKey, prefix: 'logs');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(path != null ? '截图已保存：${path.split('/').last}' : '截图失败'),
    ));
  }

  void _copyLogs(BuildContext context) {
    final provider = context.read<GatewayProvider>();
    final text = provider.state.logs.join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('日志已复制到剪贴板')));
  }
}
