import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/links.dart';
import '../../github/client.dart';
import '../../github/models.dart';
import '../detail/detail_page.dart';
import 'common.dart';

Future<void> openItemDetail(
  BuildContext context,
  GitHub gh,
  Item item,
  ValueChanged<Item> onItemChanged,
) => showDetail(context, gh, item, onChanged: () => onItemChanged(item));

Future<void> showItemMenu(
  BuildContext context, {
  required TapDownDetails details,
  required Item item,
  required Board board,
  required Map<String, Color> columnColors,
  required void Function(Item, String) onMove,
  required Future<void> Function() onOpen,
}) async {
  final overlay = Overlay.of(context).context.findRenderObject();
  if (overlay is! RenderBox) return;

  const movePrefix = 'move:';
  final selected = await showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromPoints(details.globalPosition, details.globalPosition),
      Offset.zero & overlay.size,
    ),
    constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
    items: <PopupMenuEntry<String>>[
      _action('open', Icons.open_in_new, 'Abrir detalle'),
      if (item.url != null) ...[
        _action('browser', Icons.language, 'Abrir en GitHub'),
        _action('copy', Icons.copy, 'Copiar enlace'),
      ],
      if (board.options.isNotEmpty) ...[
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          enabled: false,
          height: 30,
          child: Text('Mover a…', style: TextStyle(fontSize: 11)),
        ),
        for (final option in board.options)
          PopupMenuItem<String>(
            value: '$movePrefix${option.id}',
            enabled: option.id != item.optionId,
            child: Row(
              children: [
                _dot(_colorFor(option, columnColors)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    option.name,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
      ],
    ],
  );
  if (!context.mounted || selected == null) return;

  switch (selected) {
    case 'open':
      await onOpen();
    case 'browser':
      await openGitHub(item.url);
    case 'copy':
      await Clipboard.setData(ClipboardData(text: item.url!));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Enlace copiado')));
    case final action when action.startsWith(movePrefix):
      onMove(item, action.substring(movePrefix.length));
  }
}

class ItemMoveMenu extends StatelessWidget {
  final Board board;
  final Item item;
  final Map<String, Color> columnColors;
  final void Function(Item, String) onMove;
  final double iconSize;

  const ItemMoveMenu({
    super.key,
    required this.board,
    required this.item,
    required this.columnColors,
    required this.onMove,
    this.iconSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Mover ${item.ref} a otra columna',
      button: true,
      child: PopupMenuButton<String>(
        tooltip: 'Mover a…',
        icon: Icon(Icons.more_horiz, size: iconSize),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        onSelected: (optionId) => onMove(item, optionId),
        itemBuilder: (_) => [
          for (final option in board.options)
            PopupMenuItem(
              value: option.id,
              enabled: option.id != item.optionId,
              child: Row(
                children: [
                  _dot(_colorFor(option, columnColors)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      option.name,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

Color _colorFor(Option option, Map<String, Color> colors) =>
    colors[option.id] ?? noStatusColor;

PopupMenuItem<String> _action(String value, IconData icon, String label) {
  return PopupMenuItem<String>(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: 9),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    ),
  );
}

Widget _dot(Color color) => Container(
  width: 8,
  height: 8,
  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
);
