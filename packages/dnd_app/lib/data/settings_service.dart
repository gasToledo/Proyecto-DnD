import '../api/api_client.dart';

/// Ajustes de la cuenta. En el cliente web esto es solo una preferencia de
/// presentación: qué proveedor de retratos usar por defecto. Las claves de
/// proveedor nunca viajan al cliente ni se piden en esta pantalla — viven en
/// la configuración del servidor (ver `design.md`, decisión D9), así que a
/// diferencia de la versión de escritorio, [AppSettings] no tiene campos de
/// credencial.
class AppSettings {
  /// Proveedor de imágenes elegido: uno de los ids que devuelve
  /// `GET /api/portraits/providers` (ya filtrado a los configurados en el
  /// servidor).
  String imageProvider;

  AppSettings({this.imageProvider = 'pollinations'});

  Map<String, dynamic> toJson() => {'imageProvider': imageProvider};

  factory AppSettings.fromJson(Map<String, dynamic>? json) => AppSettings(
    imageProvider: json?['imageProvider'] as String? ?? 'pollinations',
  );
}

class SettingsService {
  final ApiClient api;

  SettingsService(this.api);

  /// Sin equivalente en el servidor (ver `CharactersController`).
  final List<Object> recoveryIssues = const [];

  Future<AppSettings> load() async {
    final document = await api.loadSettingsDocument();
    return AppSettings.fromJson(document);
  }

  Future<void> save(AppSettings settings) =>
      api.saveSettingsDocument(settings.toJson());
}
