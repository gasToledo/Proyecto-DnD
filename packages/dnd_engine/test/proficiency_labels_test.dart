import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// La ficha muestra las competencias como texto libre, y hasta ahora las
/// imprimía capitalizando el id en inglés ("Alchemists Supplies", "Light").
/// Estas pruebas fijan que la traducción exista para **todo** lo que el
/// contenido oficial referencia, que es lo que la UI va a mostrar de verdad.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  group('Traducciones', () {
    test('las categorías de armadura y arma tienen nombre en español', () {
      expect(armorTrainingLabel('light'), 'Armadura ligera');
      expect(armorTrainingLabel('shield'), 'Escudos');
      expect(weaponProficiencyLabel('simple'), 'Armas simples');
      expect(weaponProficiencyLabel('martial-ranged'),
          'Armas marciales a distancia');
    });

    test('las herramientas usan el nombre del capítulo 6 del PHB', () {
      // Tres que el catálogo escribía con nombre inventado antes de esta tanda.
      expect(toolProficiencyLabel('alchemists-supplies'),
          'Suministros de alquimista');
      expect(toolProficiencyLabel('woodcarvers-tools'),
          'Herramientas de ebanista');
      expect(toolProficiencyLabel('herbalism-kit'), 'Útiles de herborista');
      expect(toolProficiencyLabel('thieves-tools'), 'Herramientas de ladrón');
    });

    test('un id desconocido degrada al id capitalizado, no falla', () {
      // El mismo camino procesa homebrew e importaciones no confiables.
      expect(toolProficiencyLabel('herramientas-de-mesa'),
          'Herramientas De Mesa');
      expect(armorTrainingLabel(''), '');
    });
  });

  group('Cobertura del contenido oficial', () {
    /// Recorre todo lo que puede terminar en `ComputedSheet`: los campos de la
    /// clase y los efectos de clases, subclases, especies, linajes y dotes.
    Set<String> idsUsados(String tipo) {
      final ids = <String>{};
      void desdeEfectos(Iterable<Effect> efectos) {
        for (final e in efectos) {
          if (tipo == 'armor' && e is ArmorProficiencyEffect) ids.add(e.category);
          if (tipo == 'weapon' && e is WeaponProficiencyEffect) {
            ids.add(e.category);
          }
          if (tipo == 'tool' && e is ToolProficiencyEffect) ids.add(e.tool);
        }
      }

      for (final k in repo.classes.values) {
        if (tipo == 'armor') ids.addAll(k.armorProficiencies);
        if (tipo == 'weapon') ids.addAll(k.weaponProficiencies);
        for (final f in k.features) {
          desdeEfectos(f.effects);
        }
      }
      for (final s in repo.subclasses.values) {
        for (final f in s.features) {
          desdeEfectos(f.effects);
        }
      }
      for (final r in repo.races.values) {
        desdeEfectos(r.effects);
      }
      for (final l in repo.lineages.values) {
        for (final f in l.features) {
          desdeEfectos(f.effects);
        }
      }
      for (final f in repo.feats.values) {
        desdeEfectos(f.effects);
      }
      if (tipo == 'tool') {
        for (final b in repo.backgrounds.values) {
          ids.addAll(b.toolProficiencies);
        }
      }
      return ids;
    }

    test('ninguna armadura del catálogo cae al id capitalizado', () {
      for (final id in idsUsados('armor')) {
        expect(armorTrainingLabel(id), isNot(titleCaseId(id)), reason: id);
      }
    });

    test('toda competencia de arma se muestra en español', () {
      for (final id in idsUsados('weapon')) {
        // O es una categoría traducida, o es el id de un arma del catálogo y
        // el nombre lo pone el arma.
        final traducida = weaponProficiencyLabel(id) != titleCaseId(id);
        expect(traducida || repo.weapon(id) != null, isTrue, reason: id);
      }
    });

    test('ninguna herramienta del catálogo cae al id capitalizado', () {
      final ids = idsUsados('tool');
      expect(ids, isNotEmpty);
      for (final id in ids) {
        expect(toolProficiencyLabel(id), isNot(titleCaseId(id)), reason: id);
      }
    });
  });

  group('Competencia con media categoría de arma', () {
    test('el Artillero recibe las marciales a distancia, no todas', () {
      final artillero = repo.subclass('artillerist')!;
      final efectos = artillero.features
          .expand((f) => f.effects)
          .whereType<WeaponProficiencyEffect>()
          .map((e) => e.category);
      expect(efectos, contains('martial-ranged'));
      expect(efectos, isNot(contains('martial')));
    });

    test('"martial-ranged" habilita el arco largo pero no la espada larga', () {
      const profs = {'simple', 'martial-ranged'};
      expect(repo.weapon('longbow')!.isProficientWith(profs), isTrue);
      expect(repo.weapon('hand-crossbow')!.isProficientWith(profs), isTrue);
      expect(repo.weapon('longsword')!.isProficientWith(profs), isFalse);
      // El tridente es marcial y arrojadiza, pero no a distancia.
      expect(repo.weapon('trident')!.isProficientWith(profs), isFalse);
    });

    test('la categoría entera sigue habilitando todo', () {
      const profs = {'martial'};
      expect(repo.weapon('longbow')!.isProficientWith(profs), isTrue);
      expect(repo.weapon('longsword')!.isProficientWith(profs), isTrue);
    });
  });
}
