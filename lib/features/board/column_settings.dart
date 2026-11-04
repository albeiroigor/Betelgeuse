import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class ColumnSettingsDialog extends StatefulWidget {
  final ColumnConfig config;
  final List<Color> palette;
  const ColumnSettingsDialog({
    super.key,
    required this.config,
    required this.palette,
  });

  @override
  State<ColumnSettingsDialog> createState() => _ColumnSettingsDialogState();
}

class _ColumnSettingsDialogState extends State<ColumnSettingsDialog> {
  late final TextEditingController _name;
  late Color _color;
  late String _displayName;

  @override
  void initState() {
    super.initState();
    _displayName = widget.config.displayName;
    _name = TextEditingController(text: _displayName);
    _color = widget.config.color;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text(
        'Personalizar columna',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nombre'),
              onChanged: (v) => setState(() => _displayName = v),
            ),
            const SizedBox(height: 16),
            Text(
              'Color',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in widget.palette)
                  InkWell(
                    onTap: () => setState(() => _color = c),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color == c ? cs.onSurface : cs.outlineVariant,
                          width: _color == c ? 2 : 1,
                        ),
                      ),
                      child: _color == c
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Solo se guarda en esta app; no cambia nada en GitHub.',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final name = _displayName.trim();
            Navigator.of(context).pop(
              ColumnConfig(
                optionId: widget.config.optionId,
                displayName: name.isEmpty ? widget.config.displayName : name,
                color: _color,
              ),
            );
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
