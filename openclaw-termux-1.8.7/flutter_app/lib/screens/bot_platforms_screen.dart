import 'package:flutter/material.dart';
import '../app.dart';
import '../models/bot_platform.dart';
import '../services/bot_config_service.dart';
import 'bot_platform_detail_screen.dart';

/// 机器人平台配置列表
class BotPlatformsScreen extends StatefulWidget {
  const BotPlatformsScreen({super.key});

  @override
  State<BotPlatformsScreen> createState() => _BotPlatformsScreenState();
}

class _BotPlatformsScreenState extends State<BotPlatformsScreen> {
  Map<String, dynamic> _platforms = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final config = await BotConfigService.readConfig();
    if (mounted) {
      setState(() {
        _platforms = config['platforms'] as Map<String, dynamic>? ?? {};
        _loading = false;
      });
    }
  }

  Future<void> _openPlatform(BotPlatform platform) async {
    final platformConfig = _platforms[platform.id] as Map<String, dynamic>?;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BotPlatformDetailScreen(
          platform: platform,
          existingConfig: platformConfig,
        ),
      ),
    );
    if (result == true) {
      _refresh();
    }
  }

  String _statusLabel(BotPlatform platform) {
    final config = _platforms[platform.id] as Map<String, dynamic>?;
    if (config == null) return '';
    final enabled = config['enabled'] as bool? ?? false;
    return enabled ? '已启用' : '已配置';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('机器人平台'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.iconNode.withAlpha(20), AppColors.iconNode.withAlpha(5)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.iconNode.withAlpha(30)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 20, color: AppColors.iconNode),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '配置机器人平台以接入飞书、微信、QQ、Discord 等',
                          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.iconNode),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                for (final platform in BotPlatform.all)
                  _buildPlatformCard(theme, platform, isDark),
              ],
            ),
    );
  }

  Widget _buildPlatformCard(ThemeData theme, BotPlatform platform, bool isDark) {
    final status = _statusLabel(platform);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _openPlatform(platform),
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
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [platform.color.withAlpha(40), platform.color.withAlpha(15)]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(platform.icon, color: platform.color, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              platform.name,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            if (status.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: (status == '已启用'
                                        ? [AppColors.statusGreen.withAlpha(30), AppColors.statusGreen.withAlpha(10)]
                                        : [AppColors.statusAmber.withAlpha(30), AppColors.statusAmber.withAlpha(10)]),
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  status,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: status == '已启用' ? AppColors.statusGreen : AppColors.statusAmber,
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
                          platform.description,
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
      ),
    );
  }
}
