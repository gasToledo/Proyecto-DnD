import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Campaign', () {
    test('conserva sus campos en el round-trip', () {
      const c = Campaign(
        id: 'la-tumba',
        name: 'La Tumba de la Aniquilación',
        premise: 'Alguien está robando almas en Chult.',
        state: CampaignState.paused,
      );

      final r = Campaign.fromJson(c.toJson());

      expect(r.id, 'la-tumba');
      expect(r.name, 'La Tumba de la Aniquilación');
      expect(r.premise, 'Alguien está robando almas en Chult.');
      expect(r.state, CampaignState.paused);
    });

    test('una campaña nueva nace en curso y sin premisa', () {
      const c = Campaign(id: 'x', name: 'Sin nombre todavía');

      expect(c.premise, '');
      expect(c.state, CampaignState.active);
    });

    // El documento lo manda el cliente: que le falte un campo opcional no
    // puede impedir que la campaña cargue.
    test('un documento incompleto usa los valores por defecto', () {
      final r = Campaign.fromJson({'id': 'x'});

      expect(r.id, 'x');
      expect(r.name, '');
      expect(r.premise, '');
      expect(r.state, CampaignState.active);
    });

    test('un estado desconocido cae en curso en vez de romper', () {
      final r = Campaign.fromJson({'id': 'x', 'state': 'incinerada'});

      expect(r.state, CampaignState.active);
    });

    test('copyWith cambia lo pasado y conserva el resto', () {
      const c = Campaign(id: 'x', name: 'Vieja', premise: 'Algo pasa');

      final r = c.copyWith(state: CampaignState.finished);

      expect(r.id, 'x');
      expect(r.name, 'Vieja');
      expect(r.premise, 'Algo pasa');
      expect(r.state, CampaignState.finished);
    });

    test('el documento estampa la versión de esquema actual', () {
      const c = Campaign(id: 'x', name: 'Y');

      expect(c.toJson()['schemaVersion'], Campaign.currentSchemaVersion);
    });

    test('un documento sin versión se trata como la 1', () {
      expect(Campaign.schemaVersionOf({'id': 'x'}), 1);
    });

    test('una versión que no es entero positivo es un error de formato', () {
      expect(
        () => Campaign.schemaVersionOf({'schemaVersion': 0}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => Campaign.schemaVersionOf({'schemaVersion': 'dos'}),
        throwsA(isA<FormatException>()),
      );
    });

    // Sin esta puerta, una versión vieja de la app abriría una campaña escrita
    // por una nueva y la guardaría de vuelta perdiendo lo que no entiende.
    test('rechaza una versión futura con un error comprensible', () {
      expect(
        () => Campaign.migrateJson({
          'schemaVersion': Campaign.currentSchemaVersion + 1,
          'id': 'x',
        }),
        throwsA(
          isA<UnsupportedDataVersionException>()
              .having(
                (e) => e.found,
                'versión encontrada',
                Campaign.currentSchemaVersion + 1,
              )
              .having(
                (e) => e.supported,
                'versión soportada',
                Campaign.currentSchemaVersion,
              ),
        ),
      );
    });

    test('migrar no modifica el mapa de entrada', () {
      final source = <String, dynamic>{'id': 'x', 'name': 'Y'};

      Campaign.migrateJson(source);

      expect(source, {'id': 'x', 'name': 'Y'});
    });
  });
}
