/// Los 13 tipos de daño de 5e, con su nombre en español según la tabla "Tipos
/// de daño" del PHB 2024.
///
/// El contenido los referencia por [id] en inglés, que es la clave estable que
/// viaja en los JSON y en los personajes guardados; este enum es la única
/// fuente de la traducción, para que no se repartan por la UI.
enum DamageType {
  acid('acid', 'Ácido'),
  bludgeoning('bludgeoning', 'Contundente'),
  cold('cold', 'Frío'),
  fire('fire', 'Fuego'),
  force('force', 'Fuerza'),
  lightning('lightning', 'Relámpago'),
  necrotic('necrotic', 'Necrótico'),
  piercing('piercing', 'Perforante'),
  poison('poison', 'Veneno'),
  psychic('psychic', 'Psíquico'),
  radiant('radiant', 'Radiante'),
  slashing('slashing', 'Cortante'),
  thunder('thunder', 'Trueno');

  const DamageType(this.id, this.label);
  final String id;
  final String label;

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
      fromId(id)?.label ?? _conditionLabels[id] ?? _titleCase(id);
}

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

String _titleCase(String s) => s.isEmpty
    ? s
    : s
        .split(RegExp(r'[-_ ]'))
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
