/// Qué significa cada elección de los formularios homebrew que no es un arma
/// (esas tienen su glosario en `weapon_properties.dart` y
/// `weapon_mastery.dart`).
///
/// Quien arma su primera armadura o su primer conjuro elige «Media» o
/// «Evocación» sin saber qué cambia, y el formulario se lo explica con estos
/// textos. Viven en el motor por el mismo motivo que los de arma: son reglas
/// del PHB 2024, no redacción de una pantalla, y así no se reparten por la UI.
///
/// Es **descriptivo**: el compilador no lee nada de acá. Las claves son los ids
/// que viajan en los datos (`medium`, `origin`, `Evocación`).
library;

// ---------------------------------------------------------------- Armadura

const Map<String, String> armorCategoryRules = {
  'light':
      'Suma la Destreza entera. Ponérsela lleva 1 minuto y quitársela, otro.',
  'medium':
      'Suma la Destreza hasta un tope, que en el manual es +2. Ponérsela lleva '
          '5 minutos y quitársela, 1.',
  'heavy':
      'No suma Destreza, y suele exigir Fuerza. Ponérsela lleva 10 minutos y '
          'quitársela, 5.',
  'shield':
      'Se empuña en una mano y su CA se suma a la de la armadura. Ponérselo o '
          'quitárselo es la acción de Utilizar.',
};

/// Lo que vale para las cuatro categorías de armadura.
const armorTrainingRule =
    'Sin entrenamiento con la categoría, toda prueba d20 con Fuerza o Destreza '
    'tiene desventaja y no se pueden lanzar conjuros.';

const armorBaseAcRule =
    'La CA de quien la lleva antes de sumar Destreza. Sin armadura, la base '
    'es 10.';

const shieldBaseAcRule = 'Lo que el escudo suma a la CA de quien lo empuña.';

const armorAddDexRule =
    'Encendido, la CA suma el modificador de Destreza. Apagado, la CA es la '
    'base sola, como en una armadura pesada.';

const armorMaxDexRule =
    'La Destreza suma hasta este tope, nunca más. Vacío, suma entera, como en '
    'una armadura ligera.';

const armorStrengthRule =
    'Quien la lleve puesta sin llegar a esa Fuerza pierde 10 pies de '
    'velocidad.';

const armorStealthRule =
    'Las pruebas de Destreza (Sigilo) de quien la lleve puesta tienen '
    'desventaja.';

// ----------------------------------------------------------------- Conjuro

const spellCantripRule =
    'Se lanza a voluntad, sin gastar espacios de conjuro. Suele hacer más '
    'daño a medida que el personaje sube de nivel.';

String spellLevelRule(int level) =>
    'Lanzarlo gasta un espacio de conjuro de nivel $level o superior. Muchos '
    'hacen más si se lanzan con un espacio mayor.';

/// Las ocho escuelas, por su nombre en español: es lo que guarda
/// `Spell.school` en el catálogo.
const Map<String, String> spellSchoolRules = {
  'Abjuración': 'Protege, bloquea y destierra.',
  'Adivinación': 'Revela información: lo oculto, lo lejano, lo que vendrá.',
  'Conjuración': 'Trae criaturas u objetos, o traslada de un lugar a otro.',
  'Encantamiento': 'Influye en la mente de otros.',
  'Evocación': 'Crea energía: fuego, relámpago, fuerza, también curación.',
  'Ilusionismo': 'Engaña los sentidos o la mente.',
  'Nigromancia': 'Manipula la vida y la muerte.',
  'Transmutación': 'Cambia las propiedades de una criatura, un objeto o un '
      'lugar.',
};

const spellSchoolNote =
    'La escuela no cambia cómo funciona el conjuro, pero la miran algunas '
    'reglas y subclases.';

/// Tiempos de lanzamiento, por el texto que guarda `Spell.castingTime`.
///
/// Los que tardan más de un turno comparten [spellLongCastingRule].
const Map<String, String> spellCastingTimeRules = {
  'Acción': 'Ocupa la acción del turno.',
  'Acción Adicional':
      'Ocupa la acción adicional del turno. Ese turno no se puede gastar otro '
          'espacio de conjuro en otro conjuro.',
  'Reacción': 'Se lanza fuera del turno propio, en respuesta a algo. Lo que lo '
      'dispara va en la descripción.',
};

const spellLongCastingRule =
    'Tarda más que un turno: hay que mantener la concentración mientras se '
    'lanza, así que rara vez sirve en combate.';

const Map<String, String> spellComponentRules = {
  'V': 'Hay que poder hablar: amordazado o en un silencio mágico, no se lanza.',
  'S': 'Hay que tener una mano libre para gesticular.',
  'M': 'Hace falta el material nombrado, o en su lugar un canalizador o una '
      'bolsa de componentes, salvo que tenga precio o se consuma.',
};

const spellConcentrationRule =
    'Mientras dura hay que concentrarse: recibir daño pide una salvación de '
    'Constitución, y empezar otro conjuro de concentración termina este.';

const spellRitualRule =
    'Se puede lanzar como ritual: tarda 10 minutos más y no gasta espacio de '
    'conjuro.';

const spellClassesRule =
    'Las clases en cuya lista aparece: solo esas lo pueden preparar.';

// -------------------------------------------------------------------- Dote

const Map<String, String> featCategoryRules = {
  'origin':
      'La que concede un trasfondo a nivel 1. No tienen requisitos de nivel.',
  'general': 'Se toman al subir de nivel desde el 4, en lugar del aumento de '
      'característica.',
  'fighting-style':
      'Solo para quien tiene el rasgo Estilo de combate: guerreros, paladines '
          'y exploradores.',
  'dragonmark':
      'Las marcas de Eberron. Se toman como dote de origen, en lugar de la '
          'del trasfondo.',
  'epic-boon': 'Para personajes de nivel 19 o más.',
};

const featRepeatableRule =
    'Se puede tomar más de una vez. Sin marcar, una vez elegida deja de '
    'ofrecerse.';

// ------------------------------------------------------- Especie y trasfondo

const raceCreatureTypeRule =
    'Es lo que miran los conjuros y rasgos que solo afectan a un tipo, como '
    'Hechizar persona a los humanoides.';

/// Tamaños de especie, por el texto que guarda `Race.size`.
const Map<String, String> raceSizeRules = {
  'Pequeño': 'Ocupa un espacio de 5 pies, como un Mediano.',
  'Mediano': 'Ocupa un espacio de 5 pies.',
  'Grande': 'Ocupa un espacio de 10 pies.',
};

const sizeRule =
    'El tamaño decide cuánto espacio ocupa y a quién puede agarrar o empujar: '
    'hasta un tamaño más grande que el propio.';

const raceSpeedRule =
    'Lo que se mueve en un turno, antes de que la armadura o un rasgo la '
    'cambien.';

const raceSkillCountRule =
    'Cuántas competencias en habilidad elige el jugador al crear el personaje.';

const raceSkillFromRule =
    'Sin marcar ninguna, el jugador elige entre las 18. Marcando algunas, la '
    'elección queda limitada a esas.';

const raceSizeOptionsRule =
    'Marcando dos o más, el jugador elige el tamaño de su personaje. Con uno '
    'o ninguno vale el tamaño de arriba.';

const skillProficiencyRule =
    'Ser competente suma el bonificador de competencia a las pruebas de esa '
    'habilidad.';

const toolProficiencyRule =
    'Ser competente suma el bonificador de competencia a las pruebas con esa '
    'herramienta.';

const backgroundAbilitiesRule =
    'Al crear el personaje, el jugador reparte +2 a una y +1 a otra de estas '
    'tres, o +1 a cada una. Por eso tienen que ser exactamente tres.';

const backgroundOriginFeatRule =
    'La dote que el trasfondo concede a nivel 1. Solo se ofrecen las de '
    'origen.';

// ------------------------------------------------------------------ Objeto

const Map<String, String> itemCategoryRules = {
  'gear': 'Equipo de aventurero: lo que no entra en otra familia.',
  'tool': 'Se usa en pruebas de característica, y con competencia suma el '
      'bonificador.',
  'ammunition': 'Lo que gastan las armas con la propiedad Munición.',
  'focus':
      'Reemplaza los componentes materiales sin precio al lanzar conjuros.',
  'pack': 'Varios objetos que se compran juntos.',
  'container': 'Guarda otros objetos adentro.',
};

const itemCategoryNote =
    'La categoría ordena el inventario. Lo que hace mágico a un objeto es la '
    'rareza.';

const itemMundaneRule =
    'Sin rareza es un objeto común y corriente, y no se puede sintonizar.';

const itemRarityRule =
    'Tener rareza es lo que lo hace mágico. Orienta cuánto vale y a qué nivel '
    'conviene entregarlo.';

const itemAttunementRule =
    'Solo da sus efectos a quien se sintonizó con él, en un descanso corto. '
    'Cada personaje mantiene hasta tres objetos sintonizados a la vez.';

const itemAcBonusRule =
    'Suma a la Clase de Armadura mientras esté equipado, y sintonizado si lo '
    'exige.';

const itemResistanceRule =
    'Con las mismas condiciones, el daño de ese tipo que recibe el personaje '
    'se reduce a la mitad.';

const itemBaseRule =
    'Con base, el objeto es una plantilla: al agregarlo se elige el arma, la '
    'armadura o el escudo sobre el que va, y hereda sus números.';

const itemMagicBonusRule =
    'Se suma al ataque y al daño del arma base, o a la CA de la armadura o el '
    'escudo.';

// ---------------------------------------------------------------- Criatura

const creatureTypeRule =
    'Es lo que miran los conjuros y rasgos que afectan a un tipo de criatura.';

const creatureBeastNote =
    'Es el único tipo que puede aparecer entre las formas de Forma Salvaje del '
    'druida.';

/// Espacio que ocupa cada tamaño, por el id de `CreatureSize`.
const Map<String, String> creatureSizeRules = {
  'tiny': 'Ocupa un espacio de 2,5 pies.',
  'small': 'Ocupa un espacio de 5 pies.',
  'medium': 'Ocupa un espacio de 5 pies.',
  'large': 'Ocupa un espacio de 10 pies.',
  'huge': 'Ocupa un espacio de 15 pies.',
  'gargantuan': 'Ocupa un espacio de 20 pies o más.',
};

const creatureCrRule =
    'Cuán peligrosa es: una de VD igual al nivel del grupo es un combate '
    'parejo para cuatro personajes. Fija su bonificador de competencia y la '
    'experiencia que da.';

const creatureAttackBonusRule =
    'Lo que se suma al d20 para acertar. Vacío si la acción no es un ataque '
    '—un aliento con salvación, un aullido—: el perfil la muestra como texto.';

/// Cuándo se usa una acción de criatura, por el id de `CreatureActionKind`.
const Map<String, String> creatureActionKindRules = {
  'action': 'Ocupa la acción del turno.',
  'bonus': 'Ocupa la acción adicional del turno.',
  'reaction': 'Se usa fuera del turno propio, en respuesta a algo.',
  'legendary':
      'Se usa al terminar el turno de otra criatura, gastando de las acciones '
          'legendarias por ronda.',
};
