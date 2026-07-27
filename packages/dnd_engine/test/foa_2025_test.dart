import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Contenido de *Eberron: Forge of the Artificer* (capítulo 2), sin la clase
/// Artífice. Nada de esto está en el SRD: todo va etiquetado `foa_2025` para
/// que el jugador vea de qué libro sale antes de comprometer un personaje.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  Feat feat(String id) => repo.feat(id)!;

  group('Dotes', () {
    test('están las 28 dotes del capítulo 2, repartidas por categoría', () {
      final foa =
          repo.feats.values.where((f) => f.source == ContentSource.foa2025);
      expect(foa, hasLength(28));

      int conCategoria(String c) => foa.where((f) => f.category == c).length;
      expect(conCategoria('dragonmark'), 13);
      expect(conCategoria('general'), 14);
      expect(conCategoria('epic-boon'), 1);
    });

    test('las doce marcas establecidas están todas', () {
      const marcas = {
        'detection',
        'finding',
        'handling',
        'healing',
        'hospitality',
        'making',
        'passage',
        'scribing',
        'sentinel',
        'shadow',
        'storm',
        'warding',
      };
      for (final m in marcas) {
        expect(repo.feat('mark-of-$m'), isNotNull, reason: 'falta mark-of-$m');
        expect(repo.feat('greater-mark-of-$m'), isNotNull,
            reason: 'falta greater-mark-of-$m');
      }
      // Y la aberrante, que no es de casa pero sigue el mismo par.
      expect(feat('aberrant-dragonmark').category, 'dragonmark');
      expect(feat('greater-aberrant-mark').category, 'general');
    });

    test('cada marca mayor exige su marca base', () {
      final mayores = repo.feats.values
          .where((f) => f.id.startsWith('greater-mark-of-'))
          .toList();
      expect(mayores, hasLength(12));
      for (final f in mayores) {
        final base = f.id.replaceFirst('greater-', '');
        expect(f.prerequisite?.requiredFeatIds, [base], reason: f.id);
        expect(f.prerequisite?.minLevel, 4, reason: f.id);
      }
      expect(feat('greater-aberrant-mark').prerequisite?.requiredFeatIds,
          ['aberrant-dragonmark']);
    });

    test('Marca Dracónica Potente exige cualquier dote de marca', () {
      final p = feat('potent-dragonmark').prerequisite!;
      expect(p.requiredFeatCategory, 'dragonmark');
      expect(p.requiredFeatIds, isEmpty);
      expect(p.minLevel, 4);
    });

    test('Bendición de Siberys es épica y pide nivel 19', () {
      final f = feat('boon-of-siberys');
      expect(f.category, 'epic-boon');
      expect(f.prerequisite?.minLevel, 19);
    });

    test('solo Marca Aberrante Mayor sube una característica concreta', () {
      // Las otras trece generales suben "una a tu elección", que todavía no se
      // modela: queda en el texto, como el resto del catálogo.
      final conAsi = repo.feats.values
          .where((f) => f.source == ContentSource.foa2025)
          .where(
              (f) => f.effects.whereType<AbilityScoreBonusEffect>().isNotEmpty)
          .map((f) => f.id);
      expect(conAsi, ['greater-aberrant-mark']);
      expect(
        feat('greater-aberrant-mark')
            .effects
            .whereType<AbilityScoreBonusEffect>()
            .single
            .ability,
        Ability.constitution,
      );
    });

    test(
        'las tablas de Conjuros de la Marca citan el catálogo, no texto suelto',
        () {
      // Se generaron resolviendo ids contra spells.json; el riesgo real es que
      // alguien las edite a mano y escriba un nombre que no existe.
      final nombres = {for (final s in repo.spells.values) s.name};
      final marcas = repo.feats.values.where(
          (f) => f.category == 'dragonmark' && f.id != 'aberrant-dragonmark');
      expect(marcas, hasLength(12));
      for (final f in marcas) {
        final tabla = f.effects
            .whereType<PassiveTraitEffect>()
            .firstWhere((e) => e.name == 'Conjuros de la Marca');
        for (final nivel in [1, 2, 3, 4, 5]) {
          expect(tabla.description, contains('Nivel $nivel:'), reason: f.id);
        }
        // Muestra: el conjuro de nivel 5 de cada tabla existe en el catálogo.
        final ultimo =
            tabla.description.split('Nivel 5: ').last.replaceAll('.', '');
        expect(nombres, contains(ultimo), reason: '${f.id}: "$ultimo"');
      }
    });

    test('Marca de Tormenta y Marca de Tránsito traen su beneficio pasivo', () {
      String texto(String id, String rasgo) => feat(id)
          .effects
          .whereType<PassiveTraitEffect>()
          .firstWhere((e) => e.name == rasgo)
          .description;

      expect(
          texto('mark-of-storm', 'Don de la Tormenta'), contains('relámpago'));
      // El manual está en pies, no en metros: la casa lo mantiene así.
      expect(texto('mark-of-passage', 'Velocidad del Mensajero'),
          contains('5 pies'));
    });
  });
}
