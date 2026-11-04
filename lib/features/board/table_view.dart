import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../github/client.dart';
import '../../github/models.dart';
import 'board_layout.dart';
import 'card_actions.dart';
import 'common.dart';

const _tableWidth = 1120.0;
const _statusWidth = 150.0;
const _titleWidth = 330.0;
const _peopleWidth = 150.0;
const _labelsWidth = 210.0;
const _pointsWidth = 60.0;
const _dateWidth = 90.0;

class BoardTableView extends StatelessWidget {
  final GitHub gh;
  final Board board;
  final List<Option> options;
  final Map<String?, List<Item>> itemsByOption;
  final Map<String, ColumnConfig> columnConfigs;
  final Map<String, Color> colors;
  final void Function(Item, String) onMove;
  final ValueChanged<Item> onItemChanged;
  final double? Function(Option?) estimateSum;
  final void Function(Option?) onCreate;
  final bool selecting;
  final Set<String> selected;
  final ValueChanged<Item>? onToggleSelect;

  const BoardTableView({
    super.key,
    required this.gh,
    required this.board,
    required this.options,
    required this.itemsByOption,
    required this.columnConfigs,
    required this.colors,
    required this.onMove,
    required this.onItemChanged,
    required this.estimateSum,
    required this.onCreate,
    this.selecting = false,
    this.selected = const {},
    this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    final entries = <_TableEntry>[];

    void addSection(Option? option, List<Item> items, {bool always = false}) {
      if (items.isEmpty && !always) return;
      entries.add(_TableEntry.header(option, items.length));
      for (final item in items) {
        entries.add(_TableEntry.item(option, item));
      }
    }

    for (final option in options) {
      addSection(option, itemsByOption[option.id] ?? const [], always: true);
    }
    addSection(null, itemsByOption[null] ?? const []);

    return Scrollbar(
      thumbVisibility: false,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _tableWidth,
          child: Column(
            children: [
              _Header(selecting: selecting),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    if (entry.item == null) {
                      return _GroupRow(
                        option: entry.option,
                        count: entry.count,
                        estimateSum: estimateSum(entry.option),
                        color: _accent(entry.option),
                        title: entry.option == null
                            ? 'Sin estado'
                            : columnDisplayName(entry.option!, columnConfigs),
                        onAdd: () => onCreate(entry.option),
                      );
                    }
                    return _ItemRow(
                      gh: gh,
                      board: board,
                      entry: entry,
                      option: entry.option,
                      accent: _accent(entry.option),
                      status: entry.option == null
                          ? 'Sin estado'
                          : columnDisplayName(entry.option!, columnConfigs),
                      columnColors: colors,
                      onMove: onMove,
                      onItemChanged: onItemChanged,
                      selecting: selecting,
                      selected: selected.contains(entry.item!.id),
                      onToggleSelect: onToggleSelect == null
                          ? null
                          : () => onToggleSelect!(entry.item!),
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

  Color _accent(Option? option) =>
      option == null ? noStatusColor : colors[option.id] ?? noStatusColor;
}

class _Header extends StatelessWidget {
  final bool selecting;

  const _Header({required this.selecting});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: cs.onSurfaceVariant,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          if (selecting) const SizedBox(width: 44),
          _Cell(
            width: _statusWidth,
            child: Text('Estado', style: style),
          ),
          _Cell(
            width: _titleWidth,
            child: Text('Título', style: style),
          ),
          _Cell(
            width: _peopleWidth,
            child: Text('Asignados', style: style),
          ),
          _Cell(
            width: _labelsWidth,
            child: Text('Etiquetas', style: style),
          ),
          _Cell(
            width: _pointsWidth,
            child: Text('Pts', style: style),
          ),
          _Cell(
            width: _dateWidth,
            child: Text('Actualizado', style: style),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  final Option? option;
  final int count;
  final double? estimateSum;
  final Color color;
  final String title;
  final VoidCallback onAdd;

  const _GroupRow({
    required this.option,
    required this.count,
    required this.estimateSum,
    required this.color,
    required this.title,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
          ),
          if (estimateSum != null)
            Text(
              ' · ${formatPoints(estimateSum!)} pts',
              style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
            ),
          const Spacer(),
          IconButton(
            tooltip: 'Añadir tarjeta a $title',
            icon: const Icon(Icons.add, size: 20),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final GitHub gh;
  final Board board;
  final _TableEntry entry;
  final Option? option;
  final Color accent;
  final String status;
  final Map<String, Color> columnColors;
  final void Function(Item, String) onMove;
  final ValueChanged<Item> onItemChanged;
  final bool selecting;
  final bool selected;
  final VoidCallback? onToggleSelect;

  const _ItemRow({
    required this.gh,
    required this.board,
    required this.entry,
    required this.option,
    required this.accent,
    required this.status,
    required this.columnColors,
    required this.onMove,
    required this.onItemChanged,
    required this.selecting,
    required this.selected,
    required this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    final item = entry.item!;
    final cs = Theme.of(context).colorScheme;
    final (icon, iconColor) = itemIcon(item);

    return Semantics(
      container: true,
      button: true,
      label: '${item.title}. ${item.ref}. $status',
      child: Material(
        color: selected
            ? cs.primary.withValues(alpha: .08)
            : Colors.transparent,
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
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: cs.outlineVariant, width: .5),
              ),
            ),
            child: Row(
              children: [
                if (selecting)
                  SizedBox(
                    width: 44,
                    child: Checkbox(
                      value: selected,
                      onChanged: (_) => onToggleSelect?.call(),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                    ),
                  ),
                _Cell(
                  width: _statusWidth,
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: accent),
                        ),
                      ),
                    ],
                  ),
                ),
                _Cell(
                  width: _titleWidth,
                  child: Row(
                    children: [
                      Icon(icon, size: 13, color: iconColor),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: item.hidden
                                ? cs.onSurfaceVariant
                                : cs.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.ref,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _Cell(
                  width: _peopleWidth,
                  child: Text(
                    item.assignees.join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                _Cell(
                  width: _labelsWidth,
                  child: Text(
                    item.labels.map((label) => label.name).join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                _Cell(
                  width: _pointsWidth,
                  child: Text(
                    item.estimate == null ? '' : formatPoints(item.estimate!),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                _Cell(
                  width: _dateWidth,
                  child: Text(
                    _shortDate(item.updatedAt),
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
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
    );
  }
}

class _Cell extends StatelessWidget {
  final double width;
  final Widget child;

  const _Cell({required this.width, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(padding: const EdgeInsets.only(right: 10), child: child),
    );
  }
}

String _shortDate(String? iso) {
  final date = DateTime.tryParse(iso ?? '');
  if (date == null) return '';
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year % 100}';
}

class _TableEntry {
  final Option? option;
  final Item? item;
  final int count;

  const _TableEntry.header(this.option, this.count) : item = null;
  const _TableEntry.item(this.option, this.item) : count = 0;
}
