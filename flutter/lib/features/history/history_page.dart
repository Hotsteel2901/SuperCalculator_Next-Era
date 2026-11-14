import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../core/history/history_repository.dart';
import '../../core/settings/app_settings.dart';
import '../../core/ui/expressive/expressive_widgets.dart';
import '../../core/ui/expressive/motion.dart';
import '../../core/ui/feature_widgets.dart';

/// Local, offline calculation history.
///
/// The retention limit and the record-on-evaluate switch both come from the
/// settings, so the page header can state exactly what is stored instead of
/// hard-coding a count that no longer matches the repository.
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(calculationHistoryProvider);
    final controller = ref.read(calculationHistoryProvider.notifier);
    final settings = ref.watch(appSettingsProvider);
    final tokens = SuperCalcDesignTokens.of(context);
    final scheme = Theme.of(context).colorScheme;

    return FeaturePageFrame(
      title: nextEraText(context, 'History', '历史记录'),
      icon: Icons.history_rounded,
      subtitle: settings.autoSaveHistory
          ? nextEraText(
              context,
              'Up to ${settings.historyLimit} results are kept on this device.',
              '本设备最多保留 ${settings.historyLimit} 条结果。',
            )
          : nextEraText(
              context,
              'Recording is off — nothing new is stored.',
              '已关闭记录 —— 不会保存新的结果。',
            ),
      actions: <Widget>[
        AppTooltip(
          message: nextEraText(context, 'Copy JSON', '复制 JSON'),
          child: IconButton(
            onPressed: entries.isEmpty
                ? null
                : () => copyToClipboard(context, controller.exportJson()),
            icon: const Icon(Icons.data_object_rounded),
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (!settings.autoSaveHistory) ...<Widget>[
            AppCard(
              color: scheme.tertiaryContainer.withValues(alpha: 0.55),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.pause_circle_outline_rounded,
                    color: scheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      nextEraText(
                        context,
                        'Automatic recording is disabled in Settings › Input.',
                        '自动记录已在“设置 › 输入”中关闭。',
                      ),
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: scheme.onTertiaryContainer),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: tokens.cardGap),
          ],
          FeatureCard(
            title: nextEraText(context, 'Recent calculations', '最近计算'),
            icon: Icons.list_alt_rounded,
            child: entries.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Column(
                      children: <Widget>[
                        Icon(
                          Icons.history_toggle_off_rounded,
                          size: 44,
                          color: scheme.outline,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          nextEraText(
                            context,
                            'No calculations yet.',
                            '暂无计算记录。',
                          ),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          nextEraText(
                            context,
                            'Evaluate a plot or an expression to fill this list.',
                            '计算一个表达式或绘图后，这里就会出现记录。',
                          ),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: <Widget>[
                      for (final entry in entries.asMap().entries) ...<Widget>[
                        StaggeredEntry(
                          index: entry.key,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: scheme.secondaryContainer,
                              child: Icon(
                                Icons.functions_rounded,
                                size: 18,
                                color: scheme.onSecondaryContainer,
                              ),
                            ),
                            title: Text(
                              entry.value.expression,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${entry.value.backend} · '
                              '${_formatTimestamp(entry.value.createdAt)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  entry.value.result,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                AppTooltip(
                                  message: nextEraText(
                                    context,
                                    'Copy result',
                                    '复制结果',
                                  ),
                                  child: IconButton(
                                    onPressed: () => copyToClipboard(
                                      context,
                                      '${entry.value.expression} = '
                                      '${entry.value.result}',
                                    ),
                                    icon: const Icon(
                                      Icons.content_copy_rounded,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                AppTooltip(
                                  message: nextEraText(
                                    context,
                                    'Delete entry',
                                    '删除该条',
                                  ),
                                  child: IconButton(
                                    onPressed: () =>
                                        controller.removeAt(entry.key),
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (entry.key != entries.length - 1)
                          const SoftDivider(),
                      ],
                    ],
                  ),
          ),
          SizedBox(height: tokens.cardGap),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: entries.isEmpty
                    ? null
                    : () => copyToClipboard(context, controller.exportCsv()),
                icon: const Icon(Icons.grid_on_rounded),
                label: Text(nextEraText(context, 'Copy CSV', '复制 CSV')),
              ),
              OutlinedButton.icon(
                onPressed: entries.isEmpty
                    ? null
                    : () => copyToClipboard(context, controller.exportJson()),
                icon: const Icon(Icons.data_object_rounded),
                label: Text(nextEraText(context, 'Copy JSON', '复制 JSON')),
              ),
              TextButton.icon(
                onPressed: entries.isEmpty ? null : controller.clear,
                icon: const Icon(Icons.delete_sweep_rounded),
                label: Text(nextEraText(context, 'Clear history', '清空历史')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            nextEraText(
              context,
              'Storage is best-effort; private browsing or restricted profiles may keep history session-only.',
              '存储采用尽力而为策略；隐私浏览或受限配置可能只保留当前会话。',
            ),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  static String _formatTimestamp(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}
