import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Tablas de conjuros siempre preparados de subclase. Antes vivían solo como
/// texto en la descripción del rasgo: el jugador los tenía gratis por regla y
/// la ficha no los mostraba ni los dejaba lanzar.
///
/// La prueba que de verdad valida la transcripción no es contar conjuros, sino
/// comprobar que **cada uno entra en los espacios que la clase tiene a ese
/// nivel**. Un conjuro corrido de fila o leído de otra tabla casi siempre
/// rompe esa condición.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  /// Progresión de lanzamiento de cada clase que tiene tablas de subclase.
  const progresiones = <String, CasterProgression>{
    'cleric': CasterProgression.full,
    'druid': CasterProgression.full,
    'sorcerer': CasterProgression.full,
    'warlock': CasterProgression.pact,
    'artificer': CasterProgression.half,
    'paladin': CasterProgression.half,
    'ranger': CasterProgression.half,
  };

  /// Todos los rasgos de tabla: efectos que son *solo* conjuros siempre
  /// preparados, que es como los declara el contenido.
  Iterable<({Subclass sub, ClassFeature feature})> tablas() sync* {
    for (final sub in repo.subclasses.values) {
      for (final f in sub.features) {
        if (f.effects.isNotEmpty &&
            f.effects.every((e) => e is AlwaysPreparedSpellEffect)) {
          yield (sub: sub, feature: f);
        }
      }
    }
  }

  test('las 24 subclases con tabla la tienen cargada', () {
    final conTabla = tablas().map((t) => t.sub.id).toSet();
    // 19 del PHB 2024 más las 5 del Artífice. El Círculo de la Tierra queda
    // fuera a propósito y **sigue quedando fuera**: sus cuatro tablas dependen
    // del terreno elegido, así que viven en las dotes `druid-land` y no en los
    // rasgos de la subclase (ver `circle_land_test.dart`). La aserción se
    // conserva como guarda: si alguien vuelve a meter la tabla acá, se rompe.
    expect(conTabla, hasLength(24));
    expect(conTabla, isNot(contains('circle-land')));
    // Las que el manual deja sin *tabla* siguen sin tabla. Ojo: no tener tabla
    // no es lo mismo que no conceder ningún conjuro siempre preparado. El
    // Círculo de las Estrellas (Guía y Saeta Guía) y el Abjurador
    // (Contrahechizo y Disipar Magia) conceden un par fijo desde un rasgo
    // suelto, que no es una tabla por tramos y por eso `tablas()` no lo ve.
    expect(conTabla, isNot(contains('circle-stars')));
    expect(conTabla, isNot(contains('wild-magic-sorcery')));
    expect(conTabla, isNot(contains('hunter')));
    for (final id in ['abjurer', 'diviner', 'evoker', 'illusionist']) {
      expect(conTabla, isNot(contains(id)), reason: 'el Mago no tiene tabla');
    }
  });

  test('los conjuros sueltos, fuera de tabla, también se conceden', () {
    // Contraparte del test de arriba: estos rasgos declaran un par fijo de
    // conjuros junto a un passiveTrait, así que no son "tabla" pero el jugador
    // igual los tiene. Antes vivían solo en la prosa.
    Set<String> deRasgo(String subclassId, int level) => {
          for (final f in repo.subclass(subclassId)!.featuresUpTo(level))
            for (final e in f.effects)
              if (e is AlwaysPreparedSpellEffect) e.spellId,
        };

    expect(deRasgo('circle-stars', 3), {'guidance', 'guiding-bolt'});
    expect(deRasgo('abjurer', 10), {'counterspell', 'dispel-magic'});
    expect(deRasgo('abjurer', 9), isEmpty, reason: 'Rompeconjuros es nivel 10');
  });

  test('cada conjuro entra en los espacios de su clase a ese nivel', () {
    var comprobados = 0;
    for (final (:sub, :feature) in tablas()) {
      final progresion = progresiones[sub.classId];
      expect(progresion, isNotNull, reason: '${sub.classId} sin progresión');
      final espacios = spellSlotsFor(progresion!, feature.level);
      final mayor = espacios.keys.fold<int>(0, (m, l) => l > m ? l : m);

      for (final e in feature.effects.cast<AlwaysPreparedSpellEffect>()) {
        final spell = repo.spell(e.spellId);
        expect(spell, isNotNull,
            reason: '${sub.id}: no existe el conjuro "${e.spellId}"');
        comprobados++;
        // Un truco es legítimo: varias subclases conceden trucos en su tabla
        // (Llama Sagrada del Patrón Celestial, Fragmento Mental del Aberrante).
        if (spell!.isCantrip) continue;
        expect(spell.level, lessThanOrEqualTo(mayor),
            reason: '${sub.id} nivel ${feature.level}: ${spell.name} es de '
                'nivel ${spell.level} y el mayor espacio es $mayor');
      }
    }
    expect(comprobados, 232, reason: '181 del PHB más 51 del Artífice');
  });

  test('la tabla de una subclase no repite conjuro', () {
    for (final sub in repo.subclasses.values) {
      final ids = [
        for (final f in sub.features)
          for (final e in f.effects)
            if (e is AlwaysPreparedSpellEffect) e.spellId,
      ];
      expect(ids.toSet().length, ids.length,
          reason: '${sub.id} concede dos veces el mismo conjuro');
    }
  });

  test('los tramos son los que manda la progresión de la clase', () {
    // Lanzador completo 3/5/7/9; semi-lanzador 3/5/9/13/17.
    const completo = [3, 5, 7, 9];
    const semi = [3, 5, 9, 13, 17];
    final porSubclase = <String, List<int>>{};
    for (final (:sub, :feature) in tablas()) {
      (porSubclase[sub.id] ??= []).add(feature.level);
    }
    for (final e in porSubclase.entries) {
      final sub = repo.subclass(e.key)!;
      final esperado =
          progresiones[sub.classId] == CasterProgression.half ? semi : completo;
      expect(e.value..sort(), esperado, reason: e.key);
    }
  });

  test('un Paladín de Entrega los tiene sin gastar cupo', () {
    final compilador = CharacterCompiler(repo);
    ComputedSheet en(int nivel, {String? subclassId}) => compilador.compile(
          Character(
            id: 'p',
            name: 'Prueba',
            raceId: 'human',
            classId: 'paladin',
            subclassId: subclassId,
            backgroundId: 'soldier',
            level: nivel,
            assignedScores: {for (final a in Ability.values) a: 14},
            hpPerLevel: List.filled(nivel, 6),
          ),
        );

    // El Paladín ya trae conjuros siempre preparados de *clase* (Castigo
    // Divino a nivel 2, Hallar Corcel a nivel 5), así que lo que se mide es el
    // aporte de la subclase: la diferencia contra el mismo nivel sin subclase.
    Set<String> deSubclase(int nivel, String subclassId) =>
        en(nivel, subclassId: subclassId)
            .alwaysPreparedSpellIds
            .difference(en(nivel).alwaysPreparedSpellIds);

    expect(en(2).alwaysPreparedSpellIds, {'divine-smite'},
        reason: 'Castigo de Paladín es un rasgo de clase de nivel 2');
    expect(deSubclase(2, 'oath-devotion'), isEmpty,
        reason: 'la subclase llega a nivel 3');
    expect(deSubclase(3, 'oath-devotion'),
        {'protection-from-evil-and-good', 'shield-of-faith'});
    expect(deSubclase(17, 'oath-devotion'), hasLength(10));
    // No ocupan cupo: el conteo de preparados es el mismo sin subclase.
    expect(en(17, subclassId: 'oath-devotion').spellcasting!.preparedCount,
        en(17).spellcasting!.preparedCount);
  });
}
