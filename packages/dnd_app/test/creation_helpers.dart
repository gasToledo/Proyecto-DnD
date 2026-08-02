import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Elige una opción del wizard (especie, clase, trasfondo) por su nombre.
///
/// Desde que los catálogos salen alfabéticos, la opción buscada rara vez es de
/// las primeras: en el layout ancho la columna de opciones es un `ListView`
/// perezoso, así que un `find.text` a secas devuelve cero widgets porque la
/// tarjeta todavía no se construyó. Hay que scrollear la columna, no la página.
Future<void> tapOption(WidgetTester tester, String label) async {
  final target = find.text(label);
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      140,
      // La columna de opciones es el único ListView envuelto en Scrollbar del
      // paso; el scroll de la página es otro y no revela nada de esta lista.
      scrollable: find
          .descendant(
            of: find.byType(Scrollbar),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(target.first);
  await tester.pumpAndSettle();
  await tester.tap(target.first);
  await tester.pumpAndSettle();
}

/// Primera especie en orden alfabético: la que siempre está a la vista sin
/// scrollear. Las pruebas que solo miden la lista (alto, layout) se anclan acá
/// en vez de en una especie concreta, que puede quedar fuera del viewport.
const primeraEspecie = 'Aasimar';

/// Marca un arma del checklist de maestrías.
///
/// Filtra con el buscador del propio checklist en vez de scrollear: con el
/// catálogo alfabético el arma buscada puede caer lejos, y el paso de Clase
/// tiene dos listas con scroll propio (las clases y este checklist), así que
/// scrollear "la del paso" es ambiguo. Buscar es además lo que haría el
/// usuario.
Future<void> checkWeapon(WidgetTester tester, String name) async {
  // Por tipo y no por su hint: el hint desaparece apenas se escribe, así que
  // un finder por texto dejaría de resolver para limpiar la búsqueda después.
  final search = find.byType(TextField).first;
  await tester.enterText(search, name);
  await tester.pumpAndSettle();

  final tile = find.widgetWithText(CheckboxListTile, name);
  await tester.ensureVisible(tile.first);
  await tester.pumpAndSettle();
  await tester.tap(tile.first);
  await tester.pumpAndSettle();

  // Se limpia para que la próxima búsqueda parta del catálogo entero.
  await tester.enterText(search, '');
  await tester.pumpAndSettle();
}
