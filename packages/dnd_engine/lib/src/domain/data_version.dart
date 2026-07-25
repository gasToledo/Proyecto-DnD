class UnsupportedDataVersionException implements Exception {
  final String dataType;
  final int found;
  final int supported;

  const UnsupportedDataVersionException({
    required this.dataType,
    required this.found,
    required this.supported,
  });

  @override
  String toString() =>
      'La versión $found de $dataType es más nueva que la versión '
      '$supported compatible con esta aplicación.';
}
