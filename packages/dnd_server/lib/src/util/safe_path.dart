/// Verifica un segmento que se va a usar como nombre de archivo o directorio.
///
/// Los datos que llegan del cliente (claves de retrato, ids dentro de un
/// respaldo importado) son datos externos: no deben poder escapar del
/// espacio de la cuenta mediante `..` o separadores de ruta.
String requireSafePathSegment(String value, {String label = 'identificador'}) {
  if (value.isEmpty ||
      value == '.' ||
      value == '..' ||
      !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(value)) {
    throw FormatException('El $label contiene caracteres no permitidos.');
  }
  return value;
}
