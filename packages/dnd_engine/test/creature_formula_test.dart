import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// El evaluador de fórmulas del catálogo de criaturas. Es la pieza de la que
/// cuelgan todos los números de un compañero: si acá se cuela un error de
/// precedencia, el Defensor de Acero aparece con los PG mal en la mesa.
void main() {
  final vars = CreatureVars.from(
    level: 5,
    proficiencyBonus: 3,
    abilityModifiers: {
      Ability.strength: 2,
      Ability.dexterity: 1,
      Ability.constitution: 2,
      Ability.intelligence: 4,
      Ability.wisdom: 0,
      Ability.charisma: -1,
    },
    spellAttackBonus: 7,
    spellSaveDc: 15,
    spellLevel: 3,
  );

  String r(String template) => resolveCreatureFormula(template, vars);

  test('el texto de afuera de las llaves queda literal', () {
    expect(r('40 pies'), '40 pies');
    expect(r(''), '');
  });

  test('resuelve variables del personaje', () {
    expect(r('{level}'), '5');
    expect(r('{PB}'), '3');
    expect(r('{INT}'), '4');
    expect(r('{CHA}'), '-1');
    expect(r('{SPELLATK}'), '7');
    expect(r('{SPELLDC}'), '15');
    expect(r('{spellLevel}'), '3');
  });

  test('la multiplicación va antes que la suma', () {
    // PG del Defensor de Acero: 5 + cinco veces el nivel de Artífice.
    expect(r('{5+5*level}'), '30');
    // Si la precedencia estuviera al revés daría 50, que es el error que este
    // caso existe para atrapar.
    expect(r('{2*level+3}'), '13');
  });

  test('los paréntesis mandan sobre la precedencia', () {
    expect(r('{(5+5)*level}'), '50');
  });

  test('acepta resta y signo delante de un valor', () {
    expect(r('{10-level}'), '5');
    expect(r('{-CHA}'), '1');
    expect(r('{10+-CHA}'), '11');
  });

  test('mezcla dados con cálculo sin tocar los dados', () {
    // Desgarro Potenciado por Fuerza: 1d8 + 2 + tu modificador por Inteligencia.
    expect(r('1d8+{2+INT}'), '1d8+6');
    expect(r('{1+1}d6+{INT}'), '2d6+4');
  });

  test('resuelve varias llaves en un mismo texto', () {
    expect(
      r('CA {12+INT}, PG {5+5*level}'),
      'CA 16, PG 30',
    );
  });

  group('resolveCreatureInt evalúa el campo entero, sin llaves', () {
    test('una constante sigue siendo válida', () {
      expect(resolveCreatureInt('18', vars), 18);
    });

    test('la expresión es todo el campo', () {
      // Escrito con llaves —"12+{INT}"— el "12+" quedaría afuera como texto y
      // daría "12+4". Por eso los campos que tienen que dar un número no las
      // usan: es el error que se lee bien y calcula mal.
      expect(resolveCreatureInt('12+INT', vars), 16);
      expect(resolveCreatureInt('5+5*level', vars), 30);
      expect(resolveCreatureInt('SPELLATK', vars), 7);
    });

    test('lo que no es aritmética falla', () {
      expect(
        () => resolveCreatureInt('1d8+2', vars),
        throwsA(isA<CreatureFormulaException>()),
      );
      expect(
        () => resolveCreatureInt('', vars),
        throwsA(isA<CreatureFormulaException>()),
      );
    });
  });

  group('fórmulas inválidas fallan en vez de degradar', () {
    void invalid(String template) => expect(
          () => resolveCreatureFormula(template, vars),
          throwsA(isA<CreatureFormulaException>()),
          reason: template,
        );

    test('variable que no existe', () => invalid('{NIVEL}'));
    test('llave sin cerrar', () => invalid('{5+5'));
    test('llaves sin nada adentro', () => invalid('{}'));
    test('paréntesis sin cerrar', () => invalid('{(5+5}'));
    test('operador colgando', () => invalid('{5+}'));
    test('carácter inesperado', () => invalid('{5/2}'));
    test('sobra un token', () => invalid('{5 5}'));
  });
}
