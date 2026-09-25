import 'package:dnd_app/theme/app_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Llena los trucos y los conjuros de clase que faltan desde el editor real
/// de la subida: abre «Preparar conjuros», toca opciones libres de cada cupo
/// hasta completarlo y guarda.
///
/// Existe porque la subida ya no se confirma con cupo nuevo sin llenar, y los
/// tests que prueban otra cosa (un estilo de combate, una invocación) tienen
/// que pasar por ese paso igual que un jugador.
///
/// El editor arma su lista a medida que se desplaza, así que no se puede
/// contar con que ambos cupos estén construidos a la vez: cada vuelta busca
/// entre lo que hay en pantalla y, si no queda nada pendiente ahí, baja.
Future<void> completarConjurosDeClase(WidgetTester tester) async {
  final abrir = find.text('Preparar conjuros');
  if (abrir.evaluate().isEmpty) return;
  await tester.ensureVisible(abrir);
  await tester.pumpAndSettle();
  await tester.tap(abrir);
  await tester.pumpAndSettle();

  Finder? siguiente() {
    for (final e in find.byType(CappedChipSelect).evaluate()) {
      final select = e.widget as CappedChipSelect;
      if (select.selected.length >= select.max) continue;
      final chips = find.descendant(
        of: find.byWidget(select),
        matching: find.byType(FilterChip),
      );
      for (final c in chips.evaluate()) {
        final chip = c.widget as FilterChip;
        if (!chip.selected && chip.onSelected != null) {
          return find.byWidget(chip);
        }
      }
    }
    return null;
  }

  var desplazamientos = 0;
  for (var vuelta = 0; vuelta < 400; vuelta++) {
    final chip = siguiente();
    if (chip == null) {
      if (desplazamientos++ > 20) break;
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await tester.pumpAndSettle();
      continue;
    }
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Guardar'));
  await tester.pumpAndSettle();
}

/// Avanza con Continuar hasta que aparezca [confirmar], completando en el
/// camino los conjuros de clase que falten. Acotado: un paso que no se
/// destraba falla el test en vez de colgarlo.
Future<void> avanzarHastaConfirmar(
  WidgetTester tester,
  String confirmar, {
  int maxPasos = 12,
}) async {
  for (var i = 0; i < maxPasos; i++) {
    if (find.text(confirmar).evaluate().isNotEmpty) return;
    if (find.textContaining('Te falta elegir').evaluate().isNotEmpty) {
      await completarConjurosDeClase(tester);
    }
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
  }
  expect(find.text(confirmar), findsOneWidget);
}
