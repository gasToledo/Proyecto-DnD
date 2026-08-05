import 'dart:typed_data';

import 'package:dnd_server/src/ai/portrait_provider.dart';

/// Doble de [PortraitProvider] para probar el enrutado y la orquestación de
/// [PortraitGenerationService] sin red real. [onGenerate] deja simular tanto
/// un resultado como cualquier excepción que un proveedor real podría lanzar.
class FakePortraitProvider implements PortraitProvider {
  @override
  final String id;
  @override
  final String name;
  @override
  final bool supportsReference;
  @override
  final bool isConfigured;
  @override
  final int defaultCount;

  final Future<List<Uint8List>> Function({
    required String prompt,
    Uint8List? reference,
    int? count,
  })?
  onGenerate;

  FakePortraitProvider({
    required this.id,
    this.name = 'Fake',
    this.supportsReference = false,
    this.isConfigured = true,
    this.defaultCount = 1,
    this.onGenerate,
  });

  @override
  Future<List<Uint8List>> generate({
    required String prompt,
    Uint8List? reference,
    int? count,
  }) {
    if (onGenerate != null) {
      return onGenerate!(prompt: prompt, reference: reference, count: count);
    }
    return Future.value([
      Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
    ]);
  }
}
