import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/links.dart';
import '../../core/profiles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_picker.dart';
import '../../github/client.dart';
import '../../github/models.dart';
import '../profile/profile_sheet.dart';
import 'board_layout.dart';
import 'board_settings.dart';
import 'column_settings.dart';
import 'column_view.dart';
import 'common.dart';
import 'item_create.dart';
import 'list_view.dart';
import 'saved_views.dart';
import 'table_view.dart';

class BoardPage extends StatefulWidget {
  final GitHub gh;
  final Profile profile;
  final List<Profile> profiles;
  final ValueChanged<String> onSwitchProfile;
  final VoidCallback onAddProfile;
  final VoidCallback onLogout;

  const BoardPage({
    super.key,
    required this.gh,
    required this.profile,
    required this.profiles,
    required this.onSwitchProfile,
    required this.onAddProfile,
    required this.onLogout,
  });
  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  static const _cacheTtl = Duration(minutes: 3);
  static const _searchDelay = Duration(milliseconds: 180);

  List<Proj> projects = [];
  Proj? current;
  Board? board;
  bool loading = true;
  String? error;
  String q = '';
  BoardFilter filter = BoardFilter.all;
  Map<String, ColumnConfig> columnConfigs = {};
  BoardPreferences prefs = const BoardPreferences();
  GithubUser? viewer;
  bool scanning = false;
  bool selecting = false;
  final Set<String> selected = {};
  final Map<String, _CachedBoard> _cache = {};
  final _searchFocus = FocusNode();
  final _search = TextEditingController();
  Timer? _searchTimer;

  int _loadSeq = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchFocus.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final seq = ++_loadSeq;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final user = await widget.gh.me();
      final projectList = await widget.gh.projects();
      final columnConfigsResult = await ThemeStore().loadColumnConfigs();
      final prefsResult = await BoardPreferencesStore().load();
      if (!mounted || seq != _loadSeq) return;
      viewer = user;
      projects = projectList;
      columnConfigs = columnConfigsResult;
      prefs = prefsResult;
      if (projects.isEmpty) {
        setState(() {
          loading = false;
          current = null;
          board = null;
          error = 'No encontré proyectos. Crea uno en GitHub o revisa los permisos que autorizaste.';
        });
        return;
      }
      await _open(projects.first);
    } on AuthError {
      if (mounted) widget.onLogout();
    } catch (e) {
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        loading = false;
        error = '$e';
      });
    }
  }

  String _cacheKey(String projectId) =>
      '$projectId|${prefs.groupFieldFor(projectId) ?? ''}|'
      '${prefs.estimateFieldFor(projectId) ?? ''}';

  void _clearSelection() {
    selecting = false;
    selected.clear();
  }

  Future<void> _open(Proj p, {bool refresh = false}) async {
    final seq = ++_loadSeq;
    final key = _cacheKey(p.id);
    final cached = refresh ? null : _cache[key];
    final keepCurrent = board != null && board!.id == p.id;
    setState(() {
      current = p;
      error = null;
      _clearSelection();
      if (cached != null) {
        board = cached.board;
        loading = false;
      } else {
        loading = !keepCurrent;
        if (!keepCurrent) board = null;
      }
    });
    if (cached != null && DateTime.now().difference(cached.at) < _cacheTtl) {
      return;
    }
    try {
      final b = await widget.gh.board(
        p.id,
        groupFieldId: prefs.groupFieldFor(p.id),
        estimateFieldId: prefs.estimateFieldFor(p.id),
      );
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        board = b;
        loading = false;
        if (b == null) {
          error = 'Este proyecto no tiene un campo para agrupar columnas.';
        } else {
          _ensureConfigs(b);
          if (filter == BoardFilter.currentIteration &&
              b.currentIteration == null) {
            filter = BoardFilter.all;
          }
          _cache[key] = _CachedBoard(b, DateTime.now());
        }
      });
    } on AuthError {
      if (mounted) widget.onLogout();
    } catch (e) {
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        loading = false;
        if (board == null) error = '$e';
      });
      if (board != null) _snack('No se pudo actualizar: $e');
    }
  }

  void _retry() {
    final p = current;
    if (p != null && projects.any((x) => x.id == p.id)) {
      _open(p, refresh: true);
    } else {
      _init();
    }
  }

  Future<void> _scanProjects() async {
    if (scanning) return;
    setState(() => scanning = true);
    try {
      final found = await widget.gh.scanProjects();
      final merged = {for (final p in projects) p.id: p};
      var added = 0;
      for (final p in found) {
        if (merged.containsKey(p.id)) continue;
        merged[p.id] = p;
        added++;
      }
      if (!mounted) return;
      setState(() {
        projects = merged.values.toList();
        scanning = false;
      });
      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              added == 0
                  ? 'No se encontraron proyectos nuevos.'
                  : '$added proyecto(s) encontrado(s).',
            ),
          ),
        );
      if (current == null && projects.isNotEmpty) await _open(projects.first);
    } on AuthError {
      if (mounted) widget.onLogout();
    } catch (e) {
      if (!mounted) return;
      setState(() => scanning = false);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('No se pudo escanear: $e')));
    }
  }

  void _onItemChanged(Item _) => setState(() {});

  void _ensureConfigs(Board b) {
    bool changed = false;
    for (final o in b.options) {
      if (!columnConfigs.containsKey(o.id)) {
        columnConfigs[o.id] = ColumnConfig(
          optionId: o.id,
          displayName: o.name,
          color: statusPalette[b.options.indexOf(o) % statusPalette.length],
        );
        changed = true;
      }
    }
    if (changed) ThemeStore().saveColumnConfigs(columnConfigs);
  }

  Future<void> _editColumn(Option option) async {
    final cfg =
        columnConfigs[option.id] ??
        ColumnConfig(
          optionId: option.id,
          displayName: option.name,
          color:
              statusPalette[(board?.options.indexOf(option) ?? 0) %
                  statusPalette.length],
        );
    final result = await showDialog<ColumnConfig>(
      context: context,
      builder: (_) => ColumnSettingsDialog(config: cfg, palette: statusPalette),
    );
    if (result != null && mounted) {
      setState(() => columnConfigs[option.id] = result);
      ThemeStore().saveColumnConfigs(columnConfigs);
    }
  }

  void _setPrefs(BoardPreferences next) {
    final id = current?.id;
    final fieldsChanged =
        id != null &&
        (prefs.groupFieldFor(id) != next.groupFieldFor(id) ||
            prefs.estimateFieldFor(id) != next.estimateFieldFor(id));
    setState(() => prefs = next);
    BoardPreferencesStore().save(next);
    final p = current;
    if (fieldsChanged && p != null) _open(p, refresh: true);
  }

  void _onQuery(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(_searchDelay, () {
      if (!mounted) return;
      setState(() => q = value.trim());
    });
  }

  bool get _typing => _searchFocus.hasFocus;

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _escape();
      return KeyEventResult.handled;
    }
    if (_typing) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.slash) {
      _focusSearch();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyN) {
      _createFirst();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyR) {
      _refresh();
      return KeyEventResult.handled;
    }
    final index = _shortcutDigits.indexOf(key);
    if (index >= 0) {
      _moveSelectionTo(index);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _focusSearch() => _searchFocus.requestFocus();

  void _escape() {
    if (selecting) {
      setState(_clearSelection);
    } else if (_search.text.isNotEmpty || q.isNotEmpty) {
      _searchTimer?.cancel();
      _search.clear();
      setState(() => q = '');
    } else {
      _searchFocus.unfocus();
    }
  }

  void _toggleSelecting() {
    setState(() {
      selecting = !selecting;
      if (!selecting) selected.clear();
    });
  }

  void _toggleSelected(Item item) {
    setState(() {
      if (!selected.remove(item.id)) selected.add(item.id);
    });
  }

  List<Item> get _selectedItems => [
    for (final item in board?.items ?? const <Item>[])
      if (selected.contains(item.id)) item,
  ];

  Future<void> _bulkMove(String optionId) async {
    final b = board;
    if (b == null) return;
    final targets = _selectedItems
        .where((item) => item.optionId != optionId)
        .toList();
    if (targets.isEmpty) {
      setState(_clearSelection);
      return;
    }
    final before = {for (final item in targets) item.id: item.optionId};
    setState(() {
      for (final item in targets) {
        item.optionId = optionId;
      }
    });
    try {
      for (final item in targets) {
        await widget.gh.move(b.id, item.id, b.fieldId, optionId, b.fieldKind);
      }
      if (!mounted) return;
      setState(_clearSelection);
      _snack('${targets.length} tarjetas movidas');
    } on AuthError {
      widget.onLogout();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        for (final item in targets) {
          item.optionId = before[item.id];
        }
      });
      _snack('No se pudieron mover: $e');
    }
  }

  Future<void> _bulkAssign() async {
    final me = viewer;
    final targets = _selectedItems.where((item) => item.canComment).toList();
    if (targets.isEmpty) {
      _snack('Las tarjetas seleccionadas no se pueden asignar.');
      return;
    }
    if (me == null) return;
    try {
      for (final item in targets) {
        await widget.gh.setAssigned(item.cid!, me.id, true);
      }
      if (!mounted) return;
      setState(() {
        for (final item in targets) {
          if (!item.assignees.contains(me.login)) {
            item.assignees = [...item.assignees, me.login];
          }
        }
        _clearSelection();
      });
      _snack('${targets.length} tarjetas asignadas a ti');
    } on AuthError {
      widget.onLogout();
    } catch (e) {
      if (!mounted) return;
      _snack('No se pudo asignar: $e');
      _refresh();
    }
  }

  Future<void> _bulkState(bool closed) async {
    final targets = _selectedItems.where((item) => item.canComment).toList();
    if (targets.isEmpty) {
      _snack('Las tarjetas seleccionadas no se pueden cerrar.');
      return;
    }
    try {
      for (final item in targets) {
        await widget.gh.setOpenState(item.cid!, item.kind, closed);
      }
      if (!mounted) return;
      setState(() {
        for (final item in targets) {
          item.state = closed ? 'CLOSED' : 'OPEN';
        }
        _clearSelection();
      });
      _snack(
        closed
            ? '${targets.length} tarjetas cerradas'
            : '${targets.length} tarjetas reabiertas',
      );
    } on AuthError {
      widget.onLogout();
    } catch (e) {
      if (!mounted) return;
      _snack('No se pudo cambiar el estado: $e');
      _refresh();
    }
  }

  Future<void> _createItem(Option? option) async {
    final b = board;
    final proj = current;
    if (b == null || proj == null) return;
    final columnName = option == null
        ? 'Sin estado'
        : columnDisplayName(option, columnConfigs);
    final request = await showCreateItem(context, columnName: columnName);
    if (request == null || !mounted) return;
    try {
      final String? itemId;
      if (request.isExisting) {
        final contentId = await widget.gh.contentId(request.reference!);
        itemId = await widget.gh.addExisting(b.id, contentId);
      } else {
        itemId = await widget.gh.createDraft(
          b.id,
          request.title!,
          request.body ?? '',
        );
      }
      if (itemId != null && option != null) {
        await widget.gh.setField(b.id, itemId, b.fieldId, {
          b.fieldKind == FieldKind.iteration
                  ? 'iterationId'
                  : 'singleSelectOptionId':
              option.id,
        });
      }
      if (!mounted) return;
      _cache.remove(_cacheKey(proj.id));
      await _open(proj, refresh: true);
      _snack(request.isExisting ? 'Añadida al proyecto' : 'Tarjeta creada');
    } on AuthError {
      widget.onLogout();
    } catch (e) {
      if (mounted) _snack('No se pudo añadir: $e');
    }
  }

  Future<void> _openViews() async {
    final proj = current;
    if (proj == null) return;
    final action = await showSavedViews(
      context,
      boardName: proj.title,
      views: prefs.viewsFor(proj.id),
    );
    if (!mounted || action == null) return;
    if (action.deleteName != null) {
      _deleteView(action.deleteName!);
    } else if (action.saveName != null) {
      _saveView(action.saveName!);
    } else if (action.apply != null) {
      await _applyView(action.apply!);
    }
  }

  void _saveView(String name) {
    final proj = current;
    if (proj == null) return;
    final view = SavedView(
      name: name,
      query: _search.text.trim(),
      filter: filter.name,
      prefs: prefs.copyWith(views: const {}),
    );
    final list = [
      for (final existing in prefs.viewsFor(proj.id))
        if (existing.name != name) existing,
      view,
    ];
    _setPrefs(prefs.copyWith(views: {...prefs.views, proj.id: list}));
    _snack('Vista "$name" guardada');
  }

  void _deleteView(String name) {
    final proj = current;
    if (proj == null) return;
    final list = [
      for (final view in prefs.viewsFor(proj.id))
        if (view.name != name) view,
    ];
    _setPrefs(prefs.copyWith(views: {...prefs.views, proj.id: list}));
    _snack('Vista eliminada');
  }

  Future<void> _applyView(SavedView view) async {
    final proj = current;
    if (proj == null) return;
    final next = view.prefs.copyWith(views: prefs.views);
    final value =
        BoardFilter.values.asNameMap()[view.filter] ?? BoardFilter.all;
    _searchTimer?.cancel();
    _search.value = TextEditingValue(
      text: view.query,
      selection: TextSelection.collapsed(offset: view.query.length),
    );
    setState(() {
      q = view.query;
      filter = value;
      prefs = next;
      _clearSelection();
    });
    BoardPreferencesStore().save(next);
    await _open(proj, refresh: true);
  }

  void _refresh() {
    final p = current;
    if (p != null) _open(p, refresh: true);
  }

  void _createFirst() {
    final b = board;
    if (b != null) _createItem(b.options.firstOrNull);
  }

  void _moveSelectionTo(int index) {
    final b = board;
    if (b == null || selected.isEmpty || index >= b.options.length) return;
    _bulkMove(b.options[index].id);
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  bool _match(Item i) {
    if (q.isNotEmpty) {
      final qq = q.toLowerCase();
      if (!i.title.toLowerCase().contains(qq) &&
          !i.ref.toLowerCase().contains(qq) &&
          !i.labels.any((l) => l.name.toLowerCase().contains(qq))) {
        return false;
      }
    }
    switch (filter) {
      case BoardFilter.open:
        return i.state != 'CLOSED' && i.state != 'MERGED';
      case BoardFilter.closed:
        return i.state == 'CLOSED' || i.state == 'MERGED';
      case BoardFilter.mine:
        final login = viewer?.login;
        return login != null && i.assignees.contains(login);
      case BoardFilter.currentIteration:
        final iteration = board?.currentIteration;
        return iteration != null && i.optionId == iteration.id;
      case BoardFilter.all:
        return true;
    }
  }

  static const _shortcutDigits = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = board?.items ?? const <Item>[];
    var openCount = 0;
    final optionCounts = <String, int>{};
    for (final item in items) {
      if (item.state != 'CLOSED' && item.state != 'MERGED') openCount++;
      final optionId = item.optionId;
      if (optionId != null) {
        optionCounts[optionId] = (optionCounts[optionId] ?? 0) + 1;
      }
    }
    final orderedOptions = board == null
        ? const <Option>[]
        : orderColumns(board!, columnConfigs, prefs, optionCounts);
    final groupedItems = board == null
        ? <String?, List<Item>>{}
        : groupItems(
            items.where(_match),
            prefs.cardSort,
            inverted: prefs.cardSortInverted,
          );
    final estimateSums = <String?, double>{};
    if (board?.estimateField != null) {
      for (final entry in groupedItems.entries) {
        estimateSums[entry.key] = entry.value.fold(
          0.0,
          (sum, item) => sum + (item.estimate ?? 0),
        );
      }
    }
    final columnColors = {
      for (final (index, option)
          in (board?.options ?? const <Option>[]).indexed)
        option.id:
            columnConfigs[option.id]?.color ??
            statusPalette[index % statusPalette.length],
    };
    final iteration = board?.currentIteration;
    final loaded = items.length;
    final totalItems = board?.totalItems ?? loaded;
    final boardId = board?.id;

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _AppBar(
                current: current,
                projects: projects,
                profile: widget.profile,
                profiles: widget.profiles,
                onSwitchProfile: widget.onSwitchProfile,
                onAddProfile: widget.onAddProfile,
                onProjectChanged: _open,
                onScanProjects: _scanProjects,
                scanning: scanning,
                onLogout: widget.onLogout,
                searchController: _search,
                searchFocus: _searchFocus,
                onQueryChanged: _onQuery,
                filter: filter,
                onFilterChanged: (f) => setState(() => filter = f),
                onRefresh: current != null ? _refresh : null,
                total: loaded,
                totalItems: totalItems,
                open: openCount,
                closed: loaded - openCount,
                showMine: viewer != null,
                boardId: boardId,
                options: orderedOptions,
                optionCounts: optionCounts,
                columnConfigs: columnConfigs,
                columnColors: columnColors,
                prefs: prefs,
                onPrefsChanged: _setPrefs,
                selecting: selecting,
                onToggleSelecting: _toggleSelecting,
                onOpenViews: _openViews,
                iteration: iteration,
                fields: board?.fields ?? const [],
                groupFieldId: current == null
                    ? null
                    : prefs.groupFieldFor(current!.id),
                estimateFieldId: current == null
                    ? null
                    : prefs.estimateFieldFor(current!.id),
              ),
              if (selecting)
                _BulkBar(
                  count: selected.length,
                  board: board,
                  canAssign: viewer != null,
                  onMove: _bulkMove,
                  onAssign: _bulkAssign,
                  onClose: () => _bulkState(true),
                  onReopen: () => _bulkState(false),
                  onCancel: () => setState(_clearSelection),
                ),
              const SizedBox(height: 12),
              if (loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (error != null)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 36,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _retry,
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('Reintentar'),
                              ),
                              OutlinedButton.icon(
                                onPressed: scanning ? null : _scanProjects,
                                icon: const Icon(Icons.manage_search, size: 18),
                                label: const Text('Escanear proyectos'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (board == null)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Expanded(
                  child: _BoardArea(
                    board: board!,
                    gh: widget.gh,
                    options: orderedOptions,
                    itemsByOption: groupedItems,
                    columnConfigs: columnConfigs,
                    columnColors: columnColors,
                    estimateSums: estimateSums,
                    prefs: prefs,
                    selecting: selecting,
                    selected: selected,
                    onToggleSelect: _toggleSelected,
                    onCreate: _createItem,
                    onEditColumn: _editColumn,
                    onMove: _move,
                    onItemChanged: _onItemChanged,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _move(Item it, String optionId) async {
    if (it.optionId == optionId || board == null) return;
    final before = it.optionId;
    setState(() => it.optionId = optionId);
    try {
      await widget.gh.move(
        board!.id,
        it.id,
        board!.fieldId,
        optionId,
        board!.fieldKind,
      );
      if (!mounted) return;
      final name =
          board!.options
              .where((option) => option.id == optionId)
              .firstOrNull
              ?.name ??
          'otra columna';
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Movida a $name'),
          action: before == null
              ? null
              : SnackBarAction(
                  label: 'Deshacer',
                  onPressed: () => _move(it, before),
                ),
        ),
      );
    } on AuthError {
      widget.onLogout();
    } catch (e) {
      if (!mounted) return;
      setState(() => it.optionId = before);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo mover: $e')));
    }
  }
}

class _AppBar extends StatefulWidget {
  final Proj? current;
  final List<Proj> projects;
  final Profile profile;
  final List<Profile> profiles;
  final ValueChanged<String> onSwitchProfile;
  final VoidCallback onAddProfile;
  final ValueChanged<Proj> onProjectChanged;
  final VoidCallback onLogout;
  final VoidCallback? onScanProjects;
  final bool scanning;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final ValueChanged<String> onQueryChanged;
  final BoardFilter filter;
  final ValueChanged<BoardFilter> onFilterChanged;
  final VoidCallback? onRefresh;
  final int total;
  final int totalItems;
  final int open;
  final int closed;
  final bool showMine;
  final String? boardId;
  final List<Option> options;
  final Map<String, int> optionCounts;
  final Map<String, ColumnConfig> columnConfigs;
  final Map<String, Color> columnColors;
  final BoardPreferences prefs;
  final ValueChanged<BoardPreferences> onPrefsChanged;
  final bool selecting;
  final VoidCallback onToggleSelecting;
  final VoidCallback onOpenViews;
  final Option? iteration;
  final List<ProjectField> fields;
  final String? groupFieldId;
  final String? estimateFieldId;

  const _AppBar({
    required this.current,
    required this.projects,
    required this.profile,
    required this.profiles,
    required this.onSwitchProfile,
    required this.onAddProfile,
    required this.onProjectChanged,
    required this.onLogout,
    this.onScanProjects,
    required this.scanning,
    required this.searchController,
    required this.searchFocus,
    required this.onQueryChanged,
    required this.filter,
    required this.onFilterChanged,
    this.onRefresh,
    required this.total,
    required this.totalItems,
    required this.open,
    required this.closed,
    required this.showMine,
    this.boardId,
    required this.options,
    required this.optionCounts,
    required this.columnConfigs,
    required this.columnColors,
    required this.prefs,
    required this.onPrefsChanged,
    required this.selecting,
    required this.onToggleSelecting,
    required this.onOpenViews,
    this.iteration,
    required this.fields,
    this.groupFieldId,
    this.estimateFieldId,
  });

  @override
  State<_AppBar> createState() => _AppBarState();
}

class _AppBarState extends State<_AppBar> {
  Future<void> _openBoardSettings() async {
    final id = widget.boardId;
    if (id == null) return;
    final result = await showBoardSettings(
      context,
      prefs: widget.prefs,
      boardId: id,
      columns: widget.options,
      fields: widget.fields,
      groupFieldId: widget.groupFieldId,
      estimateFieldId: widget.estimateFieldId,
      columnConfigs: widget.columnConfigs,
      columnColors: widget.columnColors,
      counts: widget.optionCounts,
    );
    if (result != null) widget.onPrefsChanged(result);
  }

  Widget _viewMenu() => PopupMenuButton<BoardViewMode>(
    tooltip: 'Cambiar vista',
    icon: Icon(_viewIcon(widget.prefs.view), size: 20),
    onSelected: (mode) =>
        widget.onPrefsChanged(widget.prefs.copyWith(view: mode)),
    itemBuilder: (_) => [
      for (final mode in BoardViewMode.values)
        CheckedPopupMenuItem(
          value: mode,
          checked: widget.prefs.view == mode,
          child: Text(_viewLabel(mode)),
        ),
    ],
  );

  Widget _selectButton() => IconButton(
    tooltip: 'Seleccionar tarjetas',
    isSelected: widget.selecting,
    icon: const Icon(Icons.checklist, size: 20),
    color: widget.selecting ? Theme.of(context).colorScheme.primary : null,
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    onPressed: widget.onToggleSelecting,
  );

  Widget _viewsButton() => IconButton(
    tooltip: 'Vistas guardadas',
    icon: const Icon(Icons.bookmarks_outlined, size: 20),
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    onPressed: widget.onOpenViews,
  );

  Widget _settingsButton() => IconButton(
    tooltip: 'Organizar columnas y tarjetas',
    icon: const Icon(Icons.tune, size: 19),
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    onPressed: _openBoardSettings,
  );

  Widget _projectPicker({bool expanded = false}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: BoxConstraints(maxWidth: expanded ? double.infinity : 240),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: DropdownButton<Proj>(
        value: widget.current,
        isExpanded: expanded,
        underline: const SizedBox(),
        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
        style: TextStyle(
          fontSize: 13,
          color: cs.onSurface,
          fontWeight: FontWeight.w500,
        ),
        items: [
          for (final p in widget.projects)
            DropdownMenuItem(
              value: p,
              child: Text(p.title, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (p) {
          if (p != null) widget.onProjectChanged(p);
        },
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: Text(
          '¿Cerrar sesión de @${widget.profile.login}? '
          'La cuenta se quitará de este dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (ok == true) widget.onLogout();
  }

  Widget _profileMenu(ColorScheme cs) {
    final others = [
      for (final p in widget.profiles)
        if (p.id != widget.profile.id) p,
    ];
    return PopupMenuButton<String>(
      tooltip: 'Cuenta: @${widget.profile.login}',
      constraints: const BoxConstraints(minWidth: 230, maxWidth: 300),
      onSelected: (value) {
        switch (value) {
          case 'profile':
            showProfileSheet(context, widget.profile);
            break;
          case 'add':
            widget.onAddProfile();
            break;
          case 'logout':
            _confirmLogout();
            break;
          default:
            if (value.startsWith('switch:')) {
              widget.onSwitchProfile(value.substring(7));
            }
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: 'profile',
          child: Row(
            children: [
              ProfileAvatar(profile: widget.profile, radius: 14),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.profile.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(
                      '@${widget.profile.login}',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (others.isNotEmpty) const PopupMenuDivider(),
        for (final p in others)
          PopupMenuItem<String>(
            value: 'switch:${p.id}',
            child: Row(
              children: [
                ProfileAvatar(profile: p, radius: 12),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    '@${p.login}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'add',
          child: Row(
            children: [
              Icon(Icons.person_add_alt, size: 18),
              SizedBox(width: 9),
              Text('Añadir cuenta', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 18),
              SizedBox(width: 9),
              Text('Cerrar sesión', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: ProfileAvatar(profile: widget.profile, radius: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isWide = MediaQuery.sizeOf(context).width >= 980;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.grid_view, size: 18, color: cs.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Betelgeuse',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      widget.current?.title ?? 'Selecciona un proyecto',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isWide && widget.projects.isNotEmpty) _projectPicker(),
              const SizedBox(width: 4),
              if (isWide && widget.current?.url != null)
                IconButton(
                  tooltip: 'Abrir proyecto en GitHub',
                  icon: const Icon(Icons.open_in_new, size: 19),
                  onPressed: () => openGitHub(widget.current!.url),
                ),
              if (isWide && widget.boardId != null) ...[
                _viewMenu(),
                _selectButton(),
                _viewsButton(),
                _settingsButton(),
              ],
              if (widget.onScanProjects != null)
                IconButton(
                  tooltip: 'Escanear proyectos',
                  icon: widget.scanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.manage_search, size: 20),
                  onPressed: widget.scanning ? null : widget.onScanProjects,
                ),
              IconButton(
                tooltip: 'Recargar',
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: widget.onRefresh,
              ),
              IconButton(
                tooltip: 'Apariencia',
                icon: const Icon(Icons.palette_outlined, size: 20),
                onPressed: () => showThemePicker(context),
              ),
              _profileMenu(cs),
            ],
          ),
          if (!isWide && widget.projects.isNotEmpty) ...[
            const SizedBox(height: 8),
            _projectPicker(expanded: true),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: widget.searchController,
            focusNode: widget.searchFocus,
            onChanged: (v) {
              widget.onQueryChanged(v);
              setState(() {});
            },
            decoration: InputDecoration(
              hintText: 'Buscar título, repo o etiqueta…',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: widget.searchController.text.isNotEmpty
                  ? IconButton(
                      tooltip: 'Limpiar búsqueda',
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        widget.searchController.clear();
                        widget.onQueryChanged('');
                        setState(() {});
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChipWidget(
                    value: BoardFilter.all,
                    groupValue: widget.filter,
                    onChanged: widget.onFilterChanged,
                  ),
                  const SizedBox(width: 6),
                  FilterChipWidget(
                    value: BoardFilter.open,
                    groupValue: widget.filter,
                    onChanged: widget.onFilterChanged,
                  ),
                  const SizedBox(width: 6),
                  FilterChipWidget(
                    value: BoardFilter.closed,
                    groupValue: widget.filter,
                    onChanged: widget.onFilterChanged,
                  ),
                  if (widget.showMine) ...[
                    const SizedBox(width: 6),
                    FilterChipWidget(
                      value: BoardFilter.mine,
                      groupValue: widget.filter,
                      onChanged: widget.onFilterChanged,
                    ),
                  ],
                  if (widget.iteration != null) ...[
                    const SizedBox(width: 6),
                    FilterChipWidget(
                      value: BoardFilter.currentIteration,
                      groupValue: widget.filter,
                      onChanged: widget.onFilterChanged,
                    ),
                  ],
                  const SizedBox(width: 12),
                  if (!isWide && widget.boardId != null) ...[
                    _viewMenu(),
                    _selectButton(),
                    _viewsButton(),
                    _settingsButton(),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    '${widget.total} tarjetas · ${widget.open} abiertas · ${widget.closed} cerradas',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  if (widget.totalItems > widget.total) ...[
                    const SizedBox(width: 10),
                    Tooltip(
                      message:
                          'Se cargan como máximo 1000 tarjetas del proyecto.',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 13,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Mostrando ${widget.total} de ${widget.totalItems}',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardArea extends StatelessWidget {
  final Board board;
  final GitHub gh;
  final List<Option> options;
  final Map<String?, List<Item>> itemsByOption;
  final Map<String, ColumnConfig> columnConfigs;
  final Map<String, Color> columnColors;
  final Map<String?, double> estimateSums;
  final BoardPreferences prefs;
  final bool selecting;
  final Set<String> selected;
  final ValueChanged<Item> onToggleSelect;
  final void Function(Option?) onCreate;
  final ValueChanged<Option> onEditColumn;
  final void Function(Item, String) onMove;
  final ValueChanged<Item> onItemChanged;

  const _BoardArea({
    required this.board,
    required this.gh,
    required this.options,
    required this.itemsByOption,
    required this.columnConfigs,
    required this.columnColors,
    required this.estimateSums,
    required this.prefs,
    required this.selecting,
    required this.selected,
    required this.onToggleSelect,
    required this.onCreate,
    required this.onEditColumn,
    required this.onMove,
    required this.onItemChanged,
  });

  double? _sum(Option? option) => estimateSums[option?.id];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final looseItems = itemsByOption[null] ?? const <Item>[];
    final cols = <Option?>[...options, if (looseItems.isNotEmpty) null];

    if (board.items.isEmpty && board.options.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.view_kanban_outlined,
                size: 40,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              const Text('Sin tarjetas'),
              const SizedBox(height: 4),
              Text(
                'Añade issues o pull requests a este proyecto en GitHub.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (prefs.view == BoardViewMode.table) {
      return BoardTableView(
        gh: gh,
        board: board,
        options: options,
        itemsByOption: itemsByOption,
        columnConfigs: columnConfigs,
        colors: columnColors,
        onMove: onMove,
        onItemChanged: onItemChanged,
        estimateSum: _sum,
        onCreate: onCreate,
        selecting: selecting,
        selected: selected,
        onToggleSelect: onToggleSelect,
      );
    }

    if (prefs.view == BoardViewMode.list ||
        prefs.view == BoardViewMode.compact) {
      return BoardListView(
        gh: gh,
        board: board,
        options: options,
        itemsByOption: itemsByOption,
        columnConfigs: columnConfigs,
        colors: columnColors,
        onEditColumn: onEditColumn,
        onMove: onMove,
        onItemChanged: onItemChanged,
        estimateSum: _sum,
        onCreate: onCreate,
        dense: prefs.view == BoardViewMode.compact,
        selecting: selecting,
        selected: selected,
        onToggleSelect: onToggleSelect,
      );
    }

    if (isWide) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final option in cols)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(width: 300, child: _columnView(option)),
              ),
          ],
        ),
      );
    }

    return PageView.builder(
      key: ValueKey('board-${board.id}'),
      padEnds: false,
      itemCount: cols.length,
      itemBuilder: (_, index) {
        final option = cols[index];
        return Semantics(
          container: true,
          label: 'Columna ${index + 1} de ${cols.length}',
          child: Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 16 : 8,
              right: index == cols.length - 1 ? 16 : 8,
              bottom: 16,
            ),
            child: _columnView(option),
          ),
        );
      },
    );
  }

  Widget _columnView(Option? option) {
    final items = itemsByOption[option?.id] ?? const <Item>[];
    return ColumnView(
      gh: gh,
      board: board,
      option: option,
      accent: _accent(option),
      items: items,
      config: option == null ? null : columnConfigs[option.id],
      onEditColumn: option == null ? null : () => onEditColumn(option),
      columnColors: columnColors,
      itemsCount: items.length,
      estimateSum: _sum(option),
      onCreate: () => onCreate(option),
      selecting: selecting,
      selected: selected,
      onToggleSelect: onToggleSelect,
      onMove: onMove,
      onItemChanged: onItemChanged,
    );
  }

  Color _accent(Option? option) =>
      option == null ? noStatusColor : columnColors[option.id] ?? noStatusColor;
}

class _BulkBar extends StatelessWidget {
  final int count;
  final Board? board;
  final bool canAssign;
  final ValueChanged<String> onMove;
  final VoidCallback onAssign;
  final VoidCallback onClose;
  final VoidCallback onReopen;
  final VoidCallback onCancel;

  const _BulkBar({
    required this.count,
    required this.board,
    required this.canAssign,
    required this.onMove,
    required this.onAssign,
    required this.onClose,
    required this.onReopen,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = count > 0;
    return Material(
      color: cs.surfaceContainerHigh,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
        child: Row(
          children: [
            Text(
              '$count seleccionadas',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            MenuAnchor(
              builder: (context, controller, child) => TextButton.icon(
                onPressed: enabled && (board?.options.isNotEmpty ?? false)
                    ? () => controller.isOpen
                          ? controller.close()
                          : controller.open()
                    : null,
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Mover'),
              ),
              menuChildren: [
                for (final option in board?.options ?? const <Option>[])
                  MenuItemButton(
                    onPressed: () => onMove(option.id),
                    child: Text(option.name),
                  ),
              ],
            ),
            TextButton.icon(
              onPressed: enabled && canAssign ? onAssign : null,
              icon: const Icon(Icons.person_add_alt, size: 18),
              label: const Text('Asignarme'),
            ),
            TextButton.icon(
              onPressed: enabled ? onClose : null,
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Cerrar'),
            ),
            TextButton.icon(
              onPressed: enabled ? onReopen : null,
              icon: const Icon(Icons.undo, size: 18),
              label: const Text('Reabrir'),
            ),
            IconButton(
              tooltip: 'Cancelar selección',
              icon: const Icon(Icons.close, size: 20),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              padding: EdgeInsets.zero,
              onPressed: onCancel,
            ),
          ],
        ),
      ),
    );
  }
}

class _CachedBoard {
  final Board board;
  final DateTime at;

  const _CachedBoard(this.board, this.at);
}

IconData _viewIcon(BoardViewMode mode) => switch (mode) {
  BoardViewMode.kanban => Icons.view_kanban_outlined,
  BoardViewMode.list => Icons.view_list_outlined,
  BoardViewMode.compact => Icons.view_stream_outlined,
  BoardViewMode.table => Icons.table_rows_outlined,
};

String _viewLabel(BoardViewMode mode) => switch (mode) {
  BoardViewMode.kanban => 'Tablero',
  BoardViewMode.list => 'Lista',
  BoardViewMode.compact => 'Compacta',
  BoardViewMode.table => 'Tabla',
};
