import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:betelgeuse/features/board/board_layout.dart';
import 'package:betelgeuse/features/board/card_view.dart';
import 'package:betelgeuse/features/board/column_view.dart';
import 'package:betelgeuse/features/board/list_view.dart';
import 'package:betelgeuse/features/board/table_view.dart';
import 'package:betelgeuse/github/client.dart';
import 'package:betelgeuse/github/models.dart';

void main() {
  final board = Board(
    id: 'project-1',
    fieldId: 'field-1',
    fieldName: 'Status',
    fieldKind: FieldKind.singleSelect,
    options: const [Option('todo', 'Todo'), Option('doing', 'En progreso')],
    items: [
      Item(
        'item-1',
        'Arreglar el layout de las tarjetas que se desborda en pantallas pequeñas',
        'repo#12',
        'Issue',
        'OPEN',
        'https://github.com/repo/repo/issues/12',
        null,
        const [Label('bug', 'd73a4a'), Label('ui', '1d76db')],
        'todo',
        'content-1',
        false,
      ),
    ],
  );

  testWidgets('la columna y la tarjeta se renderizan sin errores', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 600,
              child: ColumnView(
                gh: GitHub('fake-token'),
                board: board,
                option: board.options.first,
                accent: const Color(0xFF8B5CF6),
                items: board.items,
                itemsCount: board.items.length,
                columnColors: const {'todo': Color(0xFF8B5CF6)},
                onMove: (_, _) {},
                onItemChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('repo#12'), findsOneWidget);
    expect(find.text('Todo'), findsOneWidget);
  });

  testWidgets('la tarjeta sobrevive en un ancho estrecho', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 220,
              child: ItemCardView(
                gh: GitHub('fake-token'),
                board: board,
                item: board.items.first,
                accent: const Color(0xFF22D3EE),
                columnColors: const {'todo': Color(0xFF22D3EE)},
                onMove: (_, _) {},
                onItemChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Arreglar el layout'), findsOneWidget);
  });

  testWidgets('el clic derecho abre el menú contextual', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 300,
              child: ItemCardView(
                gh: GitHub('fake-token'),
                board: board,
                item: board.items.first,
                accent: const Color(0xFF22D3EE),
                columnColors: const {'todo': Color(0xFF22D3EE)},
                onMove: (_, _) {},
                onItemChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ItemCardView), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(find.text('Abrir detalle'), findsOneWidget);
    expect(find.text('Copiar enlace'), findsOneWidget);
    expect(find.text('En progreso'), findsOneWidget);
  });

  testWidgets('la vista de lista muestra columnas y tarjetas', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BoardListView(
            gh: GitHub('fake-token'),
            board: board,
            options: board.options,
            itemsByOption: groupItems(board.items, CardSort.manual),
            columnConfigs: const {},
            colors: const {
              'todo': Color(0xFF8B5CF6),
              'doing': Color(0xFF3FB950),
            },
            onEditColumn: (_) {},
            onMove: (_, _) {},
            onItemChanged: (_) {},
            estimateSum: (_) => null,
            onCreate: (_) {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Todo'), findsWidgets);
    expect(find.text('repo#12'), findsOneWidget);
    expect(find.textContaining('Arreglar el layout'), findsOneWidget);
  });

  testWidgets('la vista de tabla muestra columnas y tarjetas', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BoardTableView(
            gh: GitHub('fake-token'),
            board: board,
            options: board.options,
            itemsByOption: groupItems(board.items, CardSort.manual),
            columnConfigs: const {},
            colors: const {
              'todo': Color(0xFF8B5CF6),
              'doing': Color(0xFF3FB950),
            },
            onMove: (_, _) {},
            onItemChanged: (_) {},
            estimateSum: (_) => null,
            onCreate: (_) {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Título'), findsOneWidget);
    expect(find.textContaining('Arreglar el layout'), findsOneWidget);
  });

  testWidgets('la vista compacta y la selección no se rompen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BoardListView(
            gh: GitHub('fake-token'),
            board: board,
            options: board.options,
            itemsByOption: groupItems(board.items, CardSort.manual),
            columnConfigs: const {},
            colors: const {
              'todo': Color(0xFF8B5CF6),
              'doing': Color(0xFF3FB950),
            },
            onEditColumn: (_) {},
            onMove: (_, _) {},
            onItemChanged: (_) {},
            estimateSum: (_) => null,
            onCreate: (_) {},
            dense: true,
            selecting: true,
            selected: {board.items.first.id},
            onToggleSelect: (_) {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(Checkbox), findsWidgets);
    expect(find.textContaining('Arreglar el layout'), findsOneWidget);
  });
}
