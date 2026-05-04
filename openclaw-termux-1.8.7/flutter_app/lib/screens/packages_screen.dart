import 'package:flutter/material.dart';
import '../app.dart';
import '../models/optional_package.dart';
import '../services/package_service.dart';
import 'package_install_screen.dart';

/// 可选包列表 — 安装/卸载开发工具
class PackagesScreen extends StatefulWidget {
  const PackagesScreen({super.key});

  @override
  State<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends State<PackagesScreen> {
  Map<String, bool> _statuses = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refreshStatuses();
  }

  Future<void> _refreshStatuses() async {
    final statuses = await PackageService.checkAllStatuses();
    if (mounted) {
      setState(() {
        _statuses = statuses;
        _loading = false;
      });
    }
  }

  Future<void> _navigateToInstall(OptionalPackage package, {bool isUninstall = false}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PackageInstallScreen(package: package, isUninstall: isUninstall),
      ),
    );
    if (result == true) _refreshStatuses();
  }

  void _confirmUninstall(OptionalPackage package) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('卸载 ${package.name}？'),
        content: Text('此操作将从环境中移除 ${package.name}。'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () { Navigator.pop(ctx); _navigateToInstall(package, isUninstall: true); },
            style: FilledButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('确认卸载'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('可选软件包'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 提示卡片
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.iconPackages.withAlpha(20), AppColors.iconPackages.withAlpha(5)]),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.iconPackages.withAlpha(30)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 20, color: AppColors.iconPackages),
                      const SizedBox(width: 12),
                      Expanded(child: Text('可在 Ubuntu 环境中安装的开发工具', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.iconPackages))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                for (final pkg in OptionalPackage.all)
                  _buildPackageCard(theme, pkg, isDark),
              ],
            ),
    );
  }

  Widget _buildPackageCard(ThemeData theme, OptionalPackage package, bool isDark) {
    final installed = _statuses[package.id] ?? false;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => installed ? null : _navigateToInstall(package),
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
                    gradient: LinearGradient(colors: [package.color.withAlpha(40), package.color.withAlpha(15)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(package.icon, color: package.color, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(package.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          if (installed) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [AppColors.statusGreen.withAlpha(30), AppColors.statusGreen.withAlpha(10)]),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('已安装', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.statusGreen, fontWeight: FontWeight.w700, fontSize: 11)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(package.description, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.storage_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(package.estimatedSize, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                installed
                    ? OutlinedButton(
                        onPressed: () => _confirmUninstall(package),
                        style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.redAccent.withAlpha(150)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                        child: const Text('卸载', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                      )
                    : FilledButton(
                        onPressed: () => _navigateToInstall(package),
                        style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10)),
                        child: const Text('安装', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
