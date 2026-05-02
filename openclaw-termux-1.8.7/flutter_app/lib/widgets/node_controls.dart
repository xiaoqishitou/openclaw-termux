import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../app.dart';
import '../models/node_state.dart';
import '../providers/node_provider.dart';
import '../screens/node_screen.dart';

class NodeControls extends StatelessWidget {
  const NodeControls({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<NodeProvider>(
      builder: (context, provider, _) {
        final state = provider.state;

        return Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? const LinearGradient(
                    colors: [Color(0xFF1A1A2E), Color(0xFF1E1040)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [const Color(0xFFF3E5F5), const Color(0xFFE8EAF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.iconNode.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.devices_rounded,
                        color: AppColors.iconNode,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '节点',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'AI 设备能力',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _statusBadge(state.status, theme),
                  ],
                ),
                const SizedBox(height: 12),
                if (state.isPaired) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.link_rounded, size: 16, color: AppColors.statusGreen),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${state.gatewayHost}:${state.gatewayPort}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 13,
                              color: AppColors.statusGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (state.pairingCode != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.statusAmber.withAlpha(15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.statusAmber.withAlpha(40)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.qr_code_rounded, color: AppColors.statusAmber, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          '配对码：',
                          style: theme.textTheme.bodyMedium,
                        ),
                        SelectableText(
                          state.pairingCode!,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (state.errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.statusRed.withAlpha(15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.statusRed.withAlpha(40)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.statusRed, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.errorMessage!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.statusRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (state.isDisabled)
                      FilledButton.icon(
                        onPressed: () => provider.enable(),
                        icon: const Icon(Icons.power_settings_new_rounded, size: 20),
                        label: const Text('启用节点'),
                      ),
                    if (!state.isDisabled) ...[
                      OutlinedButton.icon(
                        onPressed: () => provider.disable(),
                        icon: const Icon(Icons.stop_rounded, size: 20),
                        label: const Text('停用'),
                      ),
                      if (state.status == NodeStatus.error ||
                          state.status == NodeStatus.disconnected)
                        OutlinedButton.icon(
                          onPressed: () => provider.reconnect(),
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                          label: const Text('重新连接'),
                        ),
                    ],
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const NodeScreen()),
                      ),
                      icon: const Icon(Icons.settings_rounded, size: 20),
                      label: const Text('配置'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusBadge(NodeStatus status, ThemeData theme) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case NodeStatus.paired:
        color = AppColors.statusGreen;
        label = '已配对';
        icon = Icons.check_circle_outline_rounded;
      case NodeStatus.connecting:
      case NodeStatus.challenging:
      case NodeStatus.pairing:
        color = AppColors.statusAmber;
        label = '连接中';
        icon = Icons.hourglass_top;
      case NodeStatus.error:
        color = AppColors.statusRed;
        label = '错误';
        icon = Icons.error_outline_rounded;
      case NodeStatus.disabled:
        color = AppColors.statusGrey;
        label = '已停用';
        icon = Icons.circle_outlined;
      case NodeStatus.disconnected:
        color = AppColors.statusGrey;
        label = '已断开';
        icon = Icons.link_off_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
