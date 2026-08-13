/// Nombres en español de las competencias que la ficha muestra como texto:
/// entrenamiento con armadura, categorías de arma y herramientas.
///
/// Mismo criterio que [DamageType]: el contenido las referencia por su id en
/// inglés —la clave estable que viaja en los JSON y en los personajes
/// guardados— y la traducción vive únicamente acá, no repartida por la UI.
///
/// Todas las funciones caen al id capitalizado ante una clave desconocida en
/// vez de fallar, porque el mismo camino procesa homebrew e importaciones.
library;

import 'damage_type.dart' show DamageType;
import 'name_sort.dart';

/// Entrenamiento con armadura: las tres categorías del PHB 2024 más escudos.
const _armorLabels = <String, String>{
  'light': 'Armadura ligera',
  'medium': 'Armadura media',
  'heavy': 'Armadura pesada',
  'shield': 'Escudos',
};

/// Categorías de arma. Las variantes `-ranged` y `-melee` existen porque hay
/// rasgos que solo conceden media categoría: el Artillero recibe las marciales
/// **a distancia**, no todas las marciales.
const _weaponLabels = <String, String>{
  'simple': 'Armas simples',
  'simple-melee': 'Armas simples cuerpo a cuerpo',
  'simple-ranged': 'Armas simples a distancia',
  'martial': 'Armas marciales',
  'martial-melee': 'Armas marciales cuerpo a cuerpo',
  'martial-ranged': 'Armas marciales a distancia',
};

/// Herramientas del capítulo 6 del PHB 2024, con el nombre de la tabla
/// "Herramientas". `artisans-tools`, `gaming-set` y `musical-instrument` son
/// las entradas genéricas que usa el contenido cuando la regla dice "una a tu
/// elección" y el catálogo todavía no ofrece esa elección.
const _toolLabels = <String, String>{
  // Herramientas de artesano.
  'artisans-tools': 'Herramientas de artesano',
  'alchemists-supplies': 'Suministros de alquimista',
  'brewers-supplies': 'Suministros de cervecero',
  'calligraphers-supplies': 'Suministros de calígrafo',
  'carpenters-tools': 'Herramientas de carpintero',
  'cartographers-tools': 'Herramientas de cartógrafo',
  'cobblers-tools': 'Herramientas de zapatero',
  'cooks-utensils': 'Útiles de cocinero',
  'glassblowers-tools': 'Herramientas de soplador de vidrio',
  'jewelers-tools': 'Herramientas de joyero',
  'leatherworkers-tools': 'Herramientas de curtidor',
  'masons-tools': 'Herramientas de albañil',
  'painters-supplies': 'Suministros de pintor',
  'potters-tools': 'Herramientas de alfarero',
  'smiths-tools': 'Herramientas de herrero',
  'tinkers-tools': 'Herramientas de manitas',
  'weavers-tools': 'Herramientas de tejedor',
  'woodcarvers-tools': 'Herramientas de ebanista',
  // Otras herramientas.
  'disguise-kit': 'Útiles para disfrazarse',
  'forgery-kit': 'Útiles para falsificar',
  'gaming-set': 'Juego',
  'dice-set': 'Juego de dados',
  'dragonchess-set': 'Ajedrez drag\u00f3n',
  'playing-card-set': 'Baraja de cartas',
  'three-dragon-ante-set': 'Tres Dragones',
  'herbalism-kit': 'Útiles de herborista',
  'musical-instrument': 'Instrumento musical',
  'bagpipes': 'Gaita',
  'drum': 'Tambor',
  'dulcimer': 'Dulc\u00e9mele',
  'flute': 'Flauta',
  'horn': 'Cuerno',
  'lute': 'La\u00fad',
  'lyre': 'Lira',
  'pan-flute': 'Flauta de pan',
  'shawm': 'Chirim\u00eda',
  'viol': 'Viola',
  'navigators-tools': 'Herramientas de navegante',
  'poisoner-kit': 'Útiles de envenenador',
  'thieves-tools': 'Herramientas de ladrón',
};

const artisanToolProficiencyIds = <String>[
  'alchemists-supplies',
  'brewers-supplies',
  'calligraphers-supplies',
  'carpenters-tools',
  'cartographers-tools',
  'cobblers-tools',
  'cooks-utensils',
  'glassblowers-tools',
  'jewelers-tools',
  'leatherworkers-tools',
  'masons-tools',
  'painters-supplies',
  'potters-tools',
  'smiths-tools',
  'tinkers-tools',
  'weavers-tools',
  'woodcarvers-tools',
];

const gamingSetProficiencyIds = <String>[
  'dice-set',
  'dragonchess-set',
  'playing-card-set',
  'three-dragon-ante-set',
];

const musicalInstrumentProficiencyIds = <String>[
  'bagpipes',
  'drum',
  'dulcimer',
  'flute',
  'horn',
  'lute',
  'lyre',
  'pan-flute',
  'shawm',
  'viol',
];

/// Nombre del entrenamiento con armadura [id] ("light" → "Armadura ligera").
String armorTrainingLabel(String id) => _armorLabels[id] ?? titleCaseId(id);

/// Nombre de la categoría de arma [id] ("martial" → "Armas marciales").
///
/// Un rasgo también puede conceder competencia con **un arma concreta** por su
/// id (el Bardo con el estoque, el Pícaro con la espada corta). Esos ids no
/// están acá: el nombre lo tiene el arma en el catálogo, así que quien muestre
/// la competencia debe consultar primero al repositorio y usar esta función
/// solo cuando no haya arma con ese id.
String weaponProficiencyLabel(String id) =>
    _weaponLabels[id] ?? titleCaseId(id);

/// Nombre de la herramienta [id] ("thieves-tools" → "Herramientas de ladrón").
String toolProficiencyLabel(String id) => _toolLabels[id] ?? titleCaseId(id);

/// El nombre español de una herramienta conocida, o null si el id no es una.
///
/// A diferencia de [toolProficiencyLabel], que siempre devuelve algo, esto
/// distingue "no la conozco" de "se llama así". Lo usan el generador del
/// catálogo de objetos —para que el objeto y la competencia compartan nombre
/// además de id— y la ficha, para marcar en la fila si sos competente.
String? knownToolLabel(String id) => _toolLabels[id];

/// Herramientas concretas que se pueden elegir, sin las entradas genéricas.
///
/// `artisans-tools`, `gaming-set` y `musical-instrument` quedan afuera a
/// propósito: no son herramientas sino "una de esta familia a tu elección", y
/// ofrecerlas como opción dejaría al personaje con una competencia que no
/// nombra nada. Las usa el contenido, no el selector.
List<String> get toolProficiencyIds => [
      for (final id in _toolLabels.keys)
        if (id != 'artisans-tools' &&
            id != 'gaming-set' &&
            id != 'musical-instrument')
          id,
    ];

/// Expande las entradas de familia que usa el contenido a herramientas reales.
List<String> expandToolProficiencyChoices(Iterable<String> ids) {
  final result = <String>[];
  for (final id in ids) {
    final expanded = switch (id) {
      'artisans-tools' => artisanToolProficiencyIds,
      'gaming-set' => gamingSetProficiencyIds,
      'musical-instrument' => musicalInstrumentProficiencyIds,
      _ => [id],
    };
    for (final option in expanded) {
      if (!result.contains(option)) result.add(option);
    }
  }
  return result;
}
