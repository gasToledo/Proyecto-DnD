import 'package:dnd_engine/dnd_engine.dart';

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
    // El DM no le marcó nada en la ficha: el mensaje tiene que decirlo, o el
    // jugador espera encontrar la estrella ya prendida.
    'heroic_inspiration_granted' => UserEventMessage(
      'El DM te concedió Inspiración Heroica en $campaign. '
      'Marcala en la ficha de $character.',
      AppMessageTone.success,
    ),
    // Los datos propios de este aviso se leen acá adentro y no arriba: los
    // otros cinco `kind` no los traen.
    'chapter_completed' => _chapterCompleted(event, character, campaign),
    _ => null,
  };
}

/// Cierre de un capítulo. Cuando trae nivel o botín, el aviso lo dice y sube
/// de tono: es lo único accionable que puede traer.
///
/// Y traerlo es todo lo que hace. La app **no sube a nadie de nivel ni le
/// suma nada a la bolsa** — el asistente de subida y el inventario son del
/// jugador, y esto es la nota que le deja el DM para que los use.
UserEventMessage _chapterCompleted(
  UserEvent event,
  String character,
  String campaign,
) {
  final chapter = _quotedOr(event.payload['chapterName'], 'Un capítulo');
  final grantsLevel = event.payload['grantsLevel'] == true;
  // Un aviso viejo no trae ninguno de los dos, y uno de un servidor más nuevo
  // podría traerlos con otra forma. Se leen con `switch` y no con `as` porque
  // acá un cast que falle voltea la bandeja entera: lo que no sea lo esperado
  // se lee como que no hubo botín.
  final rewards = describeRewards(
    switch (event.payload['grantsGold']) {
      final int gold when gold > 0 => gold,
      _ => 0,
    },
    switch (event.payload['grantsItems']) {
      final List items => [
        for (final item in items)
          if (item is String) item,
      ],
      _ => const <String>[],
    },
  );

  final lines = [
    '$character terminó el capítulo $chapter en $campaign.',
    if (rewards.isNotEmpty) 'Se lleva $rewards.',
    if (grantsLevel) 'Podés subir de nivel.',
  ];
  return UserEventMessage(
    lines.join(' '),
    lines.length > 1 ? AppMessageTone.success : AppMessageTone.info,
  );
}

/// Nombre entre comillas angulares, o un genérico si el aviso vino sin él
/// (por ejemplo si lo borraron entre que pasó y que se leyó).
String _quoted(Object? value) => _quotedOr(value, 'Un personaje');

String _quotedOr(Object? value, String fallback) {
  final text = value is String ? value.trim() : '';
  return text.isEmpty ? fallback : '«$text»';
}
