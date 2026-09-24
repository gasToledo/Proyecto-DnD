import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

void main() {
  // La abreviatura que se muestra se tradujo al castellano del SRD, pero los
  // documentos guardados y las fórmulas de las criaturas usan los códigos en
  // inglés. Si alguien vuelve a unirlas, estas lecturas se rompen en silencio.
  test('los códigos de datos siguen en inglés y la interfaz en castellano', () {
    expect([for (final a in Ability.values) a.code],
        ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA']);
    expect([for (final a in Ability.values) a.abbr],
        ['FUE', 'DES', 'CON', 'INT', 'SAB', 'CAR']);
    expect(Ability.fromKey('str'), Ability.strength);
    expect(Ability.fromKey('WIS'), Ability.wisdom);
    expect(Ability.fromKey('charisma'), Ability.charisma);
  });
}
