import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../github/client.dart';
import '../../github/models.dart';
import 'board_layout.dart';
import 'card_actions.dart';
import 'common.dart';

class BoardListView extends StatelessWidget {
  final GitHub gh;
  final Board board;
  final List<Option> options;
  final Map<String?, List<Item>> itemsByOption;
  final Map<String, ColumnConfig> columnConfigs;
  final Map<String, Color> colors;
  final void Function(Option) onEditColumn;
  final void Function(Item, String) onMove;
  final ValueChanged<Item> onItemChanged;
  final double? Function(Option?) estimateSum;
  final void Function(Option?) onCreate;
  final bool dense;
  final bool selecting;
  final Set<String> selected;
  final ValueChanged<Item>? onToggleSelect;

  const BoardListView({
    super.key,
    required this.gh,
    required this.board,
    required this.options,
    required this.itemsByOption,
    required this.columnConfigs,
    required this.colors,
    required this.onEditColumn,
    required this.onMove,
    required this.onItemChanged,
    required this.estimateSum,
    required this.onCreate,
    this.dense = false,
    this.selecting = false,
    this.selected = const {},
    this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    final entries = <_ListEntry>[];

    void addSection(Option? option, List<Item> items, {bool always = false}) {
      if (items.isEmpty && !always) return;
      entries.add(_ListEntry.header(option, items.length));
      for (final item in items) {
        entries.add(_ListEntry.item(option, item));
      }
    }

    for (final option in options) {
      addSection(option, itemsByOption[option.id] ?? const [], always: true);
    }
    addSection(null, itemsByOption[null] ?? const []);

    if (entries.isEmpty) {
      return _EmptyList(hasItems: board.items.isNotEmpty);
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 0, 16, dense ? 8 : 16),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final option = entry.option;
        if (entry.item == null) {
          return _SectionHeader(
            title: option == null
                ? 'Sin estado'
                : columnDisplayName(option, columnConfigs),
            count: entry.count,
            estimateSum: estimateSum(option),
            color: _accent(option),
            dense: dense,
            onAdd: () => onCreate(option),
            onEdit: option == null ? null : () => onEditColumn(option),
          );
        }
        return _ItemRow(
          gh: gh,
          board: board,
          item: entry.item!,
          accent: _accent(option),
          status: option == null
              ? 'Sin estado'
              : columnDisplayName(option, columnConfigs),
          columnColors: colors,
          onMove: onMove,
          onItemChanged: onItemChanged,
          dense: dense,
          selecting: selecting,
          selected: selected.contains(entry.item!.id),
          onToggleSelect: onToggleSelect == null
              ? null
              : () => onToggleSelect!(entry.item!),
        );
      },
    );
  }

  Color _accent(Option? option) =>
      option == null ? noStatusColor : colors[option.id] ?? noStatusColor;
}

class _EmptyList extends StatelessWidget {
  final bool hasItems;

  const _EmptyList({required this.hasItems});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasItems
                  ? Icons.filter_alt_off_outlined
                  : Icons.view_list_outlined,
              size: 40,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              hasItems
                  ? 'Ninguna tarjeta coincide con los filtros.'
                  : 'Sin tarjetas',
            ),
            if (!hasItems) ...[
              const SizedBox(height: 4),
              Text(
                'Añade issues o pull requests a este proyecto en GitHub.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final double? estimateSum;
  final Color color;
  final bool dense;
  final VoidCallback onAdd;
  final VoidCallback? onEdit;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.estimateSum,
    required this.color,
    required this.dense,
    required this.onAdd,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(2, dense ? 8 : 14, 2, dense ? 4 : 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          if (estimateSum != null)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(
                '${formatPoints(estimateSum!)} pts',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ),
          IconButton(
            tooltip: 'Añadir tarjeta a $title',
            icon: const Icon(Icons.add, size: 20),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: onAdd,
          ),
          if (onEdit != null)
            IconButton(
              tooltip: 'Personalizar columna',
              icon: const Icon(Icons.more_horiz, size: 18),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              onPressed: onEdit,
            ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final GitHub gh;
  final Board board;
  final Item item;
  final Color accent;
  final String status;
  final Map<String, Color> columnColors;
  final void Function(Item, String) onMove;
  final ValueChanged<Item> onItemChanged;
  final bool dense;
  final bool selecting;
  final bool selected;
  final VoidCallback? onToggleSelect;

  const _ItemRow({
    required this.gh,
    required this.board,
    required this.item,
    required this.accent,
    required this.status,
    required this.columnColors,
    required this.onMove,
    required this.onItemChanged,
    required this.dense,
    required this.selecting,
    required this.selected,
    required this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (icon, iconColor) = itemIcon(item);
    final (checkI, checkC) = checkIcon(item.checksState);

    return Semantics(
      container: true,
      button: true,
      label: [
        item.title,
        item.ref,
        status,
        if (item.assignees.isNotEmpty)
          'asignado a ${item.assignees.join(', ')}',
      ].join('. '),
      child: Padding(
        padding: EdgeInsets.only(bottom: dense ? 2 : 6),
        child: Material(
          color: selected
              ? cs.primary.withValues(alpha: .08)
              : cs.surfaceContainerLow,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(dense ? 8 : 10),
            side: BorderSide(color: selected ? cs.primary : cs.outlineVariant),
          ),
          child: InkWell(
            onTap: selecting
                ? onToggleSelect
                : () => openItemDetail(context, gh, item, onItemChanged),
            onSecondaryTapDown: (details) => showItemMenu(
              context,
              details: details,
              item: item,
              board: board,
              columnColors: columnColors,
              onMove: onMove,
              onOpen: () => openItemDetail(context, gh, item, onItemChanged),
            ),
            child: Container(
              constraints: dense ? const BoxConstraints(minHeight: 44) : null,
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: accent, width: 3)),
              ),
              padding: EdgeInsets.fromLTRB(
                dense ? 6 : 10,
                dense ? 4 : 8,
                4,
                dense ? 4 : 8,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selecting) ...[
                    Checkbox(
                      value: selected,
                      onChanged: (_) => onToggleSelect?.call(),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                    ),
                    const SizedBox(width: 2),
                  ],
                  if (!dense)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(icon, size: 16, color: iconColor),
                    ),
                  if (!dense) const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              item.ref,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: .12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  status,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: accent,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.title,
                          maxLines: dense ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: dense ? 12.5 : 13,
                            height: 1.3,
                            fontWeight: FontWeight.w500,
                            color: item.hidden
                                ? cs.onSurfaceVariant
                                : cs.onSurface,
                          ),
                        ),
                        if (!dense && item.labels.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            children: [
                              for (final label in item.labels) LabelChip(label),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (item.commentCount != null && item.commentCount! > 0)
                    _RowMeta(
                      icon: Icons.mode_comment_outlined,
                      text: '${item.commentCount}',
                    ),
                  if (item.estimate != null)
                    _RowMeta(
                      icon: Icons.speed,
                      text: formatPoints(item.estimate!),
                    ),
                  if (checkI != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 1),
                      child: Tooltip(
                        message: 'Checks: ${item.checksState}',
                        child: Icon(checkI, size: 14, color: checkC),
                      ),
                    ),
                  if (item.avatar != null && !dense)
                    Padding(
                      padding: const EdgeInsets.only(left: 6, top: 1),
                      child: CircleAvatar(
                        radius: 9,
                        backgroundImage: NetworkImage(item.avatar!),
                      ),
                    ),
                  ItemMoveMenu(
                    board: board,
                    item: item,
                    columnColors: columnColors,
                    onMove: onMove,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RowMeta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _RowMeta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: cs.onSurfaceVariant),
          const SizedBox(width: 2),
          Text(
            text,
            style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ListEntry {
  final Option? option;
  final Item? item;
  final int count;

  const _ListEntry.header(this.option, this.count) : item = null;
  const _ListEntry.item(this.option, this.item) : count = 0;
}
