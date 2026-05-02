import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../app.dart';
import '../constants.dart';
import '../providers/gateway_provider.dart';
import '../providers/node_provider.dart';
import '../widgets/gateway_controls.dart';
import '../widgets/status_card.dart';
import 'node_screen.dart';
import 'configure_screen.dart';
import 'onboarding_screen.dart';
import 'terminal_screen.dart';
import 'web_dashboard_screen.dart';
import 'logs_screen.dart';
import 'packages_screen.dart';
import 'providers_screen.dart';
import 'settings_screen.dart';
import 'ssh_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.accent.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.hub, color: AppColors.accent, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'OpenClaw',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gateway Control Card
            const GatewayControls(),
            const SizedBox(height: 24),

            // Quick Actions Section Header
            _sectionHeader(context, '快捷入口', Icons.apps_rounded),
            const SizedBox(height: 8),

            // Grid layout for quick actions
            Consumer<GatewayProvider>(
              builder: (context, gatewayProvider, _) {
                final state = gatewayProvider.state;
                final url = state.dashboardUrl;
                final token = url != null
                    ? RegExp(r'#token=([0-9a-f]+)').firstMatch(url)?.group(1)
                    : null;

                return Consumer<NodeProvider>(
                  builder: (context, nodeProvider, _) {
                    final nodeState = nodeProvider.state;

                    return Column(
                      children: [
                        // Row 1: Core tools
                        Row(
                          children: [
                            Expanded(
                              child: _QuickActionCard(
                                title: '终端',
                                subtitle: 'Ubuntu Shell',
                                icon: Icons.terminal_rounded,
                                color: AppColors.iconTerminal,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const TerminalScreen()),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _QuickActionCard(
                                title: '仪表盘',
                                subtitle: token != null
                                    ? '令牌: ${token.substring(0, (token.length > 8 ? 8 : token.length))}...'
                                    : state.isRunning ? '打开 Web UI' : '请先启动网关',
                                icon: Icons.dashboard_rounded,
                                color: AppColors.iconDashboard,
                                enabled: state.isRunning,
                                onTap: state.isRunning
                                    ? () => Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => WebDashboardScreen(url: url),
                                          ),
                                        )
                                    : null,
                                trailing: state.isRunning && token != null
                                    ? GestureDetector(
                                        onTap: () {
                                          Clipboard.setData(ClipboardData(text: url!));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('仪表盘 URL 已复制')),
                                          );
                                        },
                                        child: const Icon(Icons.copy_rounded, size: 16, color: AppColors.statusBlue),
                                      )
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Row 2: Configuration
                        Row(
                          children: [
                            Expanded(
                              child: _QuickActionCard(
                                title: '配置向导',
                                subtitle: 'API 密钥与绑定',
                                icon: Icons.vpn_key_rounded,
                                color: AppColors.iconOnboarding,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _QuickActionCard(
                                title: '网关设置',
                                subtitle: 'Gateway 配置',
                                icon: Icons.tune_rounded,
                                color: AppColors.iconConfigure,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const ConfigureScreen()),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Row 3: AI & Packages
                        Row(
                          children: [
                            Expanded(
                              child: _QuickActionCard(
                                title: 'AI 提供商',
                                subtitle: '模型与 API 密钥',
                                icon: Icons.psychology_rounded,
                                color: AppColors.iconProviders,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const ProvidersScreen()),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _QuickActionCard(
                                title: '软件包',
                                subtitle: 'Go、Homebrew、SSH',
                                icon: Icons.extension_rounded,
                                color: AppColors.iconPackages,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const PackagesScreen()),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Row 4: Advanced
                        Row(
                          children: [
                            Expanded(
                              child: _QuickActionCard(
                                title: 'SSH 远程',
                                subtitle: '远程终端访问',
                                icon: Icons.shield_rounded,
                                color: AppColors.iconSsh,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const SshScreen()),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _QuickActionCard(
                                title: '日志',
                                subtitle: '网关输出',
                                icon: Icons.article_outlined,
                                color: AppColors.iconLogs,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const LogsScreen()),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Row 5: Node & Snapshot
                        Row(
                          children: [
                            Expanded(
                              child: _QuickActionCard(
                                title: 'Node',
                                subtitle: nodeState.isPaired
                                    ? '已连接'
                                    : nodeState.isDisabled
                                        ? '设备能力'
                                        : nodeState.statusText,
                                icon: Icons.devices_rounded,
                                color: AppColors.iconNode,
                                badge: nodeState.isPaired ? '已配对' : null,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const NodeScreen()),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _QuickActionCard(
                                title: '快照',
                                subtitle: '备份与恢复',
                                icon: Icons.backup_rounded,
                                color: AppColors.iconSnapshot,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 28),

            // Footer
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'OpenClaw v${AppConstants.version}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '·',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          AppConstants.orgName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.mutedText),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

/// Compact quick action card with colored icon, for grid layout.
class _QuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? badge;

  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.enabled = true,
    this.onTap,
    this.trailing,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withAlpha(isDark ? 25 : 20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const Spacer(),
                    if (trailing != null) trailing!,
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.statusGreen.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badge!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.statusGreen,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
