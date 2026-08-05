/// Resuelve el id con el que un documento se guarda dentro de una cuenta.
///
/// Si [requestedId] ya está en uso (creación con un id repetido, o
/// importación de un respaldo cuyo id choca con uno existente), se asigna uno
/// libre generado por [fallbackId] en vez de sobrescribir el documento que ya
/// existía. Nunca se sobrescribe: la garantía es la misma que ya usaba
/// `transfer_service.dart` en la aplicación de escritorio.
String resolveStorageId({
  required String requestedId,
  required Set<String> existingIds,
  required String Function() fallbackId,
}) {
  if (!existingIds.contains(requestedId)) return requestedId;
  String candidate;
  do {
    candidate = fallbackId();
  } while (existingIds.contains(candidate));
  return candidate;
}
