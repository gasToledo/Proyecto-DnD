import 'package:dnd_app/api/api_client.dart';
import 'package:dnd_app/data/homebrew_store.dart';
import 'package:dnd_app/homebrew/homebrew_screen.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
  });

  testWidgets(
    'las seis categorías y el formulario de armas siguen accesibles',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: HomebrewScreen(repo: repo, store: HomebrewStore(ApiClient())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Contenido homebrew'), findsOneWidget);
      expect(find.text('Agregar arma'), findsOneWidget);

      const categories = {
        'Armaduras': 'Agregar armadura',
        'Dotes': 'Agregar dote',
        'Razas': 'Agregar raza',
        'Trasfondos': 'Agregar trasfondo',
        'Conjuros': 'Agregar conjuro',
      };
      for (final entry in categories.entries) {
        await tester.tap(find.text(entry.key));
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      await tester.tap(find.text('Armas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar arma'));
      await tester.pumpAndSettle();

      expect(find.text('Arma'), findsOneWidget);
      expect(find.text('Nombre'), findsOneWidget);
      expect(find.text('Dado de daño (p.ej. 1d8)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
