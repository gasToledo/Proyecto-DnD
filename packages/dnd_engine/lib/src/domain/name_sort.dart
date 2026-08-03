/// Ordenamiento alfabético de nombres de contenido, en español.
///
/// `String.compareTo` compara unidades UTF-16, así que deja las vocales
/// acentuadas después de la Z: con él "Bárbaro" cae detrás de "Brujo" y
/// "Látigo" detrás de "Lucero del alba". Como el catálogo está íntegramente en
/// español, esa comparación cruda no sirve para ninguna lista que vea el
/// usuario.
library;

/// Equivalencias para el plegado. Las vocales acentuadas valen por su vocal
/// base porque en español la tilde es prosódica, no alfabética.
///
/// La Ñ sí es letra propia y va **detrás** de la N, así que se ancla al final
/// del tramo de la N: `￿` supera a cualquier letra, de modo que "añejo"
/// queda después de "anzuelo" pero antes de "ao".
const _folded = <String, String>{
  'á': 'a',
  'à': 'a',
  'ä': 'a',
  'â': 'a',
  'ã': 'a',
  'é': 'e',
  'è': 'e',
  'ë': 'e',
  'ê': 'e',
  'í': 'i',
  'ì': 'i',
  'ï': 'i',
  'î': 'i',
  'ó': 'o',
  'ò': 'o',
  'ö': 'o',
  'ô': 'o',
  'õ': 'o',
  'ú': 'u',
  'ù': 'u',
  'ü': 'u',
  'û': 'u',
  'ç': 'c',
  'ñ': 'n￿',
};

String _sortKey(String value) {
  final buffer = StringBuffer();
  for (final char in value.toLowerCase().split('')) {
    buffer.write(_folded[char] ?? char);
  }
  return buffer.toString();
}

/// Compara dos nombres como los ordenaría un hispanohablante: sin distinguir
/// mayúsculas y tratando la vocal acentuada como su vocal base.
///
/// Ante un empate tras plegar ("Publico" vs "Público") desempata con el texto
/// original, para que el orden sea total y determinista: dos nombres distintos
/// nunca comparan igual, así el resultado no depende del orden de entrada.
int compareContentNames(String a, String b) {
  final byKey = _sortKey(a).compareTo(_sortKey(b));
  return byKey != 0 ? byKey : a.compareTo(b);
}

/// Devuelve [items] ordenados por el nombre que expone [name].
List<T> sortedByName<T>(Iterable<T> items, String Function(T) name) =>
    items.toList()..sort((a, b) => compareContentNames(name(a), name(b)));
