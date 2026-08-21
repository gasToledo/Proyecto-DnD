/// Las condiciones de las reglas 2024, con lo que le hacen a quien las
/// sufre.
///
/// Viven acá y no adentro de una pantalla porque las miran dos: el gestor de
/// estados de la ficha del jugador —donde se marcan sobre el propio personaje
/// y sobre sus compañeros invocados— y los tags del combate del Modo DM, que
/// las ofrece como atajo.
///
/// El texto es del libro y no un resumen propio: en la mesa se lee para
/// resolver una discusión, así que acortarlo le sacaría justo lo que sirve.
library;

/// Una condición: cómo se llama y qué le hace a quien la sufre.
class ConditionInfo {
  final String label;
  final String description;
  const ConditionInfo(this.label, this.description);
}

const conditions = <String, ConditionInfo>{
  'blinded': ConditionInfo(
    'Cegado',
    'No podés ver y fallás automáticamente cualquier prueba que requiera vista. '
        'Los ataques contra vos tienen ventaja, y tus ataques tienen desventaja.',
  ),
  'charmed': ConditionInfo(
    'Hechizado',
    'No podés atacar a quien te hechizó ni dirigirle habilidades u efectos '
        'dañinos. Esa criatura tiene ventaja en pruebas sociales contra vos.',
  ),
  'deafened': ConditionInfo(
    'Ensordecido',
    'No podés oír y fallás automáticamente cualquier prueba que requiera oído.',
  ),
  'frightened': ConditionInfo(
    'Asustado',
    'Tenés desventaja en pruebas de característica y ataques mientras la '
        'fuente de tu miedo esté a la vista. No podés acercarte voluntariamente a ella.',
  ),
  'grappled': ConditionInfo(
    'Agarrado',
    'Tu velocidad se vuelve 0 y no podés beneficiarte de ningún bonus a la '
        'velocidad. La condición termina si quien te agarra queda incapacitado.',
  ),
  'incapacitated': ConditionInfo(
    'Incapacitado',
    'No podés realizar acciones ni reacciones. (En 2024 tampoco te movés ni hablás.)',
  ),
  'invisible': ConditionInfo(
    'Invisible',
    'Sos imposible de ver sin magia o sentidos especiales. A efectos de '
        'esconderte, se te considera fuertemente oscurecido. Tus ataques tienen '
        'ventaja; los ataques contra vos tienen desventaja.',
  ),
  'paralyzed': ConditionInfo(
    'Paralizado',
    'Estás incapacitado y no podés moverte ni hablar. Fallás automáticamente '
        'las salvaciones de Fuerza y Destreza. Los ataques contra vos tienen '
        'ventaja, y todo impacto cuerpo a cuerpo es crítico si el atacante está a 5 pies.',
  ),
  'petrified': ConditionInfo(
    'Petrificado',
    'Te transformás en sustancia sólida inanimada (junto a tu equipo). '
        'Incapacitado, no podés moverte ni hablar, sos inconsciente de tu entorno. '
        'Los ataques contra vos tienen ventaja, fallás salvaciones de Fuerza y '
        'Destreza, tenés resistencia a todo el daño e inmunidad a veneno y enfermedad.',
  ),
  'poisoned': ConditionInfo(
    'Envenenado',
    'Tenés desventaja en tiradas de ataque y en pruebas de característica.',
  ),
  'prone': ConditionInfo(
    'Derribado',
    'Solo podés moverte arrastrándote (o levantarte). Tenés desventaja al '
        'atacar. Los ataques cuerpo a cuerpo contra vos tienen ventaja; los '
        'ataques a distancia contra vos tienen desventaja.',
  ),
  'restrained': ConditionInfo(
    'Apresado',
    'Tu velocidad se vuelve 0. Los ataques contra vos tienen ventaja y tus '
        'ataques tienen desventaja. Tenés desventaja en salvaciones de Destreza.',
  ),
  'stunned': ConditionInfo(
    'Aturdido',
    'Estás incapacitado, no podés moverte y hablás solo entrecortadamente. '
        'Fallás automáticamente las salvaciones de Fuerza y Destreza. Los '
        'ataques contra vos tienen ventaja.',
  ),
  'unconscious': ConditionInfo(
    'Inconsciente',
    'Estás incapacitado, no podés moverte ni hablar, y no sos consciente de tu '
        'entorno. Soltás lo que sostenías y caés derribado. Fallás automáticamente '
        'las salvaciones de Fuerza y Destreza. Los ataques contra vos tienen '
        'ventaja, y todo impacto cuerpo a cuerpo es crítico si el atacante está a 5 pies.',
  ),
};
