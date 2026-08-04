/// Metadatos de un proveedor de generación de retratos, tal como los publica
/// `GET /api/portraits/providers`: ya viene filtrado a los que el servidor
/// tiene configurados (ver capacidad `ai-portrait-generation`). El cliente
/// nunca ve una clave de proveedor, solo esto.
class PortraitProviderInfo {
  final String id;
  final String name;
  final bool supportsReference;

  const PortraitProviderInfo({
    required this.id,
    required this.name,
    required this.supportsReference,
  });

  factory PortraitProviderInfo.fromJson(Map<String, dynamic> json) =>
      PortraitProviderInfo(
        id: json['id'] as String,
        name: json['name'] as String,
        supportsReference: json['supportsReference'] as bool? ?? false,
      );
}

class ImportSummary {
  final int charactersImported;
  final int portraitsImported;

  const ImportSummary({
    required this.charactersImported,
    required this.portraitsImported,
  });
}
