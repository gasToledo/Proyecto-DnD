import 'dart:async';

import '../api/api_client.dart';

/// Preferencias de la cuenta: proveedor de retratos, favorito, orden del
/// roster y tema. Las credenciales de proveedores viven solo en el servidor.
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

  /// Tema elegido, por el nombre de `ThemeMode` (`system`, `light`, `dark`).
  /// Se guarda para que no haya que volver a elegirlo en cada recarga; un
  /// valor desconocido cae a oscuro (ver `AppThemeController.parse`).
  String themeMode;

  AppSettings({
    this.imageProvider = 'pollinations',
    this.favoriteCharacterId,
    List<String>? characterOrder,
    this.sortMode = 'name',
    this.themeMode = 'dark',
  }) : characterOrder = characterOrder ?? [];

  Map<String, dynamic> toJson() => {
    'imageProvider': imageProvider,
    'favoriteCharacterId': favoriteCharacterId,
    'characterOrder': characterOrder,
    'sortMode': sortMode,
    'themeMode': themeMode,
  };

  factory AppSettings.fromJson(Map<String, dynamic>? json) => AppSettings(
    imageProvider: json?['imageProvider'] as String? ?? 'pollinations',
    favoriteCharacterId: json?['favoriteCharacterId'] as String?,
    characterOrder: [
      for (final id in (json?['characterOrder'] as List?) ?? const [])
        id as String,
    ],
    sortMode: json?['sortMode'] as String? ?? 'name',
    themeMode: json?['themeMode'] as String? ?? 'dark',
  );
}

class SettingsService {
  final ApiClient api;

  SettingsService(this.api);

  Future<AppSettings> load() async {
    final document = await api.loadSettingsDocument();
    return AppSettings.fromJson(document);
  }
}

/// Estado canónico de preferencias de una sesión y cola de persistencia.
/// Todas las pantallas que editan ajustes comparten esta instancia para que
/// dos escrituras no puedan viajar en paralelo con snapshots contradictorios.
class SettingsController {
  final ApiClient api;
  AppSettings settings;

  Map<String, dynamic>? _pendingSnapshot;
  final List<Completer<void>> _pendingWaiters = [];
  bool _draining = false;

  SettingsController(this.api, this.settings);

  Future<AppSettings> load() async {
    final document = await api.loadSettingsDocument();
    settings = AppSettings.fromJson(document);
    return settings;
  }

  Future<void> update(void Function(AppSettings settings) mutate) {
    mutate(settings);
    return saveCurrent();
  }

  /// Persiste una copia profunda del documento actual y agrupa las mutaciones
  /// que llegan mientras la petición anterior sigue en vuelo.
  Future<void> saveCurrent() {
    final completer = Completer<void>();
    _pendingSnapshot = _snapshot(settings);
    _pendingWaiters.add(completer);
    _drain();
    return completer.future;
  }

  Map<String, dynamic> _snapshot(AppSettings value) => {
    ...value.toJson(),
    'characterOrder': List<String>.of(value.characterOrder),
  };

  void _drain() {
    if (_draining) return;
    _draining = true;
    _drainLoop();
  }

  Future<void> _drainLoop() async {
    try {
      while (_pendingSnapshot != null) {
        final snapshot = _pendingSnapshot!;
        _pendingSnapshot = null;
        final waiters = List<Completer<void>>.of(_pendingWaiters);
        _pendingWaiters.clear();
        try {
          await api.saveSettingsDocument(snapshot);
          for (final waiter in waiters) {
            if (!waiter.isCompleted) waiter.complete();
          }
        } catch (error, stackTrace) {
          for (final waiter in waiters) {
            if (!waiter.isCompleted) waiter.completeError(error, stackTrace);
          }
        }
      }
    } finally {
      _draining = false;
      // A mutation can be queued between the last loop condition and the
      // cleanup above. Make sure it gets another drain without overlapping
      // the previous one.
      if (_pendingSnapshot != null) _drain();
    }
  }
}
