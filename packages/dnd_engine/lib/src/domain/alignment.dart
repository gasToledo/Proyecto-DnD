/// Alineamiento clásico (eje legal–caótico × bueno–malvado).
///
/// Es un dato **de sabor**: no participa del compilado de la ficha ni de
/// ninguna regla; solo se muestra y se exporta. Se llama `CharacterAlignment`
/// y no `Alignment` para no chocar con el `Alignment` de Flutter en la app.
enum CharacterAlignment {
  lawfulGood('Legal Bueno'),
  neutralGood('Neutral Bueno'),
  chaoticGood('Caótico Bueno'),
  lawfulNeutral('Legal Neutral'),
  trueNeutral('Neutral'),
  chaoticNeutral('Caótico Neutral'),
  lawfulEvil('Legal Malvado'),
  neutralEvil('Neutral Malvado'),
  chaoticEvil('Caótico Malvado');

  const CharacterAlignment(this.label);

  /// Nombre en español, para la UI.
  final String label;

  String toJson() => name;

  /// Tolerante: ausente o desconocido devuelve null (las fichas anteriores a
  /// este campo simplemente no lo traen).
  static CharacterAlignment? fromJson(String? v) {
    if (v == null) return null;
    for (final a in CharacterAlignment.values) {
      if (a.name == v) return a;
    }
    return null;
  }
}
