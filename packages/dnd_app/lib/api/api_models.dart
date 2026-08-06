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

/// La cuenta de la sesión en curso, tal como la publica `GET /api/me`. El
/// perfil sale del proveedor OIDC (Zitadel), no de un registro de usuario
/// propio: acá solo se muestra. Todo menos [userId] puede faltar (cuenta sin
/// esos datos cargados, o sesión abierta antes de que se empezaran a guardar).
class AccountInfo {
  final String userId;
  final String? name;
  final String? email;
  final String? pictureUrl;

  const AccountInfo({
    required this.userId,
    this.name,
    this.email,
    this.pictureUrl,
  });

  factory AccountInfo.fromJson(Map<String, dynamic> json) => AccountInfo(
    userId: json['userId'] as String,
    name: json['name'] as String?,
    email: json['email'] as String?,
    pictureUrl: json['pictureUrl'] as String?,
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
