import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../github/client.dart';
import '../../github/models.dart';
import 'card_view.dart';
import 'common.dart';

class ColumnView extends StatelessWidget {
  final GitHub gh;
  final Board board;
  final Option? option;
  final Color accent;
  final List<Item> items;
  final ColumnConfig? config;
  final int itemsCount;
  final VoidCallback? onEditColumn;
  final Map<String, Color> columnColors;
  final void Function(Item, String) onMove;
  final ValueChanged<Item> onItemChanged;
  final double? estimateSum;
  final VoidCallback? onCreate;
  final bool selecting;
  final Set<String> selected;
  final ValueChanged<Item>? onToggleSelect;

  const ColumnView({
    super.key,
    required this.gh,
    required this.board,
    required this.option,
    required this.accent,
    required this.items,
    this.config,
    required this.itemsCount,
    this.onEditColumn,
    this.columnColors = const {},
    required this.onMove,
    required this.onItemChanged,
    this.estimateSum,
    this.onCreate,
    this.selecting = false,
    this.selected = const {},
    this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final displayName = config?.displayName ?? option?.name ?? 'Sin estado';
    final summary = [
      '$itemsCount tarjetas',
      if (estimateSum != null) '${formatPoints(estimateSum!)} puntos',
    ].join(', ');

    return Semantics(
      container: true,
      label: 'Columna $displayName, $summary',
      child: DragTarget<Item>(
        onWillAcceptWithDetails: (_) => option != null,
        onAcceptWithDetails: (d) => onMove(d.data, option!.id),
        builder: (_, hover, _) => Container(
          decoration: BoxDecoration(
            color: hover.isNotEmpty
                ? cs.primary.withValues(alpha: .06)
                : cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hover.isNotEmpty ? cs.primary : cs.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ColumnHeader(
                accent: accent,
                displayName: displayName,
                itemCount: itemsCount,
                estimateSum: estimateSum,
                onAdd: onCreate,
                onEdit: onEditColumn,
              ),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: onCreate == null
                              ? Text(
                                  'Sin tarjetas',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant,
                                  ),
                                )
                              : TextButton.icon(
                                  onPressed: onCreate,
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Añadir tarjeta'),
                                ),
                        ),
                      )
                    : ListView.builder(
                        key: PageStorageKey('column-${board.id}-${option?.id}'),
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        itemCount: items.length,
                        itemBuilder: (_, k) {
                          final item = items[k];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ItemCardView(
                              gh: gh,
                              board: board,
                              item: item,
                              accent: accent,
                              columnColors: columnColors,
                              onMove: onMove,
                              onItemChanged: onItemChanged,
                              selecting: selecting,
                              selected: selected.contains(item.id),
                              onToggleSelect: onToggleSelect == null
                                  ? null
                                  : () => onToggleSelect!(item),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  final Color accent;
  final String displayName;
  final int itemCount;
  final double? estimateSum;
  final VoidCallback? onAdd;
  final VoidCallback? onEdit;

  const _ColumnHeader({
    required this.accent,
    required this.displayName,
    required this.itemCount,
    required this.estimateSum,
    required this.onAdd,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              displayName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ),
          Text(
            '$itemCount',
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
          if (onAdd != null)
            IconButton(
              tooltip: 'Añadir tarjeta a $displayName',
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
