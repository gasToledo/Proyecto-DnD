import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Chapter', () {
    test('conserva sus campos en el round-trip', () {
      const c = Chapter(
        id: 'la-cripta',
        name: 'La Cripta',
        summary: 'Bajan al osario y algo los sigue.',
        state: ChapterState.active,
        grantsLevel: true,
      );

      final r = Chapter.fromJson(c.toJson());

      expect(r.id, 'la-cripta');
      expect(r.name, 'La Cripta');
      expect(r.summary, 'Bajan al osario y algo los sigue.');
      expect(r.state, ChapterState.active);
      expect(r.grantsLevel, isTrue);
    });

    test('un capítulo nuevo nace planificado, sin descripción ni nivel', () {
      const c = Chapter(id: 'x', name: 'Sin escribir todavía');

      expect(c.summary, '');
      expect(c.state, ChapterState.planned);
      expect(c.grantsLevel, isFalse);
    });

    // El documento lo manda el cliente: que le falte un campo opcional no
    // puede impedir que el capítulo cargue.
    test('un documento incompleto usa los valores por defecto', () {
      final r = Chapter.fromJson({'id': 'x'});

      expect(r.id, 'x');
      expect(r.name, '');
      expect(r.summary, '');
      expect(r.state, ChapterState.planned);
      expect(r.grantsLevel, isFalse);
    });

    test('un estado desconocido cae en planificado en vez de romper', () {
      final r = Chapter.fromJson({'id': 'x', 'state': 'abandonado'});

      expect(r.state, ChapterState.planned);
    });

    test('copyWith cambia lo pasado y conserva el resto', () {
      const c = Chapter(
        id: 'x',
        name: 'La Cripta',
        summary: 'Algo pasa',
        grantsLevel: true,
      );

      final r = c.copyWith(state: ChapterState.completed);

      expect(r.id, 'x');
      expect(r.name, 'La Cripta');
      expect(r.summary, 'Algo pasa');
      expect(r.state, ChapterState.completed);
      expect(r.grantsLevel, isTrue);
    });

    test('las etiquetas de estado son las que ve el DM', () {
      expect(ChapterState.planned.label, 'Próximamente');
      expect(ChapterState.active.label, 'En marcha');
      expect(ChapterState.completed.label, 'Completado');
    });

    // La etiqueta es para la pantalla; lo que viaja es el nombre inglés, que
    // es lo que el servidor compara.
    test('el estado serializa su nombre y no su etiqueta', () {
      expect(ChapterState.active.toJson(), 'active');
      expect(
        const Chapter(
          id: 'x',
          name: 'y',
          state: ChapterState.completed,
        ).toJson()['state'],
        'completed',
      );
    });

    test('el documento estampa la versión de esquema actual', () {
      const c = Chapter(id: 'x', name: 'y');

      expect(c.toJson()['schemaVersion'], Chapter.currentSchemaVersion);
    });

    test('un documento sin versión se trata como la 1', () {
      expect(Chapter.schemaVersionOf({'id': 'x'}), 1);
    });

    test('una versión que no es entero positivo es un error de formato', () {
      expect(
        () => Chapter.schemaVersionOf({'schemaVersion': 0}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => Chapter.schemaVersionOf({'schemaVersion': 'dos'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('rechaza una versión futura con un error comprensible', () {
      expect(
        () => Chapter.migrateJson({
          'schemaVersion': Chapter.currentSchemaVersion + 1,
          'id': 'x',
        }),
        throwsA(
          isA<UnsupportedDataVersionException>()
              .having((e) => e.dataType, 'tipo', 'capítulo')
              .having(
                (e) => e.found,
                'versión encontrada',
                Chapter.currentSchemaVersion + 1,
              )
              .having(
                (e) => e.supported,
                'versión soportada',
                Chapter.currentSchemaVersion,
              ),
        ),
      );
    });

    test('migrar no modifica el mapa de entrada', () {
      final source = <String, dynamic>{'id': 'x', 'name': 'y'};

      Chapter.migrateJson(source);

      expect(source, {'id': 'x', 'name': 'y'});
    });
  });
}
