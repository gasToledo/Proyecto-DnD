import 'dart:typed_data';

/// Tipos de imagen admitidos para un retrato, con la extensión que se usa al
/// guardar el blob y el `content-type` con el que se sirve.
enum PortraitImageType {
  png('png', 'image/png'),
  jpeg('jpg', 'image/jpeg'),
  webp('webp', 'image/webp');

  final String extension;
  final String contentType;

  const PortraitImageType(this.extension, this.contentType);
}

/// Reconoce el tipo de imagen por su cabecera de bytes (no por la extensión
/// declarada por quien sube el archivo, que no es de fiar). Devuelve `null`
/// si no es ninguno de los formatos admitidos.
PortraitImageType? sniffPortraitImageType(Uint8List bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A) {
    return PortraitImageType.png;
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return PortraitImageType.jpeg;
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return PortraitImageType.webp;
  }
  return null;
}

/// Tipo esperado a partir de la extensión con la que se guardó el blob
/// (`.png`, `.jpg`, `.webp`, con o sin punto inicial). Se usa al servir un
/// retrato ya guardado, cuyo tipo fue validado al escribirlo.
PortraitImageType? portraitImageTypeForExtension(String extension) {
  final normalized = extension.startsWith('.')
      ? extension.substring(1)
      : extension;
  for (final type in PortraitImageType.values) {
    if (type.extension == normalized) return type;
  }
  return null;
}
