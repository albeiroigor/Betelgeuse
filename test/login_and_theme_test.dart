import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:betelgeuse/core/theme/app_theme.dart';
import 'package:betelgeuse/features/login/login_page.dart';

void main() {
  test('hay cinco temas y todos tienen paleta', () {
    expect(AppThemes.all, hasLength(5));
    for (final theme in AppThemes.all) {
      expect(theme.name, isNotEmpty);
      expect(theme.theme.useMaterial3, isTrue);
    }
    expect(AppThemes.all.where((t) => t.isDark), isNotEmpty);
    expect(AppThemes.all.where((t) => !t.isDark), isNotEmpty);
  });

  test('ColumnConfig hace round-trip de nombre y color', () {
    final config = ColumnConfig(
      optionId: 'todo',
      displayName: 'Haciendo',
      color: const Color(0xFF22D3EE),
    );
    final restored = ColumnConfig.fromJson(config.optionId, config.toJson());
    expect(restored.displayName, 'Haciendo');
    expect(restored.color, const Color(0xFF22D3EE));
  });

  testWidgets('el login renderiza sin excepciones', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Login(onToken: (_) async {})));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Betelgeuse'), findsWidgets);
    expect(find.text('Conectar con GitHub'), findsOneWidget);
  });
}
