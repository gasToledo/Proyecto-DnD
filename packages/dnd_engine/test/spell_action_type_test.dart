import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// `castingTime` es texto libre, así que la clasificación es una heurística
/// sobre datos que puede escribir cualquiera (SRD o homebrew). Estos tests
/// fijan la heurística y, sobre todo, avisan si el contenido real deja de
/// encajar en ella.
void main() {
  Spell spell(String castingTime) => Spell(
        id: 'x',
        name: 'X',
        source: ContentSource.srd2024,
        level: 1,
        castingTime: castingTime,
      );

  test('la adicional gana a la principal pese a empezar igual', () {
    expect(spell('Acción Adicional').actionType, SpellActionType.bonusAction);
    expect(spell('Acción').actionType, SpellActionType.action);
  });

  test('la reacción tolera la coletilla de cuándo se dispara', () {
    expect(
      spell('Reacción, que realizas al recibir daño de una criatura que ves')
          .actionType,
      SpellActionType.reaction,
    );
  });

  test('lo que tarda minutos u horas no compite por el turno', () {
    for (final t in ['1 minuto', '10 minutos', '1 hora', '8 horas']) {
      expect(spell(t).actionType, SpellActionType.longer, reason: t);
    }
  });

  test('el contenido real no cae entero en longer', () async {
    final repo =
        await ContentRepository.loadFromDirectory('lib/assets/srd_2024');

    final porTipo = <SpellActionType, int>{};
    for (final s in repo.spells.values) {
      porTipo[s.actionType] = (porTipo[s.actionType] ?? 0) + 1;
    }

    // Si alguien renombra "Acción Adicional" en el contenido, la heurística
    // sigue compilando y devuelve `longer` en silencio: estas cotas son lo que
    // convierte ese cambio en un test rojo.
    expect(porTipo[SpellActionType.action] ?? 0, greaterThan(200));
    expect(porTipo[SpellActionType.bonusAction] ?? 0, greaterThan(20));
    expect(porTipo[SpellActionType.reaction] ?? 0, greaterThan(0));
  });
}
