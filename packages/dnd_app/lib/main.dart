import 'dart:async';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'api/api_models.dart';
import 'app_version.dart';
import 'data/asset_content_loader.dart';
import 'data/characters_controller.dart';
import 'data/homebrew_store.dart';
import 'data/settings_service.dart';
import 'theme/app_theme.dart';
import 'theme/app_widgets.dart';
import 'ui/dashboard_screen.dart';
import 'ui/pending_events_gate.dart';
import 'web/browser.dart' as browser;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DndApp());
}

class DndApp extends StatefulWidget {
  /// Cliente alternativo. Solo lo pasa el arranque de desarrollo
  /// (`test/main_dev.dart`): la aplicación real habla con el mismo origen que
  /// la sirvió, así que le alcanza con el cliente por defecto.
  final ApiClient? api;
  const DndApp({super.key, this.api});

  @override
  State<DndApp> createState() => _DndAppState();
}

class _DndAppState extends State<DndApp> {
  // El oscuro es el tema prioritario y el que arranca; el guardado de la cuenta
  // lo reemplaza en cuanto los ajustes cargan (ver `AppThemeController`).
  final _theme = AppThemeController();

  @override
  void dispose() {
    _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _theme,
      builder: (context, mode, _) => MaterialApp(
        title: 'Milantus — Asistente de Aventuras',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        home: _Bootstrap(theme: _theme, api: widget.api),
      ),
    );
  }
}

class _AppData {
  final ContentRepository repo;
  final CharactersController controller;
  final HomebrewStore homebrew;
  final AccountInfo account;
  final AppSettings settings;
  final String? appVersion;
  _AppData(
    this.repo,
    this.controller,
    this.homebrew,
    this.account,
    this.settings,
    this.appVersion,
  );
}

/// Comprueba la sesión, carga el contenido oficial y los personajes de la
/// cuenta autenticada antes del dashboard (ver capacidad `web-client`).
class _Bootstrap extends StatefulWidget {
  final AppThemeController theme;
  final ApiClient? api;
  const _Bootstrap({required this.theme, this.api});
  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late final _api = widget.api ?? ApiClient();
  late Future<_AppData> _future;

  @override
  void initState() {
    super.initState();
    _future = _init();
  }

  Future<_AppData> _init() async {
    final account = await _api.currentAccount();
    if (account == null) {
      // Nunca hay ficha que mostrar sin sesión: se navega la pestaña entera
      // al login del proveedor OIDC (ver capacidad `user-accounts`). El
      // Future se deja sin resolver a propósito: la página está por
      // cambiar por completo.
      browser.redirectTo(_api.loginUri.toString());
      return Completer<_AppData>().future;
    }

    final repo = await loadOfficialContent();
    // Fusiona el contenido homebrew sobre el oficial (mismo esquema).
    final homebrew = HomebrewStore(_api);
    await homebrew.load();
    repo.addAll(homebrew.toRepository());

    // Una cuenta nueva arranca con la biblioteca vacía: sembrar un personaje
    // de ejemplo le deja al jugador algo ajeno que borrar antes de empezar.
    // `demoSagan()` sigue existiendo como fixture de las pruebas.
    final controller = CharactersController(_api);
    await controller.load();

    // El favorito y el orden del roster viven acá (ver `AppSettings`), así que
    // hacen falta antes de dibujar el dashboard. Un fallo al leerlos no puede
    // dejar sin personajes a nadie: se cae a los valores por defecto.
    AppSettings settings;
    try {
      settings = await SettingsService(_api).load();
    } catch (_) {
      settings = AppSettings();
    }

    // El tema se aplica acá, no en el dashboard: el control aparece también en
    // la ficha y las dos vistas leen del mismo controlador. Se guarda sobre el
    // **mismo** objeto de ajustes que usa el dashboard, así elegir un tema no
    // pisa el favorito ni el orden manual del roster.
    widget.theme.attach(AppThemeController.parse(settings.themeMode), (
      mode,
    ) async {
      settings.themeMode = mode.name;
      try {
        await SettingsService(_api).save(settings);
      } catch (_) {
        if (mounted) {
          showAppMessage(
            context,
            'El tema cambió, pero no se pudo guardar la preferencia.',
            tone: AppMessageTone.error,
          );
        }
      }
    });

    final version = await currentAppVersion();
    return _AppData(repo, controller, homebrew, account, settings, version);
  }

  void _retry() {
    setState(() {
      _future = _init();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AppData>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            body: AppErrorView(
              message: 'No se pudo iniciar la aplicación.',
              hint:
                  'Suele ser un problema momentáneo de conexión. Probá de '
                  'nuevo; si sigue igual, recargá la página.',
              details: snap.error,
              onRetry: _retry,
            ),
          );
        }
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: AppBusyLabel('Cargando datos…')),
          );
        }
        final data = snap.data!;
        if (data.controller.loadFailedOffline) {
          // Distinto de "la cuenta no tiene personajes": acá no se sabe si
          // los tiene, porque no se pudo hablar con el servidor (ver
          // capacidad `web-client`).
          return Scaffold(
            body: AppErrorView(
              icon: Icons.cloud_off,
              message: 'No se pudo conectar con el servidor.',
              hint:
                  'Tus personajes están a salvo: no se pudieron leer, pero no '
                  'se perdió nada. Revisá la conexión y reintentá.',
              onRetry: _retry,
            ),
          );
        }
        return PendingEventsGate(
          api: _api,
          child: DashboardScreen(
            repo: data.repo,
            controller: data.controller,
            homebrew: data.homebrew,
            account: data.account,
            settings: data.settings,
            appVersion: data.appVersion,
            theme: widget.theme,
          ),
        );
      },
    );
  }
}
