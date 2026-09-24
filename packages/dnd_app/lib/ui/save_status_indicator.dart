import 'package:flutter/material.dart';

import '../data/characters_controller.dart';
import '../theme/app_theme.dart';

/// El estado del guardado automático, en una placa.
///
/// Se escucha a sí mismo al controlador: así se puede poner en cualquier
/// pantalla sin que esa pantalla tenga que suscribirse ni reconstruirse
/// entera por un cambio que solo afecta a esta placa.
///
/// Vive acá y no en el dashboard porque la ficha lo necesita igual, y es
/// justamente ahí donde más se escribe: la ficha guarda sola, sin botón, y
/// sin este cartel no hay forma de saber si lo que se tipeó llegó.
class SaveStatusIndicator extends StatelessWidget {
  final CharactersController controller;

  /// Sin la palabra al lado del ícono. Para la barra de una ventana angosta,
  /// donde «Guardando…» se come el título.
  final bool compact;

  const SaveStatusIndicator({
    super.key,
    required this.controller,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _placa(context, controller.saveState),
    );
  }

  Widget _placa(BuildContext context, CharacterSaveState state) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final (icon, label, color) = switch (state) {
      CharacterSaveState.saving => (Icons.sync, 'Guardando…', pal.gold),
      CharacterSaveState.error => (
        Icons.error_outline,
        'No se guardó',
        scheme.error,
      ),
      CharacterSaveState.saved => (
        Icons.cloud_done_outlined,
        'Guardado',
        scheme.onSurfaceVariant,
      ),
    };

    return Semantics(
      label: 'Estado del guardado: $label',
      child: Tooltip(
        // En compacto el ícono queda solo, y tres íconos parecidos no se
        // distinguen de memoria.
        message: label,
        child: AnimatedSwitcher(
          duration: context.motion(const Duration(milliseconds: 180)),
          child: Container(
            key: ValueKey(state),
            height: 40,
            padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 11),
            decoration: BoxDecoration(
              color: pal.plaque,
              border: Border.all(
                color: state == CharacterSaveState.error
                    ? scheme.error
                    : pal.hairline,
              ),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: color),
                if (!compact) ...[
                  const SizedBox(width: 7),
                  Text(label, style: TextStyle(fontSize: 12, color: color)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
