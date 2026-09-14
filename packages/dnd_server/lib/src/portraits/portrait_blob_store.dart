import 'dart:typed_data';

/// Bytes de un retrato ya leído, con el `content-type` a usar en la
/// respuesta.
class PortraitBlob {
  final Uint8List bytes;
  final String contentType;

  const PortraitBlob(this.bytes, this.contentType);
}

/// Contrato de almacenamiento de blobs de retrato: detrás de esta interfaz
/// se puede cambiar el medio de almacenamiento (disco, almacén de objetos)
/// sin modificar la API ni el cliente (ver capacidad `portrait-storage`).
///
/// **No todo lo que hay bajo un personaje es un retrato.** Las imágenes del
/// Diario (`DiaryEntry.imageKey`) se guardan acá mismo, con este [save], para
/// no estrenar un almacén paralelo que repitiera la validación de tipo y
/// tamaño y la cascada de borrado.
///
/// Lo que las mantiene separadas no es la carpeta sino **el documento**: el
/// selector de retratos se dibuja desde `Character.portraitPaths`, una imagen
/// del Diario nunca entra en esa lista, y no existe ninguna ruta que liste la
/// carpeta — así que el cliente no puede descubrir un blob que la ficha no
/// nombre.
///
/// Consecuencia para quien escriba algo nuevo acá: **enumerar la carpeta y
/// tratar lo que aparezca como retratos está mal**; hay que ir por las claves
/// que la ficha nombra. [deleteAllFor] es la excepción deliberada, y es lo que
/// hace que borrar un personaje se lleve las dos cosas sin código extra.
abstract class PortraitBlobStore {
  int get maxBytes;

  /// Guarda [bytes] como un retrato nuevo de [characterId] dentro del
  /// espacio de [userId] y devuelve la clave opaca (`<characterId>/<archivo>`)
  /// que se guarda en `Character.portraitPaths`.
  ///
  /// Lanza [FormatException] si el tamaño supera el límite configurado o si
  /// los bytes no corresponden a ninguno de los tipos de imagen admitidos.
  Future<String> save({
    required String userId,
    required String characterId,
    required Uint8List bytes,
  });

  /// Lee el retrato de [portraitKey] dentro del espacio de [userId]. Devuelve
  /// `null` si no existe, incluido el caso en que la clave pertenece a otra
  /// cuenta: la ausencia y el acceso cruzado no deben distinguirse en la
  /// respuesta.
  ///
  /// Con [width] devuelve una miniatura de ese ancho en vez del original. El
  /// cliente dibuja los retratos en medallones de menos de cien píxeles y los
  /// originales son de 768 o 1024 de lado: reducir eso en el navegador no
  /// funciona —la implementación web de `NetworkImage` no sabe decodificar a
  /// un tamaño dado, así que el remuestreo lo termina haciendo la GPU en un
  /// solo salto y sale lavado o dentado— y además baja megabytes para pintar
  /// un círculo. Es el servidor el que tiene que entregar el tamaño que se va
  /// a dibujar.
  ///
  /// Un [width] que no esté en `portraitThumbnailWidths`, o mayor que el
  /// original, devuelve el original: la lista de anchos es un límite de
  /// recursos, no una validación de entrada.
  ///
  /// Lanza [FormatException] si [portraitKey] no tiene el formato esperado o
  /// contiene segmentos que intentan escapar del espacio de la cuenta; a
  /// diferencia del caso anterior, esto sí se rechaza como petición inválida.
  Future<PortraitBlob?> read({
    required String userId,
    required String portraitKey,
    int? width,
  });

  /// Borra el retrato de [portraitKey] dentro del espacio de [userId], junto
  /// con las miniaturas que se hayan derivado de él. Devuelve `false` si no
  /// había nada que borrar, incluido el caso en que la clave es de otra cuenta:
  /// igual que en [read], lo ajeno y lo inexistente no se distinguen.
  ///
  /// No toca la ficha. Sacar la clave de `Character.portraitPaths` es un
  /// guardado del documento, igual que agregarla después de [save].
  ///
  /// Lanza [FormatException] ante una clave mal formada, con la misma
  /// validación que [read]: un borrado es la última operación donde se puede
  /// relajar un intento de escapar del espacio de la cuenta.
  Future<bool> delete({required String userId, required String portraitKey});

  /// Borra todos los retratos de [characterId] dentro del espacio de
  /// [userId], con sus miniaturas. Es la otra mitad de borrar el personaje:
  /// sin esto sus archivos quedaban en el volumen para siempre, porque ninguna
  /// ficha los vuelve a nombrar.
  ///
  /// Un personaje sin retratos no deja nada que borrar, y eso no es un error.
  /// Lanza [FormatException] ante un id que intente escapar del espacio de la
  /// cuenta, con la misma validación que al guardar.
  Future<void> deleteAllFor({
    required String userId,
    required String characterId,
  });
}
