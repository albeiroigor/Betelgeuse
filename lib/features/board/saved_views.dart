import 'package:flutter/material.dart';

import 'board_layout.dart';
import 'common.dart';

class SavedViewAction {
  final SavedView? apply;
  final String? saveName;
  final String? deleteName;

  const SavedViewAction.apply(SavedView view)
    : apply = view,
      saveName = null,
      deleteName = null;

  const SavedViewAction.save(this.saveName) : apply = null, deleteName = null;

  const SavedViewAction.delete(this.deleteName) : apply = null, saveName = null;
}

Future<SavedViewAction?> showSavedViews(
  BuildContext context, {
  required String boardName,
  required List<SavedView> views,
}) => showDialog<SavedViewAction>(
  context: context,
  builder: (_) => _SavedViewsDialog(boardName: boardName, views: views),
);

class _SavedViewsDialog extends StatefulWidget {
  final String boardName;
  final List<SavedView> views;

  const _SavedViewsDialog({required this.boardName, required this.views});

  @override
  State<_SavedViewsDialog> createState() => _SavedViewsDialogState();
}

class _SavedViewsDialogState extends State<_SavedViewsDialog> {
  final _name = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Ponle un nombre a la vista.');
      return;
    }
    Navigator.of(context).pop(SavedViewAction.save(name));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(
        'Vistas de ${widget.boardName}',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Guarda la búsqueda, los filtros y el orden actuales.',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _name,
                      onSubmitted: (_) => _save(),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Nombre de la vista',
                        errorText: _error,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: FilledButton(
                      onPressed: _save,
                      child: const Text('Guardar'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (widget.views.isEmpty)
                Text(
                  'Aún no hay vistas guardadas.',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                )
              else
                for (final view in widget.views)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      view.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      [
                        _viewLabel(view.prefs.view),
                        if (view.query.isNotEmpty) '"${view.query}"',
                        _filterLabel(view.filter),
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    onTap: () =>
                        Navigator.of(context).pop(SavedViewAction.apply(view)),
                    trailing: IconButton(
                      tooltip: 'Eliminar ${view.name}',
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () =>
                          Navigator.of(context)
                              .pop(SavedViewAction.delete(view.name)),
                    ),
                  ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

String _viewLabel(BoardViewMode mode) => switch (mode) {
  BoardViewMode.kanban => 'Tablero',
  BoardViewMode.list => 'Lista',
  BoardViewMode.compact => 'Compacta',
  BoardViewMode.table => 'Tabla',
};

String _filterLabel(String name) {
  final filter = BoardFilter.values.asNameMap()[name] ?? BoardFilter.all;
  return switch (filter) {
    BoardFilter.all => 'Todo',
    BoardFilter.open => 'Abiertos',
    BoardFilter.closed => 'Cerrados',
    BoardFilter.mine => 'Mías',
    BoardFilter.currentIteration => 'Iteración actual',
  };
}
