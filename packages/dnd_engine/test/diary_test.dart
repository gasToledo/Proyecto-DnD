import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Una ficha mínima en el esquema 22, el anterior al Diario.
Map<String, dynamic> fichaConNotas(String notas) => {
      'schemaVersion': 22,
      'id': 'mirna',
      'name': 'Mirna',
      'raceId': 'human',
      'classId': 'druid',
      'backgroundId': 'hermit',
      'assignedScores': {for (final a in Ability.values) a.name: 12},
      'notes': notas,
    };

void main() {
  group('Diario', () {
    test('la nota vieja se convierte en la primera entrada', () {
      final c = Character.fromJson(
        fichaConNotas('Le debe un favor a Vex.'),
      );

      expect(c.diary, hasLength(1));
      expect(c.diary.single.kind, DiaryEntryKind.text);
      expect(c.diary.single.title, 'Nota');
      expect(c.diary.single.body, 'Le debe un favor a Vex.');
    });

    // Ascenderla a trasfondo pondría en la sección más visible de la ficha un
    // texto que pudo haberse escrito para otra cosa.
    test('la nota vieja no se vuelca al trasfondo', () {
      final c = Character.fromJson(fichaConNotas('Recordar: pociones.'));

      expect(c.background, isEmpty);
    });

    test('una ficha sin notas no estrena ninguna entrada', () {
      final c = Character.fromJson(fichaConNotas('   '));

      expect(c.diary, isEmpty);
      expect(c.background, isEmpty);
    });

    // La ficha vieja no guardaba fechas y la migración no se las inventa: una
    // fecha de hoy diría que la nota se escribió el día de la actualización.
    test('la entrada migrada no trae fechas', () {
      final c = Character.fromJson(fichaConNotas('Algo'));

      expect(c.diary.single.createdAt, isNull);
      expect(c.diary.single.updatedAt, isNull);
    });

    test('migrar no modifica el mapa de entrada', () {
      final source = fichaConNotas('Algo');

      Character.migrateJson(source);

      expect(source['notes'], 'Algo');
      expect(source.containsKey('diary'), isFalse);
    });

    test('el orden de las entradas es el que se guardó, no el de las fechas',
        () {
      final viejo = DateTime.utc(2026, 1, 1);
      final nuevo = DateTime.utc(2026, 9, 1);
      final c = _personaje(
        diary: [
          DiaryEntry(entryId: 'b', title: 'Nueva', createdAt: nuevo),
          DiaryEntry(entryId: 'a', title: 'Vieja', createdAt: viejo),
        ],
      );

      final vuelta = Character.fromJson(c.toJson());

      expect([for (final e in vuelta.diary) e.title], ['Nueva', 'Vieja']);
    });

    test('la ida y vuelta por JSON conserva los tres tipos', () {
      final c = _personaje(
        background: '# La hija del pantano\n\nLlegó antes de hablar.',
        diary: [
          DiaryEntry(
            entryId: 'a',
            title: 'Por qué no vuelve',
            body: 'Aguasprofundas la conoció con otro nombre.',
            createdAt: DateTime.utc(2026, 2, 28),
            updatedAt: DateTime.utc(2026, 3, 2),
          ),
          const DiaryEntry(
            entryId: 'b',
            kind: DiaryEntryKind.image,
            title: 'Hoja de personaje',
            imageKey: 'mirna/boceto.png',
          ),
          const DiaryEntry(
            entryId: 'c',
            kind: DiaryEntryKind.link,
            title: 'La playlist',
            body: 'https://example.com/pantano',
          ),
        ],
      );

      final vuelta = Character.fromJson(c.toJson());

      expect(vuelta.background, c.background);
      expect(vuelta.diary, hasLength(3));
      expect(
          vuelta.diary[0].body, 'Aguasprofundas la conoció con otro nombre.');
      expect(vuelta.diary[0].createdAt, DateTime.utc(2026, 2, 28));
      expect(vuelta.diary[0].updatedAt, DateTime.utc(2026, 3, 2));
      expect(vuelta.diary[1].kind, DiaryEntryKind.image);
      expect(vuelta.diary[1].imageKey, 'mirna/boceto.png');
      expect(vuelta.diary[2].kind, DiaryEntryKind.link);
      expect(vuelta.diary[2].body, 'https://example.com/pantano');
    });

    // Un documento escrito por una versión más nueva puede traer un tipo que
    // acá todavía no existe; perder la entrada entera sería peor que leerla
    // como texto, que deja título y cuerpo a la vista.
    test('un tipo desconocido se lee como texto', () {
      final entrada = DiaryEntry.fromJson({
        'entryId': 'x',
        'kind': 'video',
        'title': 'Algo',
      });

      expect(entrada.kind, DiaryEntryKind.text);
    });

    test('una fecha ilegible no cuesta la entrada', () {
      final entrada = DiaryEntry.fromJson({
        'entryId': 'x',
        'title': 'Algo',
        'createdAt': 'ayer a la tarde',
      });

      expect(entrada.title, 'Algo');
      expect(entrada.createdAt, isNull);
    });
  });
}

Character _personaje(
        {String background = '', List<DiaryEntry> diary = const []}) =>
    Character(
      id: 'mirna',
      name: 'Mirna',
      raceId: 'human',
      classId: 'druid',
      backgroundId: 'hermit',
      assignedScores: {for (final a in Ability.values) a: 12},
      background: background,
      diary: diary,
    );
