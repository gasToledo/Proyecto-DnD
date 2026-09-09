import 'package:dnd_app/theme/app_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// La celda del pie de un [AppDialog] con ese rótulo.
///
/// Antes del molde de diálogo alcanzaba con `widgetWithText(FilledButton, …)`:
/// el tipo del botón distinguía la acción del diálogo de la de la pantalla que
/// quedaba abajo. Ahora las dos son texto, así que lo que separa es estar
/// adentro del diálogo — y varios rótulos se repiten a propósito («Cerrar
/// capítulo» abre el diálogo y también lo confirma).
/// Busca la celda y no el texto suelto porque varios diálogos repiten su
/// título en el verbo de la acción («Borrar nota» es las dos cosas).
Finder dialogAction(String label) => find.descendant(
  of: find.byType(AppDialog),
  matching: find.widgetWithText(InkWell, label),
);
