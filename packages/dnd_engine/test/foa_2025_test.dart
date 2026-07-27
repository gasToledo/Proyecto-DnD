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

  group('Trasfondos', () {
    Background background(String id) => repo.background(id)!;

    test('están los 17 trasfondos del capítulo 2', () {
      final foa = repo.backgrounds.values
          .where((b) => b.source == ContentSource.foa2025);
      expect(foa, hasLength(17));
    });

    test('las trece casas dracomarcadas conceden su marca a nivel 1', () {
      // El libro es explícito: tomar el trasfondo de la casa es la única forma
      // de tener una marca a nivel 1.
      const casas = {
        'cannith': 'mark-of-making',
        'deneith': 'mark-of-sentinel',
        'ghallanda': 'mark-of-hospitality',
        'jorasco': 'mark-of-healing',
        'kundarak': 'mark-of-warding',
        'lyrandar': 'mark-of-storm',
        'medani': 'mark-of-detection',
        'orien': 'mark-of-passage',
        'phiarlan': 'mark-of-shadow',
        'sivis': 'mark-of-scribing',
        'tharashk': 'mark-of-finding',
        'thuranni': 'mark-of-shadow',
        'vadalis': 'mark-of-handling',
      };
      casas.forEach((casa, marca) {
        final b = background('house-$casa-heir');
        expect(b.originFeatId, marca, reason: casa);
        expect(repo.feat(marca)!.category, 'dragonmark');
      });
      // Phiarlan y Thuranni comparten la Marca de Sombra: la casa se escindió,
      // la marca no. Dos trasfondos que apuntan a la misma dote es correcto.
      expect(background('house-phiarlan-heir').originFeatId,
          background('house-thuranni-heir').originFeatId);
    });

    test('Heredero Aberrante trae la marca aberrante', () {
      final b = background('aberrant-heir');
      expect(b.originFeatId, 'aberrant-dragonmark');
      expect(b.skillProficiencies, containsAll(['history', 'intimidation']));
    });

    test('los tres sin marca usan dotes de origen normales', () {
      // Agente de Casa da afiliación sin marca; Arqueólogo e Inquisidor
      // sostienen las campañas de los capítulos 4 y 6.
      const sinMarca = {
        'house-agent': 'lucky',
        'archaeologist': 'skilled',
        'inquisitive': 'alert',
      };
      sinMarca.forEach((id, dote) {
        expect(background(id).originFeatId, dote, reason: id);
        expect(repo.feat(dote)!.category, 'origin');
      });
    });

    test('todos declaran ícono y línea de sabor', () {
      // `iconFor` cae en silencio a un genérico si el id no está registrado en
      // la app, así que acá al menos se exige que el dato esté.
      for (final b in repo.backgrounds.values
          .where((b) => b.source == ContentSource.foa2025)) {
        expect(b.iconId, isNotNull, reason: b.id);
        expect(b.tagline, isNotNull, reason: b.id);
      }
    });
  });

  group('Especies', () {
    Race race(String id) => repo.race(id)!;
    Iterable<PassiveTraitEffect> rasgos(String id) =>
        race(id).effects.whereType<PassiveTraitEffect>();
    String rasgo(String id, String nombre) =>
        rasgos(id).firstWhere((e) => e.name == nombre).description;

    test('están las 5 especies del capítulo 2', () {
      final foa =
          repo.races.values.where((r) => r.source == ContentSource.foa2025);
      expect(foa.map((r) => r.id).toSet(), {
        'changeling',
        'kalashtar',
        'khoravar',
        'shifter',
        'warforged',
      });
    });

    test('Cambiaformas elige dos habilidades de una lista de cinco', () {
      final r = race('changeling');
      expect(r.skillChoiceCount, 2);
      expect(r.skillChoiceFrom, [
        'deception',
        'insight',
        'intimidation',
        'performance',
        'persuasion',
      ]);
    });

    test('Kalashtar resiste lo psíquico y tiene telepatía por nivel', () {
      final r = race('kalashtar');
      expect(
          r.effects.whereType<ResistanceEffect>().single.damageType, 'psychic');
      expect(
          rasgo('kalashtar', 'Vínculo Mental'), contains('10 veces tu nivel'));
      expect(rasgo('kalashtar', 'Mente Dual'), contains('ventaja'));
    });

    test('Khoravar y Cambiante ven en la oscuridad a 60 pies', () {
      for (final id in ['khoravar', 'shifter']) {
        expect(race(id).effects.whereType<DarkvisionEffect>().single.range, 60,
            reason: id);
      }
      // El Cambiaformas y el Forjado no la tienen.
      for (final id in ['changeling', 'warforged']) {
        expect(race(id).effects.whereType<DarkvisionEffect>(), isEmpty,
            reason: id);
      }
    });

    test('Cambiante elige entre las cuatro habilidades bestiales', () {
      final r = race('shifter');
      expect(r.skillChoiceCount, 1);
      expect(r.skillChoiceFrom,
          ['acrobatics', 'athletics', 'intimidation', 'survival']);
      // Los cuatro modos de transformación viven en un solo rasgo, porque la
      // elección todavía no se persiste.
      final bestial = rasgo('shifter', 'Naturaleza Bestial');
      for (final modo in [
        'Piel Robusta',
        'Colmillo Largo',
        'Paso Veloz',
        'Cacería Salvaje',
      ]) {
        expect(bestial, contains(modo));
      }
    });

    test('Forjado suma +1 a la CA y resiste veneno', () {
      final r = race('warforged');
      expect(r.effects.whereType<ArmorClassBonusEffect>().single.amount, 1);
      expect(
          r.effects.whereType<ResistanceEffect>().single.damageType, 'poison');
    });

    test('ninguna especie nueva mide distancias en métrico', () {
      // El manual del que sale el contenido está en metros; la casa juega en
      // pies y el catálogo entero está normalizado así.
      final metrico =
          RegExp(r'\d\s?(m|km|cm)(?![\wáéíóúñ])', caseSensitive: false);
      for (final r in repo.races.values
          .where((r) => r.source == ContentSource.foa2025)) {
        for (final e in r.effects.whereType<PassiveTraitEffect>()) {
          expect(metrico.hasMatch(e.description), isFalse,
              reason: '${r.id}/${e.name}: ${e.description}');
        }
      }
    });
  });
}
