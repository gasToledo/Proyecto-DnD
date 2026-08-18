import '../api/api_models.dart';
import '../theme/app_widgets.dart';

/// Un aviso ya traducido a lo que se muestra en pantalla.
class UserEventMessage {
  final String text;
  final AppMessageTone tone;

  const UserEventMessage(this.text, this.tone);
}

/// Catálogo de los mensajes de aviso.
///
/// El servidor guarda **qué pasó** (`kind` más los datos del `payload`) y este
/// archivo decide **cómo se dice**. Así corregir una redacción es cambiar una
/// línea acá, y no migrar lo que ya está guardado en la base.
///
/// Un `kind` desconocido devuelve `null` en vez de romper: si el servidor se
/// actualiza antes que la pestaña abierta del navegador, el aviso se ignora en
/// silencio, que es preferible a una pantalla con error.
UserEventMessage? messageForEvent(UserEvent event) {
  final character = _quoted(event.payload['characterName']);
  final campaign = _quoted(event.payload['campaignName']);

  return switch (event.kind) {
    'character_linked' => UserEventMessage(
      '$character se sumó a la campaña $campaign.',
      AppMessageTone.success,
    ),
    'character_unlinked_by_dm' => UserEventMessage(
      '$character ya no forma parte de $campaign.',
      AppMessageTone.info,
    ),
    'character_unlinked_by_owner' => UserEventMessage(
      '$character salió de tu campaña $campaign.',
      AppMessageTone.info,
    ),
    'character_deleted_by_owner' => UserEventMessage(
      '$character ya no está disponible en $campaign.',
      AppMessageTone.info,
    ),
    _ => null,
  };
}

/// Nombre entre comillas angulares, o un genérico si el aviso vino sin él
/// (por ejemplo si lo borraron entre que pasó y que se leyó).
String _quoted(Object? value) {
  final text = value is String ? value.trim() : '';
  return text.isEmpty ? 'Un personaje' : '«$text»';
}
