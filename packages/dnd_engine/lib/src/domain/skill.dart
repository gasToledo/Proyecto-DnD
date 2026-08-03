import 'ability.dart';
import 'name_sort.dart';

/// Las 18 habilidades de 5e (SRD 5.2), con su nombre en español y la
/// característica que las gobierna.
///
/// El contenido (clases, especies, trasfondos) referencia habilidades por [id];
/// este enum es la única fuente de la traducción y del vínculo con la
/// característica, para que no se repartan por la UI.
enum Skill {
  acrobatics('acrobatics', 'Acrobacias', Ability.dexterity),
  animalHandling('animal-handling', 'Trato con Animales', Ability.wisdom),
  arcana('arcana', 'Arcanos', Ability.intelligence),
  athletics('athletics', 'Atletismo', Ability.strength),
  deception('deception', 'Engaño', Ability.charisma),
  history('history', 'Historia', Ability.intelligence),
  insight('insight', 'Perspicacia', Ability.wisdom),
  intimidation('intimidation', 'Intimidación', Ability.charisma),
  investigation('investigation', 'Investigación', Ability.intelligence),
  medicine('medicine', 'Medicina', Ability.wisdom),
  nature('nature', 'Naturaleza', Ability.intelligence),
  perception('perception', 'Percepción', Ability.wisdom),
  performance('performance', 'Interpretación', Ability.charisma),
  persuasion('persuasion', 'Persuasión', Ability.charisma),
  religion('religion', 'Religión', Ability.intelligence),
  sleightOfHand('sleight-of-hand', 'Juego de Manos', Ability.dexterity),
  stealth('stealth', 'Sigilo', Ability.dexterity),
  survival('survival', 'Supervivencia', Ability.wisdom);

  const Skill(this.id, this.label, this.ability);

  /// Id usado por el contenido JSON (p.ej. `sleight-of-hand`).
  final String id;

  /// Nombre en español, para la UI.
  final String label;

  /// Característica que gobierna la habilidad.
  final Ability ability;

  /// Todos los ids, en el orden del enum.
  static List<String> get allIds => [for (final s in Skill.values) s.id];

  /// Habilidad por id, o null si no es una de las 18 (p.ej. una inventada por
  /// contenido homebrew).
  static Skill? fromId(String id) {
    for (final s in Skill.values) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Nombre para mostrar. Si el id no está en el catálogo (homebrew), devuelve
  /// el id capitalizado en vez de fallar.
  static String labelFor(String id) => fromId(id)?.label ?? titleCaseId(id);
}
