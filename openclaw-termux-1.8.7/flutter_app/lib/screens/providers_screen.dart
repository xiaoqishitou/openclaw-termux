import 'package:flutter/material.dart';
import '../app.dart';
import '../models/ai_provider.dart';
import '../services/provider_config_service.dart';
import 'provider_detail_screen.dart';

/// AI 提供商列表 — 配置 API 密钥和模型
class ProvidersScreen extends StatefulWidget {
  const ProvidersScreen({super.key});

  @override
  State<ProvidersScreen> createState() => _ProvidersScreenState();
}

class _ProvidersScreenState extends State<ProvidersScreen> {
  String? _activeModel;
  Map<String, dynamic> _providers = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final config = await ProviderConfigService.readConfig();
    if (mounted) {
      setState(() {
        _activeModel = config['activeModel'] as String?;
        _providers = config['providers'] as Map<String, dynamic>? ?? {};
        _loading = false;
      });
    }
  }

  Future<void> _openProvider(AiProvider provider) async {
    final providerConfig = _providers[provider.id] as Map<String, dynamic>?;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProviderDetailScreen(
          provider: provider,
          existingApiKey: providerConfig?['apiKey'] as String?,
          existingModel: _activeModel,
        ),
      ),
    );
    if (result == true) {
      _refresh();
    }
  }

  String _statusLabel(AiProvider provider) {
    final isConfigured = _providers.containsKey(provider.id);
    if (!isConfigured) return '';
    if (_activeModel != null) {
      final isActive = provider.defaultModels.any((m) => _activeModel!.contains(m)) ||
          _activeModel!.contains(provider.id);
      if (isActive) return '使用中';
    }
    return '已配置';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 提供商'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 当前活跃模型卡片
                if (_activeModel != null && _activeModel!.isNotEmpty) ...[
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.statusGreen.withAlpha(30), AppColors.statusGreen.withAlpha(10)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.statusGreen.withAlpha(40)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.statusGreen.withAlpha(25),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.check_circle, color: AppColors.statusGreen, size: 26),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '当前活跃模型',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: AppColors.statusGreen,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _activeModel!,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                Text(
                  '选择提供商以配置 API 密钥和模型',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                for (final provider in AiProvider.all)
                  _buildProviderCard(theme, provider, isDark),
              ],
            ),
    );
  }

  Widget _buildProviderCard(ThemeData theme, AiProvider provider, bool isDark) {
    final status = _statusLabel(provider);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _openProvider(provider),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.darkElevated.withAlpha(80) : Colors.grey.shade200),
            color: isDark ? AppColors.darkElevated : Colors.white,
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                // 图标容器
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [provider.color.withAlpha(40), provider.color.withAlpha(15)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(provider.icon, color: provider.color, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            provider.name,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (status.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: (status == '使用中'
                                      ? [AppColors.statusGreen.withAlpha(30), AppColors.statusGreen.withAlpha(10)]
                                      : [AppColors.statusAmber.withAlpha(30), AppColors.statusAmber.withAlpha(10)]),
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: status == '使用中' ? AppColors.statusGreen : AppColors.statusAmber,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        provider.description,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
