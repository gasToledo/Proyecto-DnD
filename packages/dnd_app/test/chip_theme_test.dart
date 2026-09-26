import 'package:dnd_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Elegir un chip no puede cambiarle el ancho. El tilde de Material lo
/// ensanchaba, y en un `Wrap` la fila se reacomodaba: al elegir un Estilo de
/// Combate o un idioma, lo de abajo se corría y el toque siguiente caía en
/// otra opción.
void main() {
  for (final (nombre, theme) in [
    ('oscuro', AppTheme.dark),
    ('claro', AppTheme.light),
  ]) {
    testWidgets('elegir un chip no le cambia el ancho (tema $nombre)', (
      tester,
    ) async {
      var choice = false;
      var filter = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Defensa'),
                    selected: choice,
                    onSelected: (v) => setState(() => choice = v),
                  ),
                  FilterChip(
                    label: const Text('Enano'),
                    selected: filter,
                    onSelected: (v) => setState(() => filter = v),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final defensa = find.widgetWithText(ChoiceChip, 'Defensa');
      final enano = find.widgetWithText(FilterChip, 'Enano');
      final antes = (tester.getSize(defensa), tester.getRect(enano));

      await tester.tap(defensa);
      await tester.tap(enano);
      await tester.pumpAndSettle();

      expect(choice, isTrue);
      expect(filter, isTrue);
      expect(tester.getSize(defensa), antes.$1);
      // El vecino tampoco se corre: es lo que hacía errar el toque siguiente.
      expect(tester.getRect(enano), antes.$2);
      expect(tester.takeException(), isNull);
    });
  }
}
