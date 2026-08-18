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

/// `true` si [value] tiene forma de UUID.
///
/// Los ids de vínculo entre campaña y personaje son UUID generados por la base,
/// y viajan en la URL. Uno mal formado no puede llegar a la consulta: Postgres
/// lo rechazaría con un error de tipo, que se traduciría en un 500 cuando en
/// realidad es un identificador que no existe. Comprobarlo antes deja
/// responder 404, sin distinguir "no existe" de "no es tuyo".
bool isUuid(String value) => RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
).hasMatch(value);
