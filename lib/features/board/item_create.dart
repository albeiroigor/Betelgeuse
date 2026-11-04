import 'package:flutter/material.dart';

enum _CreateMode { draft, existing }

class CreateItemRequest {
  final String? title;
  final String? body;
  final String? reference;

  const CreateItemRequest.draft(this.title, this.body) : reference = null;
  const CreateItemRequest.existing(this.reference) : title = null, body = null;

  bool get isExisting => reference != null;
}

Future<CreateItemRequest?> showCreateItem(
  BuildContext context, {
  required String columnName,
}) => showDialog<CreateItemRequest>(
  context: context,
  builder: (_) => _CreateItemDialog(columnName: columnName),
);

class _CreateItemDialog extends StatefulWidget {
  final String columnName;

  const _CreateItemDialog({required this.columnName});

  @override
  State<_CreateItemDialog> createState() => _CreateItemDialogState();
}

class _CreateItemDialogState extends State<_CreateItemDialog> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _reference = TextEditingController();
  var _mode = _CreateMode.draft;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _reference.dispose();
    super.dispose();
  }

  void _submit() {
    if (_mode == _CreateMode.draft) {
      final title = _title.text.trim();
      if (title.isEmpty) {
        setState(() => _error = 'Escribe un título.');
        return;
      }
      Navigator.of(context)
          .pop(CreateItemRequest.draft(title, _body.text.trim()));
      return;
    }
    final reference = _reference.text.trim();
    if (reference.isEmpty) {
      setState(() => _error = 'Escribe una URL o owner/repo#número.');
      return;
    }
    Navigator.of(context).pop(CreateItemRequest.existing(reference));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(
        'Añadir a ${widget.columnName}',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<_CreateMode>(
                segments: const [
                  ButtonSegment(
                    value: _CreateMode.draft,
                    icon: Icon(Icons.note_add_outlined, size: 16),
                    label: Text('Nueva'),
                  ),
                  ButtonSegment(
                    value: _CreateMode.existing,
                    icon: Icon(Icons.add_link, size: 16),
                    label: Text('Existente'),
                  ),
                ],
                selected: {_mode},
                showSelectedIcon: false,
                onSelectionChanged: (value) => setState(() {
                  _mode = value.first;
                  _error = null;
                }),
              ),
              const SizedBox(height: 16),
              if (_mode == _CreateMode.draft) ...[
                TextField(
                  controller: _title,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    hintText: '¿Qué hay que hacer?',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _body,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (opcional)',
                    alignLabelWithHint: true,
                  ),
                ),
              ] else
                TextField(
                  controller: _reference,
                  autofocus: true,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Issue o pull request',
                    hintText: 'https://github.com/owner/repo/issues/12',
                    helperText: 'También puedes usar owner/repo#12',
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: TextStyle(fontSize: 12, color: cs.error)),
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
        FilledButton(onPressed: _submit, child: const Text('Añadir')),
      ],
    );
  }
}
