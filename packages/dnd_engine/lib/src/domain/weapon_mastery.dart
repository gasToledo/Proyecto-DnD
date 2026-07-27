/// Glosario de las propiedades de maestría con armas (PHB 2024, cap. 6).
///
/// El campo `mastery` de un arma guarda el identificador en inglés (`nick`,
/// `vex`), que es lo que usan los datos y las importaciones. Este glosario le
/// pone nombre oficial y texto de regla para que la ficha no muestre el
/// identificador crudo.
library;

/// Una propiedad de maestría: su nombre en español y qué hace.
class WeaponMastery {
  /// Identificador en inglés, el que aparece en `Weapon.mastery`.
  final String id;

  /// Nombre oficial en español del PHB 2024.
  final String name;

  final String description;

  const WeaponMastery({
    required this.id,
    required this.name,
    required this.description,
  });
}

/// Las ocho propiedades de maestría, indexadas por su identificador.
const Map<String, WeaponMastery> weaponMasteries = {
  'cleave': WeaponMastery(
    id: 'cleave',
    name: 'Hender',
    description:
        'Si acertás a una criatura con un ataque cuerpo a cuerpo con esta '
        'arma, podés hacer un ataque cuerpo a cuerpo con ella contra una '
        'segunda criatura que esté a 1,5 m o menos de la primera y dentro de '
        'tu alcance. Si acertás, la segunda criatura sufre el daño del arma, '
        'pero no sumás tu modificador de característica salvo que sea '
        'negativo. Solo una vez por turno.',
  ),
  'graze': WeaponMastery(
    id: 'graze',
    name: 'Rozar',
    description:
        'Si tu tirada de ataque con esta arma falla, podés causarle a la '
        'criatura un daño igual al modificador de característica que usaste '
        'para el ataque. Es del mismo tipo que inflige el arma y solo aumenta '
        'si aumenta ese modificador.',
  ),
  'nick': WeaponMastery(
    id: 'nick',
    name: 'Mellar',
    description:
        'Cuando hagas el ataque extra de la propiedad Ligera, podés hacerlo '
        'como parte de la acción de Atacar en vez de como acción adicional. '
        'Solo una vez por turno.',
  ),
  'push': WeaponMastery(
    id: 'push',
    name: 'Empujar',
    description:
        'Si acertás a una criatura con esta arma, podés empujarla hasta 3 m '
        'en línea recta alejándola de vos, siempre que sea Grande o más '
        'pequeña.',
  ),
  'sap': WeaponMastery(
    id: 'sap',
    name: 'Debilitar',
    description:
        'Si acertás a una criatura con esta arma, tiene desventaja en su '
        'próxima tirada de ataque antes del principio de tu siguiente turno.',
  ),
  'slow': WeaponMastery(
    id: 'slow',
    name: 'Ralentizar',
    description:
        'Si acertás a una criatura con esta arma y le causás daño, podés '
        'reducir su velocidad en 3 m hasta el principio de tu siguiente '
        'turno. Varios ataques con esta propiedad no acumulan: la reducción '
        'nunca supera los 3 m.',
  ),
  'topple': WeaponMastery(
    id: 'topple',
    name: 'Derribar',
    description:
        'Si acertás a una criatura con esta arma, podés obligarla a hacer una '
        'salvación de Constitución (CD 8 + tu modificador de característica '
        'del ataque + tu bonificador de competencia). Si falla, queda '
        'derribada.',
  ),
  'vex': WeaponMastery(
    id: 'vex',
    name: 'Molestar',
    description:
        'Si acertás a una criatura con esta arma y le causás daño, tenés '
        'ventaja en tu siguiente tirada de ataque contra ella antes del final '
        'de tu siguiente turno.',
  ),
};

/// Nombre en español de una maestría, o el identificador si es desconocida
/// (puede venir de homebrew o de una importación).
String weaponMasteryName(String id) => weaponMasteries[id]?.name ?? id;
