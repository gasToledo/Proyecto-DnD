import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

Character _base() => Character(
      id: 'x',
      name: 'Prueba',
      raceId: 'human',
      classId: 'fighter',
      backgroundId: 'soldier',
      assignedScores: {for (final a in Ability.values) a: 12},
      hpPerLevel: const [10],
      equippedArmorId: 'leather',
      equippedWeaponIds: const ['longsword'],
    );

void main() {
  group('Character.copyWith y equipo', () {
    test('cambiar a otra armadura la reemplaza', () {
      final c = _base().copyWith(equippedArmorId: 'chain-mail');
      expect(c.equippedArmorId, 'chain-mail');
    });

    test('pasar null DESEQUIPA la armadura (antes se conservaba)', () {
      final c = _base().copyWith(equippedArmorId: null);
      expect(c.equippedArmorId, isNull);
    });

    test('no pasar equippedArmorId conserva la armadura', () {
      final c = _base().copyWith(name: 'Otro');
      expect(c.equippedArmorId, 'leather');
      expect(c.name, 'Otro');
    });

    test('el cambio sobrevive un round-trip por JSON', () {
      final c = _base().copyWith(equippedArmorId: null);
      final restored = Character.fromJson(c.toJson());
      expect(restored.equippedArmorId, isNull);
    });

    test('desequipar preserva el CombatState por referencia', () {
      final base = _base();
      final c = base.copyWith(equippedArmorId: null);
      expect(identical(c.combat, base.combat), isTrue);
    });
  });
}
