import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/links.dart';
import '../../github/client.dart';
import '../../github/models.dart';
import '../board/common.dart' show LabelChip, checkIcon, itemIcon;
import '../board/item_edit.dart';

Future<void> showDetail(
  BuildContext context,
  GitHub gh,
  Item item, {
  VoidCallback? onChanged,
}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  builder: (_) => Align(
    alignment: Alignment.bottomCenter,
    child: _DetailSheet(gh: gh, item: item, onChanged: onChanged),
  ),
);

class _DetailSheet extends StatefulWidget {
  final GitHub gh;
  final Item item;
  final VoidCallback? onChanged;
  const _DetailSheet({required this.gh, required this.item, this.onChanged});
  @override
  State<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<_DetailSheet> {
  late Future<Map<String, dynamic>?> f;
  final _comment = TextEditingController();
  Map<String, dynamic>? _detail;
  GithubUser? _me;
  bool _busy = false;

  bool get _canAct =>
      widget.item.cid != null &&
      !widget.item.hidden &&
      (widget.item.kind == 'Issue' || widget.item.kind == 'PullRequest');

  bool get _canEdit => widget.item.cid != null && !widget.item.hidden;

  @override
  void initState() {
    super.initState();
    f = _fetch();
    _loadMe();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _fetch() async {
    final id = widget.item.cid;
    if (id == null || widget.item.hidden) return null;
    final detail = await widget.gh.detail(id);
    if (mounted) _detail = detail;
    return detail;
  }

  Future<void> _loadMe() async {
    try {
      final m = await widget.gh.me();
      if (mounted) setState(() => _me = m);
    } catch (_) {}
  }

  void _reload() {
    if (!_canAct) return;
    setState(() => f = _fetch());
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _run(Future<void> Function() action, String errorPrefix) async {
    setState(() => _busy = true);
    try {
      await action();
      _reload();
    } on AuthError {
      _snack('Tu sesión expiró. Vuelve a iniciar sesión.');
    } catch (e) {
      _snack('$errorPrefix: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _commentOn() async {
    final text = _comment.text.trim();
    if (text.isEmpty || widget.item.cid == null) return;
    await _run(() async {
      await widget.gh.addComment(widget.item.cid!, text);
      _comment.clear();
      _snack('Comentario publicado');
    }, 'No se pudo comentar');
  }

  Future<void> _toggleState(bool closed) async {
    if (widget.item.cid == null) return;
    await _run(() async {
      await widget.gh.setOpenState(widget.item.cid!, widget.item.kind, closed);
      widget.item.state = closed ? 'CLOSED' : 'OPEN';
      widget.onChanged?.call();
      _snack(closed ? 'Cerrado' : 'Reabierto');
    }, 'No se pudo cambiar el estado');
  }

  Future<void> _toggleAssign(bool assigned) async {
    if (widget.item.cid == null || _me == null) return;
    final login = _me!.login;
    await _run(() async {
      await widget.gh.setAssigned(widget.item.cid!, _me!.id, !assigned);
      final next = [...widget.item.assignees];
      if (assigned) {
        next.remove(login);
      } else if (!next.contains(login)) {
        next.add(login);
      }
      widget.item.assignees = next;
      widget.onChanged?.call();
      _snack(assigned ? 'Asignación quitada' : 'Asignado a ti');
    }, 'No se pudo asignar');
  }

  Future<void> _openEdit() async {
    final detail = _detail;
    final item = widget.item;
    if (detail == null || item.cid == null) return;
    final repo = detail['repository'] as Map<String, dynamic>?;
    final currentMilestone = detail['milestone'] as Map<String, dynamic>?;
    final repoLabels = [
      for (final l in (repo?['labels']?['nodes'] as List?) ?? [])
        Label(
          l['name'] as String? ?? '',
          l['color'] as String? ?? '8B949E',
          id: l['id'] as String?,
        ),
    ];
    final milestones = [
      for (final m in (repo?['milestones']?['nodes'] as List?) ?? [])
        Milestone(m['id'] as String, m['title'] as String? ?? ''),
    ];
    final currentMilestoneId = currentMilestone?['id'] as String?;
    if (currentMilestoneId != null &&
        !milestones.any((milestone) => milestone.id == currentMilestoneId)) {
      milestones.insert(
        0,
        Milestone(
          currentMilestoneId,
          currentMilestone?['title'] as String? ?? 'Milestone',
        ),
      );
    }
    final currentLabels = [
      for (final l in (detail['labels']?['nodes'] as List?) ?? [])
        Label(
          l['name'] as String? ?? '',
          l['color'] as String? ?? '8B949E',
          id: l['id'] as String?,
        ),
    ];
    final allowMilestone = item.kind != 'DraftIssue' && repo != null;
    final result = await showItemEditor(
      context,
      title: (detail['title'] as String?) ?? item.title,
      body: (detail['body'] as String?) ?? '',
      milestoneId: currentMilestoneId,
      currentLabels: currentLabels,
      repoLabels: repoLabels,
      milestones: milestones,
      allowMilestone: allowMilestone,
    );
    if (result == null || !mounted) return;
    await _run(() async {
      await widget.gh.updateContent(
        item.cid!,
        item.kind,
        title: result.title,
        body: result.body,
        milestoneId: allowMilestone ? result.milestoneId : null,
      );
      if (allowMilestone) {
        final currentIds = {
          for (final label in currentLabels)
            if (label.id != null) label.id!,
        };
        await widget.gh.setLabels(
          item.cid!,
          add: result.labelIds.difference(currentIds).toList(),
          remove: currentIds.difference(result.labelIds).toList(),
        );
        item.labels = [
          for (final label in repoLabels)
            if (result.labelIds.contains(label.id)) label,
        ];
      }
      item.title = result.title;
      widget.onChanged?.call();
      _snack('Tarjeta actualizada');
    }, 'No se pudo guardar');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final i = widget.item;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 720),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .85,
        minChildSize: .5,
        maxChildSize: .95,
        builder: (ctx, scroll) => FutureBuilder<Map<String, dynamic>?>(
          future: f,
          builder: (context, s) {
            final d = s.data;
            final labels = (d?['labels']?['nodes'] as List?) ?? [];
            final comments = (d?['comments']?['nodes'] as List?) ?? [];
            final assignees = (d?['assignees']?['nodes'] as List?) ?? [];
            final milestone = d?['milestone']?['title'] as String?;
            final review = d?['reviewDecision'] as String?;
            final checks =
                (d?['commits']?['nodes'] as List?)
                        ?.firstOrNull?['commit']?['statusCheckRollup']?['state']
                    as String?;
            final checksColor = checkIcon(checks).$2;
            final author =
                (d?['author']?['login'] ?? d?['creator']?['login']) as String?;
            final state =
                (d?['issueState'] ?? d?['prState'] ?? d?['state']) as String?;
            final isClosed = state == 'CLOSED' || state == 'MERGED';
            final isAssigned =
                _me != null && assignees.any((a) => a['login'] == _me!.login);
            final (icon, iconColor) = itemIcon(i);

            return ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 20, color: iconColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            i.title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                i.ref,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              if (state != null)
                                _Badge(text: state, color: _stateColor(state)),
                              if (author != null)
                                Text(
                                  'por $author',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              if (milestone != null)
                                _Badge(text: milestone, color: cs.secondary),
                              if (review != null)
                                _Badge(
                                  text: _reviewLabel(review),
                                  color: _reviewColor(review),
                                ),
                              if (checks != null)
                                _Badge(
                                  text: 'Checks: ${_checkLabel(checks)}',
                                  color: checksColor ?? cs.outline,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (labels.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final l in labels)
                        LabelChip(Label(l['name'], l['color'] ?? '8B949E')),
                    ],
                  ),
                ],
                if (assignees.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 15,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Asignado a ${assignees.map((a) => a['login']).join(', ')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    if (_canAct)
                      _Action(
                        icon: isClosed
                            ? Icons.undo
                            : Icons.check_circle_outline,
                        label: isClosed ? 'Reabrir' : 'Cerrar',
                        onPressed: _busy ? null : () => _toggleState(!isClosed),
                      ),
                    if (_canEdit)
                      _Action(
                        icon: Icons.edit_outlined,
                        label: 'Editar',
                        onPressed: _busy || _detail == null ? null : _openEdit,
                      ),
                    if (_canAct && _me != null)
                      _Action(
                        icon: isAssigned
                            ? Icons.person_remove_outlined
                            : Icons.person_add_alt,
                        label: isAssigned ? 'Quitarme' : 'Asignarme',
                        onPressed: _busy
                            ? null
                            : () => _toggleAssign(isAssigned),
                      ),
                    if (i.url != null)
                      _Action(
                        icon: Icons.open_in_new,
                        label: 'Abrir',
                        onPressed: () => openGitHub(i.url),
                      ),
                    if (i.url != null)
                      _Action(
                        icon: Icons.copy,
                        label: 'Copiar enlace',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: i.url!));
                          _snack('Enlace copiado');
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Divider(color: cs.outlineVariant),
                const SizedBox(height: 16),
                if (i.hidden)
                  _Message(
                    icon: Icons.lock_outline,
                    title: 'Sin acceso al contenido',
                    text: 'GitHub no entrega el contenido de este elemento. Cierra sesión y entra de nuevo para dar permiso de repositorios.',
                  )
                else if (s.connectionState != ConnectionState.done)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (s.hasError)
                  _Message(
                    icon: Icons.error_outline,
                    title: 'Error al cargar',
                    text: '${s.error}',
                  )
                else if (d == null)
                  const _Message(
                    icon: Icons.inbox_outlined,
                    title: 'Sin detalle',
                    text: 'No se pudo cargar el detalle de este elemento.',
                  )
                else ...[
                  Text(
                    'Descripción',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  (d['body'] as String?)?.trim().isNotEmpty == true
                      ? _Md(d['body'])
                      : Text(
                          'Sin descripción.',
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                  if (comments.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Comentarios (${d['comments']['totalCount']})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    for (final c in comments) ...[
                      const SizedBox(height: 10),
                      _Comment(
                        author: _authorOf(c),
                        date: _dateOf(c['createdAt']),
                        body: c['body'] ?? '',
                      ),
                    ],
                  ],
                  if (_canAct) ...[
                    const SizedBox(height: 24),
                    TextField(
                      controller: _comment,
                      minLines: 2,
                      maxLines: 6,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        hintText: 'Escribe un comentario…',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: _busy ? null : _commentOn,
                        child: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Comentar'),
                      ),
                    ),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  String _authorOf(Map<dynamic, dynamic> comment) {
    final author = comment['author']?['login'] as String?;
    return author == null || author.trim().isEmpty ? 'alguien' : author;
  }

  String _dateOf(Object? raw) {
    final date = raw?.toString() ?? '';
    return date.length >= 10 ? date.substring(0, 10) : date;
  }

  Color _stateColor(String state) => switch (state) {
    'MERGED' => const Color(0xFF8B5CF6),
    'CLOSED' => const Color(0xFFE5484D),
    _ => const Color(0xFF3FB950),
  };

  String _reviewLabel(String review) => switch (review) {
    'APPROVED' => 'Aprobado',
    'CHANGES_REQUESTED' => 'Cambios solicitados',
    'REVIEW_REQUIRED' => 'Revisión pendiente',
    _ => review,
  };

  Color _reviewColor(String review) => switch (review) {
    'APPROVED' => const Color(0xFF3FB950),
    'CHANGES_REQUESTED' => const Color(0xFFE5484D),
    _ => const Color(0xFFF59E0B),
  };

  String _checkLabel(String state) => switch (state) {
    'SUCCESS' => 'OK',
    'FAILURE' || 'ERROR' => 'falló',
    'PENDING' || 'EXPECTED' => 'pendiente',
    _ => state.toLowerCase(),
  };
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
    ),
  );
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  const _Action({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(
        foregroundColor: cs.onSurfaceVariant,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _Message({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, size: 28, color: cs.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Comment extends StatelessWidget {
  final String author;
  final String date;
  final String body;
  const _Comment({
    required this.author,
    required this.date,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: cs.primary.withValues(alpha: .12),
                child: Text(
                  author.trim().isEmpty
                      ? '?'
                      : author.characters.first.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$author · $date',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Md(body),
        ],
      ),
    );
  }
}

class _Md extends StatelessWidget {
  final String text;
  const _Md(this.text);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    final out = <Widget>[];
    final code = <String>[];
    var inCode = false;

    Widget block() => Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        code.join('\n'),
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12.5,
          height: 1.4,
        ),
      ),
    );

    final clean = text
        .replaceAll('\r', '')
        .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
    for (final raw in clean.split('\n')) {
      final l = raw.trimRight();
      if (l.trimLeft().startsWith('```')) {
        if (inCode) {
          out.add(block());
          code.clear();
        }
        inCode = !inCode;
        continue;
      }
      if (inCode) {
        code.add(raw);
        continue;
      }
      if (l.isEmpty) {
        out.add(const SizedBox(height: 6));
        continue;
      }
      final h = RegExp(r'^(#{1,6})\s+(.*)').firstMatch(l);
      final b = RegExp(r'^(\s*)[-*]\s+(\[( |x|X)\]\s+)?(.*)').firstMatch(l);
      if (h != null) {
        out.add(
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: SelectableText(
              h[2]!,
              style:
                  (h[1]!.length <= 2
                          ? t.textTheme.titleMedium
                          : t.textTheme.titleSmall)
                      ?.copyWith(fontWeight: FontWeight.w600, height: 1.3),
            ),
          ),
        );
      } else if (b != null) {
        out.add(
          Padding(
            padding: EdgeInsets.only(left: 4.0 + b[1]!.length * 6, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                b[2] == null
                    ? const Text('•  ')
                    : Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(
                          b[3] == ' '
                              ? Icons.check_box_outline_blank
                              : Icons.check_box,
                          size: 16,
                          color: cs.primary,
                        ),
                      ),
                Expanded(
                  child: SelectableText(b[4]!, style: t.textTheme.bodyMedium),
                ),
              ],
            ),
          ),
        );
      } else {
        out.add(
          SelectableText(
            l,
            style: t.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
        );
      }
    }
    if (code.isNotEmpty) out.add(block());
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: out);
  }
}
