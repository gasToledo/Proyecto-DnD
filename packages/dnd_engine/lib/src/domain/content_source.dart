/// Origen del contenido. Oficial y homebrew comparten estructura; solo cambia
/// esta etiqueta (y de qué edición proviene lo oficial).
///
/// `srd2024` es lo licenciable bajo CC BY 4.0. `phb2024` es contenido oficial
/// del Player's Handbook 2024 que **no** está en el SRD 5.2.1 y por lo tanto no
/// queda cubierto por esa atribución: la distinción es de licencia, no cosmética.
/// `foa2025` es *Forge of the Artificer*, una expansión aparte: tampoco está en
/// el SRD, y además el jugador necesita ver que una opción viene de otro libro
/// antes de comprometer un personaje con ella.
///
/// Vive en su propio archivo, y no junto a `Race` y compañía, porque también lo
/// necesitan los efectos: `FeatureChoiceEffect` declara opciones en línea que
/// llevan procedencia, y `content.dart` ya importa `effects.dart`.
enum ContentSource {
  srd2024,
  phb2024,
  foa2025,
  srd2014,
  homebrew;

  /// Un valor desconocido degrada a [homebrew] a propósito: este parser también
  /// procesa importaciones, que se tratan como datos no confiables y no deben
  /// hacer fallar la carga. La red de seguridad del contenido oficial es
  /// `content_integrity_test.dart`, no una excepción en tiempo de carga.
  static ContentSource fromJson(String? v) => switch (v) {
        'srd_2024' => ContentSource.srd2024,
        'phb_2024' => ContentSource.phb2024,
        'foa_2025' => ContentSource.foa2025,
        'srd_2014' => ContentSource.srd2014,
        'homebrew' => ContentSource.homebrew,
        _ => ContentSource.homebrew,
      };

  String toJson() => switch (this) {
        ContentSource.srd2024 => 'srd_2024',
        ContentSource.phb2024 => 'phb_2024',
        ContentSource.foa2025 => 'foa_2025',
        ContentSource.srd2014 => 'srd_2014',
        ContentSource.homebrew => 'homebrew',
      };
}
