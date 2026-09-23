import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  group('Npc — round-trip', () {
    test('un PNJ sin estadísticas conserva sus datos narrativos', () {
      final npc = Npc(
        id: 'npc-1',
        name: 'Toblen',
        sheetKind: NpcSheetKind.none,
        speech: 'Habla con la boca llena.',
        appearance: 'Delantal manchado',
        background: 'Dueño de la posada.',
        tags: const ['Phandalin'],
        notes: [
          NpcNote(id: 'n1', date: DateTime.utc(2026, 9, 14), text: 'Debe oro'),
        ],
        portraitPaths: const ['npc-1/a.png'],
        portraitPrompts: const {'npc-1/a.png': 'retrato'},
      );

      final r = Npc.fromJson(npc.toJson());

      expect(r.name, 'Toblen');
      expect(r.sheetKind, NpcSheetKind.none);
      expect(r.hasStats, isFalse);
      expect(r.speech, npc.speech);
      expect(r.appearance, npc.appearance);
      expect(r.background, npc.background);
      expect(r.tags, ['Phandalin']);
      expect(r.notes.single.text, 'Debe oro');
      expect(r.notes.single.date, DateTime.utc(2026, 9, 14));
      expect(r.portraitPaths, ['npc-1/a.png']);
      expect(r.portraitPrompts, {'npc-1/a.png': 'retrato'});
    });

    test('un PNJ con bloque guarda una copia completa de la criatura', () {
      final knight = repo.creature('knight')!;
      final npc = Npc(
        id: 'npc-2',
        name: 'Capitana Ilse Varn',
        sheetKind: NpcSheetKind.block,
        block: knight,
        baseCreatureId: knight.id,
        baseCreatureName: knight.name,
      );

      final r = Npc.fromJson(npc.toJson());

      expect(r.hasStats, isTrue);
      expect(r.baseCreatureName, knight.name);
      expect(r.block!.hp, knight.hp);
      expect(r.block!.ac, knight.ac);
      expect(r.block!.actions.length, knight.actions.length);
    });

    test('un PNJ con ficha de personaje guarda el id de su ficha', () {
      final npc = Npc(
        id: 'npc-3',
        name: 'Maerith',
        sheetKind: NpcSheetKind.character,
        characterId: 'npc-3-ficha',
      );

      final r = Npc.fromJson(npc.toJson());

      expect(r.sheetKind, NpcSheetKind.character);
      expect(r.characterId, 'npc-3-ficha');
      expect(r.block, isNull);
    });

    test('editar el bloque no toca la criatura de origen', () {
      final knight = repo.creature('knight')!;
      final npc = Npc(
        id: 'npc-2',
        name: 'Ilse',
        sheetKind: NpcSheetKind.block,
        block: knight,
      );
      final edited = npc.copyWith(
        block: Creature.fromJson({...knight.toJson(), 'hp': '60'}),
      );

      expect(edited.block!.hp, '60');
      expect(repo.creature('knight')!.hp, knight.hp);
      expect(edited.sheetKind, NpcSheetKind.block);
    });
  });

  group('Npc — tags', () {
    test('no quedan dos tags que solo difieran en mayúsculas', () {
      final npc = Npc(
        id: 'a',
        name: 'A',
        sheetKind: NpcSheetKind.none,
        tags: const ['Waterdeep', 'waterdeep', ' ', 'Enemigos '],
      );

      expect(npc.tags, ['Waterdeep', 'Enemigos']);
      expect(npc.hasTag('WATERDEEP'), isTrue);
    });
  });

  group('Npc — versionado', () {
    Map<String, dynamic> doc() =>
        Npc(id: 'a', name: 'A', sheetKind: NpcSheetKind.none).toJson();

    test('el documento estampa la versión actual', () {
      expect(doc()['schemaVersion'], Npc.currentSchemaVersion);
    });

    test('migrar no modifica el mapa de entrada', () {
      final source = doc();
      final copy = Map<String, dynamic>.from(source);
      Npc.migrateJson(source);
      expect(source, copy);
    });

    test('rechaza una versión futura', () {
      expect(
        () => Npc.fromJson({...doc(), 'schemaVersion': 99}),
        throwsA(isA<UnsupportedDataVersionException>()),
      );
    });

    test('un tipo desconocido cae en sin estadísticas', () {
      final r = Npc.fromJson({...doc(), 'sheetKind': 'algo-nuevo'});
      expect(r.sheetKind, NpcSheetKind.none);
    });
  });

  group('NpcStatus', () {
    test('un estado desconocido cae en vivo', () {
      expect(NpcStatus.fromJson('zombi'), NpcStatus.alive);
      expect(NpcStatus.fromJson('dead'), NpcStatus.dead);
    });
  });
}
