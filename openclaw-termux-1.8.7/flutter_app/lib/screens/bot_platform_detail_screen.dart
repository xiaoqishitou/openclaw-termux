import 'package:flutter/material.dart';
import '../app.dart';
import '../models/bot_platform.dart';
import '../services/bot_config_service.dart';

/// 机器人平台详情配置页
class BotPlatformDetailScreen extends StatefulWidget {
  final BotPlatform platform;
  final Map<String, dynamic>? existingConfig;

  const BotPlatformDetailScreen({
    super.key,
    required this.platform,
    this.existingConfig,
  });

  @override
  State<BotPlatformDetailScreen> createState() => _BotPlatformDetailScreenState();
}

class _BotPlatformDetailScreenState extends State<BotPlatformDetailScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _obscureFields = {};
  bool _enabled = false;
  bool _saving = false;
  bool _removing = false;

  bool get _isConfigured => widget.existingConfig != null;

  @override
  void initState() {
    super.initState();
    final existingValues = widget.existingConfig?['config'] as Map<String, dynamic>? ?? {};
    _enabled = widget.existingConfig?['enabled'] as bool? ?? false;

    for (final field in widget.platform.configFields) {
      _controllers[field.key] = TextEditingController(
        text: existingValues[field.key]?.toString() ?? '',
      );
      if (field.isSecret) {
        _obscureFields[field.key] = true;
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final values = <String, String>{};
    for (final field in widget.platform.configFields) {
      values[field.key] = _controllers[field.key]!.text.trim();
    }

    setState(() => _saving = true);
    try {
      await BotConfigService.savePlatformConfig(
        platform: widget.platform,
        values: values,
        enabled: _enabled,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.platform.name} 已保存')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('移除 ${widget.platform.name}？'),
        content: const Text('此操作将删除该平台的配置。'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('确认移除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _removing = true);
    try {
      await BotConfigService.removePlatformConfig(widget.platform);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.platform.name} 已移除')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('移除失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(widget.platform.name), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 平台信息卡片
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.darkElevated.withAlpha(80) : Colors.grey.shade200),
              color: isDark ? AppColors.darkElevated : Colors.white,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [widget.platform.color.withAlpha(40), widget.platform.color.withAlpha(15)]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(widget.platform.icon, color: widget.platform.color, size: 28),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.platform.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(widget.platform.description, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // 启用开关
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? AppColors.darkElevated.withAlpha(80) : Colors.grey.shade200),
              color: isDark ? AppColors.darkElevated : Colors.white,
            ),
            child: SwitchListTile(
              title: const Text('启用平台', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('开启后将尝试连接此平台'),
              value: _enabled,
              activeColor: AppColors.accent,
              onChanged: (v) => setState(() => _enabled = v),
            ),
          ),
          const SizedBox(height: 24),

          // 配置字段
          Text('配置项', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          for (final field in widget.platform.configFields) ...[
            TextField(
              controller: _controllers[field.key],
              obscureText: _obscureFields[field.key] ?? false,
              decoration: InputDecoration(
                labelText: field.label,
                hintText: field.hint,
                prefixIcon: Icon(
                  field.isSecret ? Icons.key_outlined : Icons.settings_outlined,
                  size: 20,
                  color: isDark ? AppColors.mutedText : Colors.grey,
                ),
                suffixIcon: field.isSecret
                    ? IconButton(
                        icon: Icon(
                          _obscureFields[field.key]! ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscureFields[field.key] = !(_obscureFields[field.key] ?? false)),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 20),

          // 操作按钮
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('保存配置', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
          if (_isConfigured) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: _removing ? null : _remove,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.redAccent.withAlpha(150)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _removing
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('移除配置', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
