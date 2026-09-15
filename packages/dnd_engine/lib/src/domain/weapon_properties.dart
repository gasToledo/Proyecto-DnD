/// Glosario de las propiedades de arma (PHB 2024, cap. 6) y de sus dos
/// categorías.
///
/// Mismo criterio que `weaponMasteries`: `Weapon.properties` guarda el id en
/// inglés (`finesse`, `two-handed`), que es lo que viaja en los datos, y acá
/// viven el nombre y la regla. Existe para explicar la elección a quien arma
/// un arma propia: «Sutil» no dice qué hace.
///
/// Es **descriptivo**. Las reglas que el compilador aplica (Sutil, Ligera, A
/// dos manos, Versátil) salen de los ids, no de estos textos.
library;

/// Una propiedad de arma: su nombre en español y qué hace.
class WeaponProperty {
  /// Identificador en inglés, el que aparece en `Weapon.properties`.
  final String id;
  final String name;
  final String description;

  const WeaponProperty({
    required this.id,
    required this.name,
    required this.description,
  });
}

/// Las diez propiedades que usa el catálogo, en el orden en que se ofrecen.
const Map<String, WeaponProperty> weaponProperties = {
  'finesse': WeaponProperty(
    id: 'finesse',
    name: 'Sutil',
    description:
        'Para el ataque y el daño usás, a elección, tu modificador de Fuerza '
        'o de Destreza, pero el mismo en las dos tiradas.',
  ),
  'versatile': WeaponProperty(
    id: 'versatile',
    name: 'Versátil',
    description:
        'Se puede empuñar con una o con dos manos. A dos manos, en un ataque '
        'cuerpo a cuerpo, hace el daño del dado versátil en vez del normal.',
  ),
  'two-handed': WeaponProperty(
    id: 'two-handed',
    name: 'A dos manos',
    description: 'Hacen falta las dos manos para atacar con ella.',
  ),
  'light': WeaponProperty(
    id: 'light',
    name: 'Ligera',
    description:
        'Si atacás con ella en la acción de Atacar, más tarde en el mismo '
        'turno podés hacer un ataque extra como acción adicional con otra '
        'arma Ligera. Ese ataque no suma tu modificador al daño, salvo que '
        'sea negativo.',
  ),
  'heavy': WeaponProperty(
    id: 'heavy',
    name: 'Pesada',
    description:
        'Tenés desventaja al atacar con ella si es cuerpo a cuerpo y tu Fuerza '
        'es menor que 13, o si es a distancia y tu Destreza es menor que 13.',
  ),
  'thrown': WeaponProperty(
    id: 'thrown',
    name: 'Arrojadiza',
    description:
        'Se puede lanzar para hacer un ataque a distancia, y sacarla es parte '
        'del ataque. Si es un arma cuerpo a cuerpo, se lanza con la misma '
        'característica con la que se ataca con ella.',
  ),
  'ranged': WeaponProperty(
    id: 'ranged',
    name: 'A distancia',
    description:
        'Ataca desde lejos, con Destreza. Más allá del alcance normal el '
        'ataque tiene desventaja, y más allá del largo no se puede atacar.',
  ),
  'ammunition': WeaponProperty(
    id: 'ammunition',
    name: 'Munición',
    description:
        'Solo sirve si tenés munición para disparar, y cada ataque gasta una '
        'pieza. Después del combate, con 1 minuto de búsqueda recuperás la '
        'mitad de lo gastado.',
  ),
  'reach': WeaponProperty(
    id: 'reach',
    name: 'Alcance',
    description:
        'Suma 5 pies a tu alcance al atacar con ella, también para los '
        'ataques de oportunidad.',
  ),
  'loading': WeaponProperty(
    id: 'loading',
    name: 'Recarga',
    description:
        'Disparás una sola pieza de munición por acción, acción adicional o '
        'reacción, aunque normalmente puedas hacer más ataques.',
  ),
};

/// Lo que significan los dos números del alcance (`Weapon.rangeNormal` y
/// `Weapon.rangeLong`), que valen igual para A distancia y Arrojadiza.
const weaponRangeRule =
    'Hasta el alcance normal se ataca sin problema; entre el normal y el '
    'largo, con desventaja; más allá del largo no se puede atacar. Se mide '
    'en pies.';

/// Qué implica cada categoría de arma, por su id (`Weapon.category`).
const Map<String, String> weaponCategoryRules = {
  'simple':
      'Todas las clases del manual son competentes con las armas simples.',
  'martial':
      'Sin competencia con armas marciales se puede atacar igual, pero sin '
          'sumar el bonificador de competencia y sin usar su maestría.',
};
