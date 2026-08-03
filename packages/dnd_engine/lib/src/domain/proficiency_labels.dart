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
  'herbalism-kit': 'Útiles de herborista',
  'musical-instrument': 'Instrumento musical',
  'navigators-tools': 'Herramientas de navegante',
  'poisoner-kit': 'Útiles de envenenador',
  'thieves-tools': 'Herramientas de ladrón',
};

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
