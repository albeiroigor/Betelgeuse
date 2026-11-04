import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:betelgeuse/core/theme/app_theme.dart';
import 'package:betelgeuse/features/board/board_layout.dart';
import 'package:betelgeuse/github/models.dart';

void main() {
  const todo = Option('todo', 'Todo');
  const doing = Option('doing', 'En progreso');
  const done = Option('done', 'Hecho');

  Item item(
    String id,
    String title,
    String option, {
    String? updatedAt,
    String? createdAt,
    int? number,
  }) => Item(
    id,
    title,
    'repo#$id',
    'Issue',
    'OPEN',
    null,
    null,
    const [],
    option,
    'content-$id',
    false,
    updatedAt: updatedAt,
    createdAt: createdAt,
    number: number ?? int.tryParse(id),
  );

  final board = Board(
    id: 'board-1',
    fieldId: 'field-1',
    fieldName: 'Status',
    fieldKind: FieldKind.singleSelect,
    options: const [todo, doing, done],
    items: [
      item(
        '1',
        'Zeta',
        'todo',
        updatedAt: '2024-01-01T00:00:00Z',
        createdAt: '2024-01-01T00:00:00Z',
      ),
      item(
        '2',
        'Alfa',
        'todo',
        updatedAt: '2024-03-01T00:00:00Z',
        createdAt: '2024-03-01T00:00:00Z',
      ),
      item(
        '3',
        'Beta',
        'doing',
        updatedAt: '2024-02-01T00:00:00Z',
        createdAt: '2024-02-15T00:00:00Z',
      ),
      item('4', 'Gamma', 'doing', createdAt: '2024-01-15T00:00:00Z'),
      item('5', 'Delta', 'doing', createdAt: '2024-03-15T00:00:00Z'),
      item('6', 'Omega', 'done', createdAt: '2024-06-01T00:00:00Z'),
    ],
  );
  const configs = <String, ColumnConfig>{};
  const counts = {'todo': 2, 'doing': 3, 'done': 1};

  test('ordena las columnas de forma alfabética', () {
    final ordered = orderColumns(
      board,
      configs,
      const BoardPreferences(columnOrder: ColumnOrder.alphabetical),
      counts,
    );

    expect(ordered.map((o) => o.id), ['doing', 'done', 'todo']);
  });

  test('ordena las columnas por cantidad de tarjetas', () {
    final ordered = orderColumns(
      board,
      configs,
      const BoardPreferences(columnOrder: ColumnOrder.cards),
      counts,
    );

    expect(ordered.map((o) => o.id), ['doing', 'todo', 'done']);
  });

  test('respeta el orden manual y añade las columnas nuevas al final', () {
    final ordered = orderColumns(
      board,
      configs,
      const BoardPreferences(
        columnOrder: ColumnOrder.manual,
        manualOrders: {
          'board-1': ['done', 'desconocida'],
        },
      ),
      counts,
    );

    expect(ordered.map((o) => o.id), ['done', 'todo', 'doing']);
  });

  test('usa el nombre personalizado al ordenar alfabéticamente', () {
    final ordered = orderColumns(
      board,
      {
        'todo': ColumnConfig(
          optionId: 'todo',
          displayName: 'AAA',
          color: const Color(0xFF22D3EE),
        ),
      },
      const BoardPreferences(columnOrder: ColumnOrder.alphabetical),
      counts,
    );

    expect(ordered.map((o) => o.id), ['todo', 'doing', 'done']);
  });

  test('ordena las tarjetas por título y por fecha', () {
    final byTitle = groupItems(board.items, CardSort.alphabetical);
    final byRecent = groupItems(board.items, CardSort.recent);

    expect(byTitle['doing']!.map((i) => i.title), ['Beta', 'Delta', 'Gamma']);
    expect(byRecent['todo']!.map((i) => i.title), ['Alfa', 'Zeta']);
    expect(byRecent['doing']!.last.title, 'Gamma');
  });

  test('invierte cualquier orden de tarjetas', () {
    final byTitle = groupItems(
      board.items,
      CardSort.alphabetical,
      inverted: true,
    );
    final byNumber = groupItems(
      board.items,
      CardSort.issueNumber,
      inverted: true,
    );
    final byCreation = groupItems(
      board.items,
      CardSort.creation,
      inverted: true,
    );
    final manual = groupItems(board.items, CardSort.manual, inverted: true);

    expect(byTitle['doing']!.map((i) => i.title), ['Gamma', 'Delta', 'Beta']);
    expect(byNumber['doing']!.map((i) => i.title), ['Delta', 'Gamma', 'Beta']);
    expect(byCreation['doing']!.map((i) => i.title), [
      'Delta',
      'Beta',
      'Gamma',
    ]);
    expect(manual['doing']!.map((i) => i.title), ['Delta', 'Gamma', 'Beta']);
  });

  test('ordena las tarjetas por número de issue y por creación', () {
    final byNumber = groupItems(board.items, CardSort.issueNumber);
    final byCreation = groupItems(board.items, CardSort.creation);

    expect(byNumber['doing']!.map((i) => i.title), ['Beta', 'Gamma', 'Delta']);
    expect(byCreation['doing']!.map((i) => i.title), [
      'Gamma',
      'Beta',
      'Delta',
    ]);
    expect(byCreation['todo']!.map((i) => i.title), ['Zeta', 'Alfa']);
  });

  test('las preferencias hacen round-trip incluyendo el orden manual', () {
    const prefs = BoardPreferences(
      columnOrder: ColumnOrder.manual,
      cardSort: CardSort.recent,
      cardSortInverted: true,
      view: BoardViewMode.list,
      manualOrders: {
        'board-1': ['done', 'todo', 'doing'],
      },
    );

    final restored = BoardPreferences.fromJson(prefs.toJson());

    expect(restored.columnOrder, ColumnOrder.manual);
    expect(restored.cardSort, CardSort.recent);
    expect(restored.cardSortInverted, isTrue);
    expect(restored.view, BoardViewMode.list);
    expect(restored.manualOrderFor('board-1'), ['done', 'todo', 'doing']);
  });

  test('resolvedManualOrder limpia ids viejos y añade los que faltan', () {
    final order = resolvedManualOrder(
      const [todo, doing, done],
      const ['done', 'vieja'],
    );

    expect(order, ['done', 'todo', 'doing']);
  });

  test('las preferencias guardan vistas y campos por tablero', () {
    const prefs = BoardPreferences(
      groupFields: {'board-1': 'field-status'},
      estimateFields: {'board-1': 'field-points'},
      views: {
        'board-1': [SavedView(name: 'Mías', query: 'bug', filter: 'mine')],
      },
    );

    final restored = BoardPreferences.fromJson(prefs.toJson());
    final view = restored.viewsFor('board-1').single;

    expect(restored.groupFieldFor('board-1'), 'field-status');
    expect(restored.estimateFieldFor('board-1'), 'field-points');
    expect(view.name, 'Mías');
    expect(view.query, 'bug');
    expect(view.filter, 'mine');
    expect(view.prefs.views, isEmpty);
  });

  test('detecta la iteración en curso', () {
    final current = Option(
      'i1',
      'Sprint 1',
      start: DateTime.now().subtract(const Duration(days: 1)),
      duration: 14,
    );

    expect(current.isCurrent, isTrue);
    expect(const Option('i2', 'Vieja').isCurrent, isFalse);
  });
}
