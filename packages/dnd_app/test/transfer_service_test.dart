import 'dart:convert';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/data/transfer_service.dart';
import 'package:flutter_test/flutter_test.dart';

// La importación del respaldo ZIP principal ahora la valida y aplica el
// servidor (`POST /api/import`, capacidad `account-data-import`): este
// cliente ya no decodifica ese formato, así que `parseImport`/id-collision
// en el cliente no existen más. Lo que queda es el paquete liviano y
// aparte de "solo homebrew" (`dnd_homebrew`), que sigue siendo lógica pura
// del lado del cliente.
void main() {
  group('parseHomebrewImport', () {
    test('lee un pack de homebrew y devuelve listas por tipo', () {
      final text = jsonEncode({
        'type': 'dnd_homebrew',
        'formatVersion': 1,
        'content': {
          'weapons': [
            {
              'id': 'hb-sword',
              'name': 'Espada rúnica',
              'source': 'homebrew',
              'category': 'martial',
              'damageDice': '1d8',
              'damageType': 'cortante',
            },
          ],
          'feats': [
            {'id': 'hb-feat', 'name': 'Dote casera', 'source': 'homebrew'},
          ],
        },
      });
      final parsed = TransferService.parseHomebrewImport(text);
      expect(parsed['weapons'], hasLength(1));
      expect(parsed['feats'], hasLength(1));
      // Los tipos ausentes vienen como listas vacías, no null.
      expect(parsed['spells'], isEmpty);
      // Round-trip a modelo del engine.
      expect(Weapon.fromJson(parsed['weapons']!.first).name, 'Espada rúnica');
    });

    test('rechaza un archivo que no es homebrew', () {
      final text = jsonEncode({'type': 'dnd_character', 'character': {}});
      expect(
        () => TransferService.parseHomebrewImport(text),
        throwsFormatException,
      );
    });

    test('rechaza un pack homebrew de versión futura', () {
      final text = jsonEncode({
        'type': 'dnd_homebrew',
        'formatVersion': TransferService.formatVersion + 1,
        'content': const <String, dynamic>{},
      });

      expect(
        () => TransferService.parseHomebrewImport(text),
        throwsA(isA<UnsupportedDataVersionException>()),
      );
    });
  });
}
