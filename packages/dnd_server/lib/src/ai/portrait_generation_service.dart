import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'portrait_provider.dart';

/// Fallo al generar, distinto de un pedido mal formado: el proveedor
/// respondió con un error, se demoró en exceso, o la cuenta no tiene
/// conexión. El mensaje SHALL ser comprensible y MUST NOT contener ninguna
/// credencial (ver capacidad `ai-portrait-generation`).
class PortraitGenerationFailure implements Exception {
  final String message;
  const PortraitGenerationFailure(this.message);
  @override
  String toString() => message;
}

/// Orquesta la generación de retratos con los proveedores configurados en
/// este servidor. Deliberadamente no guarda nada: los candidatos que produce
/// son efímeros hasta que la cuenta elige uno y lo persiste vía
/// `PortraitBlobStore` (endpoint de subida), así un proveedor que falla o
/// devuelve basura nunca deja un retrato parcial asociado al personaje.
class PortraitGenerationService {
  final List<PortraitProvider> providers;

  const PortraitGenerationService(this.providers);

  /// Proveedores que este servidor puede ofrecer como opción seleccionable.
  List<PortraitProvider> get available => availableProviders(providers);

  Future<List<Uint8List>> generate({
    required String providerId,
    required String prompt,
    Uint8List? reference,
    int? count,
  }) async {
    final provider = providers.where((p) => p.id == providerId).firstOrNull;
    if (provider == null) {
      throw FormatException('Proveedor "$providerId" desconocido.');
    }
    if (!provider.isConfigured) {
      throw FormatException(
        'El proveedor "$providerId" no tiene credenciales configuradas en '
        'este servidor.',
      );
    }
    if (reference != null && !provider.supportsReference) {
      throw FormatException(
        'El proveedor "$providerId" no admite imagen de referencia.',
      );
    }

    try {
      return await provider.generate(
        prompt: prompt,
        reference: reference,
        count: count,
      );
    } on ProviderException catch (e) {
      throw PortraitGenerationFailure(e.message);
    } on TimeoutException {
      throw const PortraitGenerationFailure(
        'La generación tardó demasiado. Probá de nuevo en unos segundos.',
      );
    } on SocketException {
      throw const PortraitGenerationFailure(
        'El servidor no pudo contactar al proveedor de generación.',
      );
    }
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
