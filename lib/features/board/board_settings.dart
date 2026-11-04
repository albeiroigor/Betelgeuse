import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../github/models.dart';
import 'board_layout.dart';
import 'common.dart';

Future<BoardPreferences?> showBoardSettings(
  BuildContext context, {
  required BoardPreferences prefs,
  required String boardId,
  required List<Option> columns,
  required List<ProjectField> fields,
  required String? groupFieldId,
  required String? estimateFieldId,
  required Map<String, ColumnConfig> columnConfigs,
  required Map<String, Color> columnColors,
  required Map<String, int> counts,
}) {
  return showDialog<BoardPreferences>(
    context: context,
    builder: (_) => _BoardSettingsDialog(
      prefs: prefs,
      boardId: boardId,
      columns: columns,
      fields: fields,
      groupFieldId: groupFieldId,
      estimateFieldId: estimateFieldId,
      columnConfigs: columnConfigs,
      columnColors: columnColors,
      counts: counts,
    ),
  );
}

class _BoardSettingsDialog extends StatefulWidget {
  final BoardPreferences prefs;
  final String boardId;
  final List<Option> columns;
  final List<ProjectField> fields;
  final String? groupFieldId;
  final String? estimateFieldId;
  final Map<String, ColumnConfig> columnConfigs;
  final Map<String, Color> columnColors;
  final Map<String, int> counts;

  const _BoardSettingsDialog({
    required this.prefs,
    required this.boardId,
    required this.columns,
    required this.fields,
    required this.groupFieldId,
    required this.estimateFieldId,
    required this.columnConfigs,
    required this.columnColors,
    required this.counts,
  });

  @override
  State<_BoardSettingsDialog> createState() => _BoardSettingsDialogState();
}

class _BoardSettingsDialogState extends State<_BoardSettingsDialog> {
  late ColumnOrder _columnOrder;
  late CardSort _cardSort;
  late bool _cardSortInverted;
  late BoardViewMode _view;
  late List<String> _manual;
  late String _groupFieldId;
  late String _estimateFieldId;
  var _epoch = 0;

  @override
  void initState() {
    super.initState();
    _columnOrder = widget.prefs.columnOrder;
    _cardSort = widget.prefs.cardSort;
    _cardSortInverted = widget.prefs.cardSortInverted;
    _view = widget.prefs.view;
    _manual = resolvedManualOrder(
      widget.columns,
      widget.prefs.manualOrderFor(widget.boardId),
    );
    final groupable = {
      for (final field in widget.fields)
        if (field.groupable) field.id,
    };
    final numeric = {
      for (final field in widget.fields)
        if (field.kind == FieldKind.number) field.id,
    };
    _groupFieldId = groupable.contains(widget.groupFieldId)
        ? widget.groupFieldId!
        : '';
    _estimateFieldId = numeric.contains(widget.estimateFieldId)
        ? widget.estimateFieldId!
        : '';
  }

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _manual.length) return;
    setState(() {
      final id = _manual.removeAt(index);
      _manual.insert(target, id);
    });
  }

  void _reset() {
    setState(() {
      _columnOrder = ColumnOrder.github;
      _cardSort = CardSort.manual;
      _cardSortInverted = false;
      _view = BoardViewMode.kanban;
      _groupFieldId = '';
      _estimateFieldId = '';
      _epoch++;
      _manual = resolvedManualOrder(widget.columns, const []);
    });
  }

  Map<String, String> _fieldMap(Map<String, String> current, String id) {
    final next = {...current};
    if (id.isEmpty) {
      next.remove(widget.boardId);
    } else {
      next[widget.boardId] = id;
    }
    return next;
  }

  void _save() {
    Navigator.of(context).pop(
      widget.prefs.copyWith(
        columnOrder: _columnOrder,
        cardSort: _cardSort,
        cardSortInverted: _cardSortInverted,
        view: _view,
        manualOrders: {...widget.prefs.manualOrders, widget.boardId: _manual},
        groupFields: _fieldMap(widget.prefs.groupFields, _groupFieldId),
        estimateFields: _fieldMap(
          widget.prefs.estimateFields,
          _estimateFieldId,
        ),
      ),
    );
  }

  Widget _chips<T>({
    required List<(String, T)> options,
    required T group,
    required ValueChanged<T> onSelected,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (label, value) in options)
          _ChoiceChip(
            label: label,
            value: value,
            group: group,
            onSelected: onSelected,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final byId = {for (final option in widget.columns) option.id: option};

    return AlertDialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text(
        'Organizar tablero',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Label('Visualización'),
              const SizedBox(height: 8),
              _chips(
                options: const [
                  ('Tablero', BoardViewMode.kanban),
                  ('Lista', BoardViewMode.list),
                  ('Compacta', BoardViewMode.compact),
                  ('Tabla', BoardViewMode.table),
                ],
                group: _view,
                onSelected: (value) => setState(() => _view = value),
              ),
              const SizedBox(height: 18),
              _Label('Agrupar por'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey('group-$_epoch'),
                initialValue: _groupFieldId,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Status (automático)'),
                  ),
                  for (final field in widget.fields)
                    if (field.groupable)
                      DropdownMenuItem(
                        value: field.id,
                        child: Text(field.name),
                      ),
                ],
                onChanged: (value) =>
                    setState(() => _groupFieldId = value ?? ''),
              ),
              const SizedBox(height: 18),
              _Label('Estimar con'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey('estimate-$_epoch'),
                initialValue: _estimateFieldId,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Sin estimación'),
                  ),
                  for (final field in widget.fields)
                    if (field.kind == FieldKind.number)
                      DropdownMenuItem(
                        value: field.id,
                        child: Text(field.name),
                      ),
                ],
                onChanged: (value) =>
                    setState(() => _estimateFieldId = value ?? ''),
              ),
              const SizedBox(height: 18),
              _Label('Orden de columnas'),
              const SizedBox(height: 8),
              _chips(
                options: const [
                  ('Original', ColumnOrder.github),
                  ('Alfabético', ColumnOrder.alphabetical),
                  ('Más tarjetas', ColumnOrder.cards),
                  ('Manual', ColumnOrder.manual),
                ],
                group: _columnOrder,
                onSelected: (value) => setState(() => _columnOrder = value),
              ),
              if (_columnOrder == ColumnOrder.manual) ...[
                const SizedBox(height: 10),
                Container(
                  constraints: const BoxConstraints(maxHeight: 216),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _manual.length,
                    itemBuilder: (_, index) {
                      final option = byId[_manual[index]];
                      if (option == null) return const SizedBox.shrink();
                      final name = columnDisplayName(
                        option,
                        widget.columnConfigs,
                      );
                      final color =
                          widget.columnColors[option.id] ?? noStatusColor;
                      final count = widget.counts[option.id] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12.5),
                              ),
                            ),
                            Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Subir',
                              icon: const Icon(
                                Icons.keyboard_arrow_up,
                                size: 18,
                              ),
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(
                                minWidth: 26,
                                minHeight: 26,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: index == 0
                                  ? null
                                  : () => _move(index, -1),
                            ),
                            IconButton(
                              tooltip: 'Bajar',
                              icon: const Icon(
                                Icons.keyboard_arrow_down,
                                size: 18,
                              ),
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(
                                minWidth: 26,
                                minHeight: 26,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: index == _manual.length - 1
                                  ? null
                                  : () => _move(index, 1),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 18),
              _Label('Orden de tarjetas'),
              const SizedBox(height: 8),
              _chips(
                options: const [
                  ('Original', CardSort.manual),
                  ('Alfabético', CardSort.alphabetical),
                  ('Número', CardSort.issueNumber),
                  ('Creación', CardSort.creation),
                  ('Recientes', CardSort.recent),
                ],
                group: _cardSort,
                onSelected: (value) => setState(() => _cardSort = value),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                value: _cardSortInverted,
                onChanged: (value) => setState(() => _cardSortInverted = value),
                title: const Text(
                  'Invertido',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  'Invierte el orden de las tarjetas',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
                dense: true,
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              Text(
                'Solo se guarda en esta app; no cambia nada en GitHub.',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _reset, child: const Text('Restablecer')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _ChoiceChip<T> extends StatelessWidget {
  final String label;
  final T value;
  final T group;
  final ValueChanged<T> onSelected;

  const _ChoiceChip({
    required this.label,
    required this.value,
    required this.group,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selected = value == group;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(value),
      showCheckmark: false,
      selectedColor: cs.primary,
      backgroundColor: cs.surface,
      labelStyle: TextStyle(
        color: selected ? cs.onPrimary : cs.onSurfaceVariant,
        fontWeight: FontWeight.w500,
        fontSize: 12,
      ),
      side: BorderSide(color: cs.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
