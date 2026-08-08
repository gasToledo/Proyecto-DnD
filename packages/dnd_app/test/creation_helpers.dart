import 'package:dnd_app/creation/creation_wizard.dart';
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
  final column = find.byKey(optionColumnKey);

  // En modo angosto las opciones son un `Wrap` que construye todo, así que solo
  // hace falta scrollear cuando existe la columna del modo dividido y la
  // tarjeta todavía no está construida.
  if (target.evaluate().isEmpty && column.evaluate().isNotEmpty) {
    // Se arrastra sobre la lista misma en vez de buscarle el `Scrollable`
    // adentro: ese finder depende de la estructura interna del ListView y se
    // vacía según cómo esté armado el paso.
    await tester.dragUntilVisible(target, column, const Offset(0, -140));
    await tester.pumpAndSettle();
  }

  expect(
    target,
    findsWidgets,
    reason: 'no apareció la opción "$label" para tocar',
  );
  await tester.ensureVisible(target.first);
  await tester.pumpAndSettle();
  await tester.tap(target.first);
  await tester.pumpAndSettle();
}

/// Primera especie en orden alfabético: la que siempre está a la vista sin
/// scrollear. Las pruebas que solo miden la lista (alto, layout) se anclan acá
/// en vez de en una especie concreta, que puede quedar fuera del viewport.
const primeraEspecie = 'Aasimar';

/// Elige el tamaño de la especie cuando ofrece Mediano o Pequeño.
///
/// El paso de Raza no deja avanzar sin esto, así que cualquier prueba que
/// navegue más allá de la primera pantalla con una de esas especies tiene que
/// pasar por acá. Con una especie de tamaño fijo no hace nada.
Future<void> pickSize(WidgetTester tester, [String size = 'Mediano']) async {
  final option = find.text(size);
  if (option.evaluate().isEmpty) return;
  await tester.ensureVisible(option.last);
  await tester.pumpAndSettle();
  await tester.tap(option.last);
  await tester.pumpAndSettle();
}

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

/// Elige los dos idiomas del origen, y uno más por cada cupo que declare un
/// rasgo (la Jerga de Ladrones del Pícaro).
///
/// El paso de Aptitudes no deja avanzar sin ellos, así que toda prueba que
/// navegue hasta Equipo o más allá tiene que pasar por acá.
///
/// Se toman los chips por su etiqueta y no por posición: varios idiomas
/// comparten nombre con una especie ("Elfo", "Enano"), pero en este paso las
/// tarjetas de especie no están, así que no hay ambigüedad. Se usa `.first`
/// porque el cupo de un rasgo ofrece las mismas etiquetas más abajo.
Future<void> pickLanguages(WidgetTester tester) async {
  Future<void> tapChip(String label) async {
    final chip = find.widgetWithText(FilterChip, label);
    if (chip.evaluate().isEmpty) return;
    await tester.ensureVisible(chip.first);
    await tester.pumpAndSettle();
    await tester.tap(chip.first);
    await tester.pumpAndSettle();
  }

  await tapChip('Goblin');
  await tapChip('Orco');

  // Un cupo de rasgo deja su etiqueta libre después de llenar el origen: se
  // toma la primera que quede sin usar.
  for (final extra in ['Gigante', 'Dracónico', 'Gnomo']) {
    if (find.textContaining('/ 1 elegidos').evaluate().isEmpty) break;
    await tapChip(extra);
  }
}
