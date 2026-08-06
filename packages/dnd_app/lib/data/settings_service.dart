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

  /// Personaje fijado arriba del roster, o `null` si no hay ninguno. Uno solo:
  /// marcar otro le saca la marca al anterior, así nunca hay dudas sobre quién
  /// va primero.
  String? favoriteCharacterId;

  /// Orden elegido a mano, por id. Puede quedar desfasado del roster (ids de
  /// personajes borrados, personajes nuevos que no están todavía): el
  /// dashboard lo reconcilia al mostrar, no al guardar, así que borrar y
  /// recrear un personaje no rompe el orden del resto.
  List<String> characterOrder;

  /// Criterio de orden activo, por nombre del modo. Se guarda para que el
  /// orden manual siga en pie al volver a entrar: si no, arrastrar tarjetas
  /// sería trabajo que se pierde al recargar.
  String sortMode;

  AppSettings({
    this.imageProvider = 'pollinations',
    this.favoriteCharacterId,
    List<String>? characterOrder,
    this.sortMode = 'name',
  }) : characterOrder = characterOrder ?? [];

  Map<String, dynamic> toJson() => {
    'imageProvider': imageProvider,
    'favoriteCharacterId': favoriteCharacterId,
    'characterOrder': characterOrder,
    'sortMode': sortMode,
  };

  factory AppSettings.fromJson(Map<String, dynamic>? json) => AppSettings(
    imageProvider: json?['imageProvider'] as String? ?? 'pollinations',
    favoriteCharacterId: json?['favoriteCharacterId'] as String?,
    characterOrder: [
      for (final id in (json?['characterOrder'] as List?) ?? const [])
        id as String,
    ],
    sortMode: json?['sortMode'] as String? ?? 'name',
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
