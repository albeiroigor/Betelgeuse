import 'package:flutter/material.dart';

import '../../github/models.dart';

class ItemEditResult {
  final String title;
  final String body;
  final String? milestoneId;
  final Set<String> labelIds;

  const ItemEditResult({
    required this.title,
    required this.body,
    this.milestoneId,
    required this.labelIds,
  });
}

Future<ItemEditResult?> showItemEditor(
  BuildContext context, {
  required String title,
  required String body,
  required String? milestoneId,
  required List<Label> currentLabels,
  required List<Label> repoLabels,
  required List<Milestone> milestones,
  required bool allowMilestone,
}) => showDialog<ItemEditResult>(
  context: context,
  builder: (_) => _ItemEditor(
    title: title,
    body: body,
    milestoneId: milestoneId,
    currentLabels: currentLabels,
    repoLabels: repoLabels,
    milestones: milestones,
    allowMilestone: allowMilestone,
  ),
);

class _ItemEditor extends StatefulWidget {
  final String title;
  final String body;
  final String? milestoneId;
  final List<Label> currentLabels;
  final List<Label> repoLabels;
  final List<Milestone> milestones;
  final bool allowMilestone;

  const _ItemEditor({
    required this.title,
    required this.body,
    required this.milestoneId,
    required this.currentLabels,
    required this.repoLabels,
    required this.milestones,
    required this.allowMilestone,
  });

  @override
  State<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<_ItemEditor> {
  late final _title = TextEditingController(text: widget.title);
  late final _body = TextEditingController(text: widget.body);
  late final Set<String> _labels = {
    for (final label in widget.currentLabels)
      if (label.id != null) label.id!,
  };
  late String _milestone =
      widget.milestones.any((milestone) => milestone.id == widget.milestoneId)
      ? widget.milestoneId!
      : '';
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'El título no puede quedar vacío.');
      return;
    }
    Navigator.of(context).pop(
      ItemEditResult(
        title: title,
        body: _body.text,
        milestoneId: widget.allowMilestone && _milestone.isNotEmpty
            ? _milestone
            : null,
        labelIds: _labels,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text(
        'Editar tarjeta',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _title,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Título',
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _body,
                minLines: 5,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  alignLabelWithHint: true,
                ),
              ),
              if (widget.repoLabels.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Etiquetas',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final label in widget.repoLabels)
                      FilterChip(
                        label: Text(label.name),
                        selected: _labels.contains(label.id),
                        onSelected: (selected) => setState(() {
                          if (label.id == null) return;
                          if (selected) {
                            _labels.add(label.id!);
                          } else {
                            _labels.remove(label.id);
                          }
                        }),
                        avatar: CircleAvatar(
                          radius: 5,
                          backgroundColor: label.swatch,
                        ),
                      ),
                  ],
                ),
              ],
              if (widget.allowMilestone) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _milestone,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Milestone',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Sin milestone'),
                    ),
                    for (final milestone in widget.milestones)
                      DropdownMenuItem(
                        value: milestone.id,
                        child: Text(milestone.title),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _milestone = value ?? ''),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}
