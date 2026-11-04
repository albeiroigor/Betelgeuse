import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../github/client.dart';
import '../../github/models.dart';
import 'card_actions.dart';
import 'common.dart';

bool get _immediateDrag {
  if (kIsWeb) return false;
  return switch (defaultTargetPlatform) {
    TargetPlatform.linux ||
    TargetPlatform.macOS ||
    TargetPlatform.windows => true,
    _ => false,
  };
}

class ItemCardView extends StatelessWidget {
  final GitHub gh;
  final Board board;
  final Item item;
  final Color accent;
  final Map<String, Color> columnColors;
  final void Function(Item, String) onMove;
  final ValueChanged<Item> onItemChanged;
  final bool selecting;
  final bool selected;
  final VoidCallback? onToggleSelect;

  const ItemCardView({
    super.key,
    required this.gh,
    required this.board,
    required this.item,
    required this.accent,
    required this.columnColors,
    required this.onMove,
    required this.onItemChanged,
    this.selecting = false,
    this.selected = false,
    this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (icon, iconColor) = itemIcon(item);
    final (checkI, checkC) = checkIcon(item.checksState);
    final option = board.options
        .where((option) => option.id == item.optionId)
        .firstOrNull;

    final card = Card(
      child: InkWell(
        onTap: selecting
            ? onToggleSelect
            : () => openItemDetail(context, gh, item, onItemChanged),
        child: Container(
          decoration: BoxDecoration(
            color: selected ? cs.primary.withValues(alpha: .08) : null,
            border: Border(
              left: BorderSide(
                color: selected ? cs.primary : accent,
                width: selected ? 4 : 3,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                  Icon(icon, size: 14, color: iconColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.ref,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (item.commentCount != null && item.commentCount! > 0)
                    _Meta(
                      icon: Icons.mode_comment_outlined,
                      text: '${item.commentCount}',
                    ),
                  if (item.estimate != null)
                    _Meta(
                      icon: Icons.speed,
                      text: formatPoints(item.estimate!),
                    ),
                  if (checkI != null)
                    Tooltip(
                      message: 'Checks: ${item.checksState}',
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(checkI, size: 14, color: checkC),
                      ),
                    ),
                  if (item.avatar != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
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
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  item.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                    color: item.hidden ? cs.onSurfaceVariant : cs.onSurface,
                  ),
                ),
              ),
              if (item.labels.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      for (final label in item.labels) LabelChip(label),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    final feedback = Material(
      color: Colors.transparent,
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(width: 260, child: card),
    );
    final ghost = Opacity(opacity: .4, child: card);

    final draggable = selecting
        ? card
        : _immediateDrag
        ? Draggable<Item>(
            data: item,
            feedback: feedback,
            childWhenDragging: ghost,
            child: card,
          )
        : LongPressDraggable<Item>(
            data: item,
            feedback: feedback,
            childWhenDragging: ghost,
            child: card,
          );

    return Semantics(
      container: true,
      button: true,
      label: _semantics(option?.name),
      child: GestureDetector(
        onSecondaryTapDown: (details) => showItemMenu(
          context,
          details: details,
          item: item,
          board: board,
          columnColors: columnColors,
          onMove: onMove,
          onOpen: () => openItemDetail(context, gh, item, onItemChanged),
        ),
        child: draggable,
      ),
    );
  }

  String _semantics(String? status) {
    final kind = switch (item.kind) {
      'PullRequest' => 'Pull request',
      'Issue' => 'Issue',
      _ => 'Borrador',
    };
    return [
      kind,
      item.title,
      item.ref,
      status ?? 'Sin estado',
      if (item.assignees.isNotEmpty) 'asignado a ${item.assignees.join(', ')}',
    ].join('. ');
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
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
