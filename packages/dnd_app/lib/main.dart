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
import 'web/browser.dart' as browser;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DndApp());
}

class DndApp extends StatefulWidget {
  const DndApp({super.key});

  @override
  State<DndApp> createState() => _DndAppState();
}

class _DndAppState extends State<DndApp> {
  // El oscuro es el tema prioritario y el que arranca; el claro se alcanza con
  // el botón del panel lateral.
  ThemeMode _mode = ThemeMode.dark;

  void _toggleTheme() => setState(
    () => _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Milantus — Asistente de Aventuras',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _mode,
      home: _Bootstrap(onToggleTheme: _toggleTheme),
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
  final VoidCallback onToggleTheme;
  const _Bootstrap({required this.onToggleTheme});
  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  final _api = ApiClient();
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

    final repo = await AssetContentLoader.loadOfficial();
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
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 44,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    const Text('No se pudo iniciar la aplicación.'),
                    const SizedBox(height: 8),
                    SelectableText(
                      '${snap.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
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
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off,
                      size: 44,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    const Text('No se pudo conectar con el servidor.'),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return DashboardScreen(
          repo: data.repo,
          controller: data.controller,
          homebrew: data.homebrew,
          account: data.account,
          settings: data.settings,
          appVersion: data.appVersion,
          onToggleTheme: widget.onToggleTheme,
        );
      },
    );
  }
}
