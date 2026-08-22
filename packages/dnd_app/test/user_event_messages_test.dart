import 'package:dnd_app/api/api_models.dart';
import 'package:dnd_app/theme/app_widgets.dart';
import 'package:dnd_app/ui/user_event_messages.dart';
import 'package:flutter_test/flutter_test.dart';

UserEvent event(
  String kind, {
  String character = 'Thorin',
  String campaign = 'La Tumba',
}) => UserEvent(
  id: 'e1',
  kind: kind,
  payload: {'characterName': character, 'campaignName': campaign},
);

void main() {
  group('messageForEvent', () {
    test('nombra al personaje y a la campaña en cada aviso', () {
      for (final kind in [
        'character_linked',
        'character_unlinked_by_dm',
        'character_unlinked_by_owner',
        'character_deleted_by_owner',
      ]) {
        final message = messageForEvent(event(kind));

        expect(message, isNotNull, reason: kind);
        expect(message!.text, contains('Thorin'), reason: kind);
        expect(message.text, contains('La Tumba'), reason: kind);
      }
    });

    test('sumarse a una campaña es una buena noticia', () {
      expect(
        messageForEvent(event('character_linked'))!.tone,
        AppMessageTone.success,
      );
    });

    // Salir de una campaña no es un error: pasa a propósito y no hay nada que
    // arreglar. Pintarlo de rojo asustaría sin motivo.
    test('los avisos de baja son informativos, no errores', () {
      for (final kind in [
        'character_unlinked_by_dm',
        'character_unlinked_by_owner',
        'character_deleted_by_owner',
      ]) {
        expect(
          messageForEvent(event(kind))!.tone,
          AppMessageTone.info,
          reason: kind,
        );
      }
    });

    // Si el servidor se actualiza antes que la pestaña abierta del navegador,
    // el aviso nuevo no puede tumbar la pantalla.
    test('un kind desconocido se ignora en vez de romper', () {
      expect(messageForEvent(event('algo_que_todavia_no_existe')), isNull);
    });

    test('un aviso sin nombres igual dice algo legible', () {
      final message = messageForEvent(
        const UserEvent(id: 'e1', kind: 'character_linked', payload: {}),
      );

      expect(message, isNotNull);
      expect(message!.text, contains('Un personaje'));
      expect(message.text, isNot(contains('null')));
    });
  });

  group('messageForEvent — capítulos', () {
    UserEvent chapterEvent({
      bool grantsLevel = false,
      Object? grantsGold,
      Object? grantsItems,
    }) => UserEvent(
      id: 'e1',
      kind: 'chapter_completed',
      payload: {
        'characterName': 'Thorin',
        'campaignName': 'La Tumba',
        'chapterName': 'La Cripta',
        'grantsLevel': grantsLevel,
        'grantsGold': ?grantsGold,
        'grantsItems': ?grantsItems,
      },
    );

    test('nombra al personaje, al capítulo y a la campaña', () {
      final message = messageForEvent(chapterEvent())!;

      expect(message.text, contains('Thorin'));
      expect(message.text, contains('La Cripta'));
      expect(message.text, contains('La Tumba'));
    });

    // Cerrar un capítulo sin recompensa es una noticia, no un logro.
    test('sin nivel es informativo y no menciona subir', () {
      final message = messageForEvent(chapterEvent())!;

      expect(message.tone, AppMessageTone.info);
      expect(message.text, isNot(contains('subir de nivel')));
    });

    // Es lo único accionable que puede traer un aviso, así que se destaca.
    test('con nivel lo dice y sube de tono', () {
      final message = messageForEvent(chapterEvent(grantsLevel: true))!;

      expect(message.text, contains('Podés subir de nivel.'));
      expect(message.tone, AppMessageTone.success);
    });

    test('el botín se dice entero y sube de tono', () {
      final message = messageForEvent(
        chapterEvent(
          grantsGold: 250,
          grantsItems: ['Espada larga +1', 'Poción de curación'],
        ),
      )!;

      expect(
        message.text,
        contains('Se lleva 250 po, Espada larga +1 y Poción de curación.'),
      );
      expect(message.tone, AppMessageTone.success);
    });

    // El aviso lo dice; la ficha la escribe el jugador. Si alguna vez esta
    // redacción sugiere que la app lo aplicó sola, está mintiendo.
    test('el botín se anuncia sin prometer que ya está aplicado', () {
      final message = messageForEvent(chapterEvent(grantsGold: 250))!;

      expect(message.text, contains('Se lleva 250 po.'));
      expect(message.text, isNot(contains('sumó')));
      expect(message.text, isNot(contains('agregó')));
    });

    test('sin botín no aparece ninguna línea de recompensa', () {
      final message = messageForEvent(chapterEvent())!;

      expect(message.text, isNot(contains('Se lleva')));
    });

    // Un aviso guardado antes de que existiera el botín, o uno de un servidor
    // más nuevo con otra forma: se lee como que no hubo, y no rompe la bandeja.
    test('un botín ausente o con otra forma se lee como que no hubo', () {
      for (final event in [
        chapterEvent(),
        chapterEvent(grantsGold: '250', grantsItems: 'Espada'),
        chapterEvent(grantsGold: 0, grantsItems: const []),
      ]) {
        final message = messageForEvent(event)!;
        expect(message.text, isNot(contains('Se lleva')));
        expect(message.text, isNot(contains('null')));
      }
    });

    test('un aviso de capítulo sin nombres igual dice algo legible', () {
      final message = messageForEvent(
        const UserEvent(id: 'e1', kind: 'chapter_completed', payload: {}),
      );

      expect(message, isNotNull);
      expect(message!.text, contains('Un capítulo'));
      expect(message.text, isNot(contains('null')));
    });
  });

  group('Inspiración Heroica concedida por el DM', () {
    test('nombra al personaje, la campaña y dice que la marque él', () {
      final message = messageForEvent(
        const UserEvent(
          id: 'e9',
          kind: 'heroic_inspiration_granted',
          payload: {'characterName': 'Sagan', 'campaignName': 'La Tumba'},
        ),
      )!;

      expect(message.text, contains('Sagan'));
      expect(message.text, contains('La Tumba'));
      // Lo importante del mensaje: el DM no se la marcó en la ficha.
      expect(message.text, contains('Marcala'));
      expect(message.tone, AppMessageTone.success);
    });

    test('sin nombres igual dice algo legible', () {
      final message = messageForEvent(
        const UserEvent(
          id: 'e10',
          kind: 'heroic_inspiration_granted',
          payload: {},
        ),
      );

      expect(message, isNotNull);
      expect(message!.text, isNot(contains('null')));
    });
  });
}
