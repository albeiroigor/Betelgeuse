import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../github/models.dart';

enum ColumnOrder { github, alphabetical, cards, manual }

enum CardSort { manual, alphabetical, issueNumber, creation, recent }

enum BoardViewMode { kanban, list, compact, table }

class SavedView {
  final String name;
  final String query;
  final String filter;
  final BoardPreferences prefs;

  const SavedView({
    required this.name,
    this.query = '',
    this.filter = 'all',
    this.prefs = const BoardPreferences(),
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'query': query,
    'filter': filter,
    'prefs': prefs.toJson(),
  };

  factory SavedView.fromJson(Map<String, dynamic> json) => SavedView(
    name: '${json['name'] ?? 'Vista'}',
    query: '${json['query'] ?? ''}',
    filter: '${json['filter'] ?? 'all'}',
    prefs: BoardPreferences.fromJson(
      Map<String, dynamic>.from(json['prefs'] as Map? ?? const {}),
      withViews: false,
    ),
  );
}

class BoardPreferences {
  final ColumnOrder columnOrder;
  final CardSort cardSort;
  final bool cardSortInverted;
  final BoardViewMode view;
  final Map<String, List<String>> manualOrders;
  final Map<String, String> groupFields;
  final Map<String, String> estimateFields;
  final Map<String, List<SavedView>> views;

  const BoardPreferences({
    this.columnOrder = ColumnOrder.github,
    this.cardSort = CardSort.manual,
    this.cardSortInverted = false,
    this.view = BoardViewMode.kanban,
    this.manualOrders = const {},
    this.groupFields = const {},
    this.estimateFields = const {},
    this.views = const {},
  });

  BoardPreferences copyWith({
    ColumnOrder? columnOrder,
    CardSort? cardSort,
    bool? cardSortInverted,
    BoardViewMode? view,
    Map<String, List<String>>? manualOrders,
    Map<String, String>? groupFields,
    Map<String, String>? estimateFields,
    Map<String, List<SavedView>>? views,
  }) => BoardPreferences(
    columnOrder: columnOrder ?? this.columnOrder,
    cardSort: cardSort ?? this.cardSort,
    cardSortInverted: cardSortInverted ?? this.cardSortInverted,
    view: view ?? this.view,
    manualOrders: manualOrders ?? this.manualOrders,
    groupFields: groupFields ?? this.groupFields,
    estimateFields: estimateFields ?? this.estimateFields,
    views: views ?? this.views,
  );

  List<String> manualOrderFor(String boardId) =>
      manualOrders[boardId] ?? const [];

  String? groupFieldFor(String boardId) => groupFields[boardId];

  String? estimateFieldFor(String boardId) => estimateFields[boardId];

  List<SavedView> viewsFor(String boardId) => views[boardId] ?? const [];

  Map<String, dynamic> toJson() => {
    'columnOrder': columnOrder.name,
    'cardSort': cardSort.name,
    'inverted': cardSortInverted,
    'view': view.name,
    'manual': manualOrders,
    'groupFields': groupFields,
    'estimateFields': estimateFields,
    'views': {
      for (final entry in views.entries)
        entry.key: [for (final view in entry.value) view.toJson()],
    },
  };

  factory BoardPreferences.fromJson(
    Map<String, dynamic> json, {
    bool withViews = true,
  }) {
    final manual = <String, List<String>>{};
    final rawManual = json['manual'];
    if (rawManual is Map) {
      for (final entry in rawManual.entries) {
        final ids = entry.value;
        if (ids is List) manual['${entry.key}'] = [for (final id in ids) '$id'];
      }
    }
    Map<String, String> stringMap(Object? raw) => {
      if (raw is Map)
        for (final entry in raw.entries) '${entry.key}': '${entry.value}',
    };
    final views = <String, List<SavedView>>{};
    if (withViews && json['views'] is Map) {
      for (final entry in (json['views'] as Map).entries) {
        final list = entry.value;
        if (list is List) {
          views['${entry.key}'] = [
            for (final item in list)
              if (item is Map)
                SavedView.fromJson(Map<String, dynamic>.from(item)),
          ];
        }
      }
    }
    return BoardPreferences(
      columnOrder:
          ColumnOrder.values.asNameMap()[json['columnOrder']] ??
          ColumnOrder.github,
      cardSort:
          CardSort.values.asNameMap()[json['cardSort']] ?? CardSort.manual,
      cardSortInverted: json['inverted'] == true,
      view:
          BoardViewMode.values.asNameMap()[json['view']] ??
          BoardViewMode.kanban,
      manualOrders: manual,
      groupFields: stringMap(json['groupFields']),
      estimateFields: stringMap(json['estimateFields']),
      views: views,
    );
  }
}

class BoardPreferencesStore {
  static const _key = 'betelgeuse_board_prefs';

  Future<BoardPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const BoardPreferences();
    try {
      return BoardPreferences.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return const BoardPreferences();
    }
  }

  Future<void> save(BoardPreferences prefs) async {
    final store = await SharedPreferences.getInstance();
    await store.setString(_key, jsonEncode(prefs.toJson()));
  }
}

String columnDisplayName(Option option, Map<String, ColumnConfig> configs) {
  final custom = configs[option.id]?.displayName.trim();
  return custom == null || custom.isEmpty ? option.name : custom;
}

List<String> resolvedManualOrder(List<Option> columns, List<String> current) {
  final known = {for (final option in columns) option.id};
  final order = [
    for (final id in current)
      if (known.contains(id)) id,
  ];
  for (final option in columns) {
    if (!order.contains(option.id)) order.add(option.id);
  }
  return order;
}

List<Option> orderColumns(
  Board board,
  Map<String, ColumnConfig> configs,
  BoardPreferences prefs,
  Map<String, int> counts,
) {
  final index = {
    for (var i = 0; i < board.options.length; i++) board.options[i].id: i,
  };
  final options = [...board.options];

  switch (prefs.columnOrder) {
    case ColumnOrder.github:
      return options;
    case ColumnOrder.alphabetical:
      options.sort((a, b) {
        final byName = columnDisplayName(
          a,
          configs,
        ).toLowerCase().compareTo(columnDisplayName(b, configs).toLowerCase());
        return byName != 0 ? byName : index[a.id]!.compareTo(index[b.id]!);
      });
      return options;
    case ColumnOrder.cards:
      options.sort((a, b) {
        final byCount = (counts[b.id] ?? 0).compareTo(counts[a.id] ?? 0);
        return byCount != 0 ? byCount : index[a.id]!.compareTo(index[b.id]!);
      });
      return options;
    case ColumnOrder.manual:
      final byId = {for (final option in options) option.id: option};
      return [
        for (final id in resolvedManualOrder(
          options,
          prefs.manualOrderFor(board.id),
        ))
          byId[id]!,
      ];
  }
}

Map<String?, List<Item>> groupItems(
  Iterable<Item> items,
  CardSort sort, {
  bool inverted = false,
}) {
  final out = <String?, List<Item>>{};
  for (final item in items) {
    out.putIfAbsent(item.optionId, () => []).add(item);
  }
  for (final list in out.values) {
    sortItems(list, sort, inverted: inverted);
  }
  return out;
}

void sortItems(List<Item> items, CardSort sort, {bool inverted = false}) {
  final comparator = switch (sort) {
    CardSort.alphabetical => _byTitle,
    CardSort.issueNumber => _byNumber,
    CardSort.creation => _byCreation,
    CardSort.recent => _byRecent,
    CardSort.manual => null,
  };
  if (comparator != null) items.sort(comparator);
  if (inverted) {
    final reversed = items.reversed.toList();
    items
      ..clear()
      ..addAll(reversed);
  }
}

int _byTitle(Item a, Item b) {
  final byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());
  if (byTitle != 0) return byTitle;
  return a.ref.toLowerCase().compareTo(b.ref.toLowerCase());
}

int _byRecent(Item a, Item b) {
  final da = DateTime.tryParse(a.updatedAt ?? '');
  final db = DateTime.tryParse(b.updatedAt ?? '');
  if (da == null && db == null) return _byTitle(a, b);
  if (da == null) return 1;
  if (db == null) return -1;
  final byDate = db.compareTo(da);
  return byDate != 0 ? byDate : _byTitle(a, b);
}

int _byCreation(Item a, Item b) {
  final da = DateTime.tryParse(a.createdAt ?? '');
  final db = DateTime.tryParse(b.createdAt ?? '');
  if (da == null && db == null) return _byTitle(a, b);
  if (da == null) return 1;
  if (db == null) return -1;
  final byDate = da.compareTo(db);
  return byDate != 0 ? byDate : _byTitle(a, b);
}

int _byNumber(Item a, Item b) {
  final na = a.number;
  final nb = b.number;
  if (na == null && nb == null) return _byTitle(a, b);
  if (na == null) return 1;
  if (nb == null) return -1;
  final byNumber = na.compareTo(nb);
  if (byNumber != 0) return byNumber;
  return a.ref.toLowerCase().compareTo(b.ref.toLowerCase());
}
