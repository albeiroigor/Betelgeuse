import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'theme_notifier.dart';

Future<void> showThemePicker(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        const Align(alignment: Alignment.bottomCenter, child: _ThemePicker()),
  );
}

class _ThemePicker extends StatelessWidget {
  const _ThemePicker();

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<ThemeNotifier>();
    final cs = Theme.of(context).colorScheme;
    final themes = AppThemes.all;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 520),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Text(
                    'Apariencia',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final theme in themes)
                    _ThemeTile(
                      theme: theme,
                      selected: theme.id == notifier.current,
                      onTap: () async {
                        await notifier.setTheme(theme.id);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final AppTheme theme;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeTile({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final preview = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 32,
              decoration: BoxDecoration(
                color: preview.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: preview.outlineVariant),
              ),
              child: Row(
                children: [
                  Expanded(flex: 2, child: ColoredBox(color: preview.primary)),
                  Expanded(child: ColoredBox(color: preview.secondary)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    theme.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    theme.isDark ? 'Oscuro' : 'Claro',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check, size: 20, color: cs.primary)
            else
              const SizedBox(width: 20),
          ],
        ),
      ),
    );
  }
}
