import 'name_sort.dart';

/// Los 13 tipos de daño de 5e, con su nombre en español según la tabla "Tipos
/// de daño" del PHB 2024.
///
/// El contenido los referencia por [id] en inglés, que es la clave estable que
/// viaja en los JSON y en los personajes guardados; este enum es la única
/// fuente de la traducción, para que no se repartan por la UI.
enum DamageType {
  acid('acid', 'Ácido', 'Líquidos corrosivos y enzimas digestivas.'),
  bludgeoning(
    'bludgeoning',
    'Contundente',
    'Golpes con objetos romos, constricción y caídas.',
  ),
  cold('cold', 'Frío', 'Agua helada y ráfagas gélidas.'),
  fire('fire', 'Fuego', 'Llamas y calor insoportable.'),
  force('force', 'Fuerza', 'Energía mágica pura.'),
  lightning('lightning', 'Relámpago', 'Electricidad.'),
  necrotic('necrotic', 'Necrótico', 'Energía que drena la vida.'),
  piercing('piercing', 'Perforante', 'Colmillos y objetos punzantes.'),
  poison('poison', 'Veneno', 'Gases tóxicos y venenos.'),
  psychic('psychic', 'Psíquico', 'Energía que desgarra la mente.'),
  radiant('radiant', 'Radiante', 'Energía sagrada y radiación abrasadora.'),
  slashing('slashing', 'Cortante', 'Garras y objetos filosos.'),
  thunder('thunder', 'Trueno', 'Sonido que golpea como una onda expansiva.');

  const DamageType(this.id, this.label, this.description);
  final String id;
  final String label;

  /// Qué lo causa, con los ejemplos de la tabla del PHB. Sirve para elegir el
  /// tipo de un arma o de un conjuro propio: el nombre solo («Necrótico») no
  /// dice de dónde sale.
  final String description;

  static DamageType? fromId(String id) {
    for (final t in values) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Nombre para mostrar. Si el id no está en el catálogo devuelve el id
  /// capitalizado en vez de fallar: `ImmunityEffect` también se usa hoy para
  /// inmunidad a **estados** (el Artífice es inmune a `poisoned`), y el
  /// homebrew puede traer cualquier cosa.
  static String labelFor(String id) =>
      fromId(id)?.label ?? _conditionLabels[id] ?? titleCaseId(id);
}

/// Lo que el tipo de daño cambia en la mesa, que vale igual para los trece: no
/// va en cada [DamageType.description] para no repetirlo trece veces.
const damageTypeRule =
    'No cambia cuánto pega, sino a quién le entra: hay criaturas que lo '
    'resisten y reciben la mitad, otras inmunes y otras vulnerables, que '
    'reciben el doble.';

/// Estados que hoy viajan por el mismo campo que los tipos de daño. Separarlos
/// en un efecto propio exigiría migrar contenido y personajes; mientras tanto,
/// al menos se muestran en español.
const _conditionLabels = <String, String>{
  'blinded': 'Cegado',
  'charmed': 'Encantado',
  'deafened': 'Ensordecido',
  'frightened': 'Asustado',
  'grappled': 'Agarrado',
  'incapacitated': 'Incapacitado',
  'paralyzed': 'Paralizado',
  'petrified': 'Petrificado',
  'poisoned': 'Envenenado',
  'prone': 'Derribado',
  'restrained': 'Apresado',
  'stunned': 'Aturdido',
  'unconscious': 'Inconsciente',
};
