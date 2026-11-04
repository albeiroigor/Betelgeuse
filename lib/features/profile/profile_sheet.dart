import 'package:flutter/material.dart';

import '../../core/app_info.dart';
import '../../core/links.dart';
import '../../core/profiles.dart';

class ProfileAvatar extends StatelessWidget {
  final Profile profile;
  final double radius;

  const ProfileAvatar({super.key, required this.profile, this.radius = 16});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: cs.primary.withValues(alpha: .15),
      foregroundImage: profile.avatarUrl == null
          ? null
          : NetworkImage(profile.avatarUrl!),
      child: Text(
        profile.login.isEmpty
            ? '?'
            : profile.login.characters.first.toUpperCase(),
        style: TextStyle(
          fontSize: radius * .8,
          fontWeight: FontWeight.w700,
          color: cs.primary,
        ),
      ),
    );
  }
}

Future<void> showProfileSheet(BuildContext context, Profile profile) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProfileSheet(profile: profile),
  );
}

class _ProfileSheet extends StatefulWidget {
  final Profile profile;
  const _ProfileSheet({required this.profile});

  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  late final Future<AppVersion> _version = AppInfo.version();
  bool _checking = false;

  Future<void> _checkUpdates() async {
    setState(() => _checking = true);
    try {
      final version = await _version;
      final release = await AppInfo.latestRelease();
      if (!mounted) return;
      if (release == null) {
        _snack(
          AppInfo.hasRepository
              ? 'No se pudo consultar la última release.'
              : 'Este build no tiene configurado APP_REPOSITORY.',
        );
        return;
      }
      if (!release.isNewerThan(version.version)) {
        _snack('Ya tienes la última versión (${version.label}).');
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Nueva versión ${release.tag}'),
          content: SingleChildScrollView(
            child: Text(
              release.notes.trim().isEmpty
                  ? 'Hay una versión más reciente disponible.'
                  : release.notes,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                openUrl(release.url);
              },
              child: const Text('Ver release'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = widget.profile;
    final releasesUri = AppInfo.releasesUri;

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                ProfileAvatar(profile: p, radius: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.displayName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${p.login}',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (p.bio?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text(
                p.bio!,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => openGitHub(p.githubUrl),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Ver perfil en GitHub'),
            ),
            const SizedBox(height: 16),
            Divider(color: cs.outlineVariant),
            const SizedBox(height: 12),
            FutureBuilder<AppVersion>(
              future: _version,
              builder: (context, snapshot) {
                final version = snapshot.data;
                return Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        snapshot.hasError
                            ? 'No se pudo leer la versión.'
                            : version == null
                            ? 'Cargando versión…'
                            : 'Betelgeuse ${version.label}',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _checking ? null : _checkUpdates,
                      child: _checking
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Buscar actualizaciones'),
                    ),
                  ],
                );
              },
            ),
            if (releasesUri != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => openUrl(releasesUri.toString()),
                  icon: const Icon(Icons.history, size: 16),
                  label: const Text('Ver todas las releases'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
