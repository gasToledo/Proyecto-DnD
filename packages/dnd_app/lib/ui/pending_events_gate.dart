import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/api_models.dart';
import '../data/user_events_service.dart';
import '../theme/app_widgets.dart';
import 'user_event_messages.dart';

/// Pide los avisos pendientes de esta cuenta, los muestra uno detrás de otro
/// y los marca vistos. Se llama en un punto de entrada concreto (montar una
/// pantalla, terminar una acción), nunca en un timer propio — eso exigiría el
/// service worker y los permisos de notificación push que se descartaron a
/// propósito.
///
/// Esto es **tiempo real diferido, no en vivo**, y la distinción importa: los
/// avisos son una cola durable de "esto pasó mientras no mirabas" — se piden
/// al entrar a algún lado y se marcan vistos, uno por uno, para siempre. El
/// aviso de turno del combat tracker (`SheetScreen._pollTurn`, en
/// `sheet_screen.dart`) es distinto a propósito: es estado efímero de "esto
/// es verdad ahora mismo", así que **sí** usa su propio timer que se
/// reprograma solo, en vez de esta cola — si viajara por acá, una ronda vieja
/// dejaría "es tu turno" acumulados sin vencer nunca.
///
/// Un fallo al pedirlos se traga en silencio: no poder mostrar un aviso no es
/// motivo para interrumpir lo que la persona vino a hacer.
Future<void> checkPendingEvents(BuildContext context, ApiClient api) async {
  final service = UserEventsService(api);
  final List<UserEvent> pending;
  try {
    pending = await service.loadUnseen();
  } catch (_) {
    return;
  }

  var first = true;
  for (final event in pending) {
    if (!context.mounted) return;
    final message = messageForEvent(event);
    // Un `kind` que este cliente no conoce igual se marca visto: el servidor
    // puede ser más nuevo que la pestaña abierta, y dejarlo pendiente lo
    // volvería a traer para siempre.
    if (message != null) {
      // Uno detrás de otro: `showAppMessage` reemplaza el anterior, así que
      // sin la espera solo se vería el último.
      if (!first) await Future<void>.delayed(const Duration(seconds: 4));
      if (!context.mounted) return;
      showAppMessage(context, message.text, tone: message.tone);
      first = false;
    }
    try {
      await service.markSeen([event]);
    } catch (_) {
      // Se volverá a mostrar la próxima vez: preferible a perderlo.
    }
  }
}

/// Llama a [checkPendingEvents] apenas se monta [child].
///
/// Se envuelve en cada punto de entrada donde de verdad importa enterarse
/// pronto — el arranque de la app, entrar a Modo DM, abrir una ficha — y no
/// una sola vez en la raíz: navegar de vuelta a una pantalla ya montada no
/// vuelve a preguntar por sí sola.
class PendingEventsGate extends StatefulWidget {
  final ApiClient api;
  final Widget child;

  const PendingEventsGate({super.key, required this.api, required this.child});

  @override
  State<PendingEventsGate> createState() => _PendingEventsGateState();
}

class _PendingEventsGateState extends State<PendingEventsGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => checkPendingEvents(context, widget.api),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
