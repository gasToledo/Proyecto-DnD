import 'name_sort.dart';

/// Los idiomas del SRD 5.2.1, con su nombre en español.
///
/// El contenido los referencia por [id] en inglés, que es la clave estable que
/// viaja en JSON y en los personajes guardados; la traducción vive solo acá,
/// igual que en [Skill] y en `damage_type.dart`.
///
/// La regla 2024 los separa en dos tablas y la diferencia es mecánica, no
/// decorativa: **los dos idiomas que elige el jugador al crear el personaje
/// salen de los estándar**, y los inusuales llegan solo por un rasgo
/// ("Algunos rasgos permiten a los personajes aprender un idioma inusual").
enum Language {
  // --- Estándar: los que puede elegir cualquier personaje al crearse. ---
  //
  // Común va primero porque todo personaje lo sabe y no ocupa una de las dos
  // elecciones.
  common('common', 'Común', standard: true),
  draconic('draconic', 'Dracónico', standard: true),
  dwarvish('dwarvish', 'Enano', standard: true),
  elvish('elvish', 'Elfo', standard: true),
  giant('giant', 'Gigante', standard: true),
  gnomish('gnomish', 'Gnomo', standard: true),
  goblin('goblin', 'Goblin', standard: true),
  halfling('halfling', 'Mediano', standard: true),
  orc('orc', 'Orco', standard: true),
  commonSignLanguage(
    'common-sign-language',
    'Lengua de signos común',
    standard: true,
  ),

  // --- Inusuales: secretos o de otros planos. Solo por rasgo. ---
  abyssal('abyssal', 'Abisal'),
  celestial('celestial', 'Celestial'),
  deepSpeech('deep-speech', 'Habla de las profundidades'),
  druidic('druidic', 'Druídico'),
  infernal('infernal', 'Infernal'),

  /// Incluye los dialectos acuano, aurano, ígneo y terrano, que se entienden
  /// entre sí. Va como una sola entrada porque así lo presenta la tabla del
  /// SRD y porque mecánicamente son el mismo idioma.
  primordial('primordial', 'Primordial'),

  sylvan('sylvan', 'Silvano'),
  thievesCant('thieves-cant', 'Jerga de ladrones'),
  undercommon('undercommon', 'Infracomún');

  const Language(this.id, this.label, {this.standard = false});

  /// Id usado por el contenido JSON y por los personajes guardados.
  final String id;

  /// Nombre en español, para la UI.
  final String label;

  /// Si figura en la tabla "Idiomas estándar" y por lo tanto se puede elegir
  /// al crear el personaje.
  final bool standard;

  /// Idioma que todo personaje sabe sin gastar una elección.
  static const Language universal = Language.common;

  /// Cuántos idiomas elige el jugador además de Común.
  ///
  /// Vive en el motor y no en el contenido a propósito: no lo concede una
  /// especie ni un trasfondo, es una regla del paso de origen que vale para
  /// todo personaje ("Tu personaje sabe al menos tres idiomas: común y otros
  /// dos"). Ponerlo en un JSON sugeriría que alguna opción puede cambiarlo.
  static const int originChoiceCount = 2;

  /// Los elegibles al crear el personaje: los estándar menos Común, que ya se
  /// sabe y no debe gastar una de las dos elecciones.
  static List<Language> get originChoices => [
        for (final l in Language.values)
          if (l.standard && l != universal) l,
      ];

  static List<String> get allIds => [for (final l in Language.values) l.id];

  static Language? fromId(String id) {
    for (final l in Language.values) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// Nombre para mostrar. Un id que no está en el catálogo (homebrew) cae al
  /// id capitalizado en vez de fallar, misma red que [Skill.labelFor].
  static String labelFor(String id) => fromId(id)?.label ?? titleCaseId(id);
}
