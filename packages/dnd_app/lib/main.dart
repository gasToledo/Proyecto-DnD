import 'dart:async';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import 'data/asset_content_loader.dart';
import 'data/character_store.dart';
import 'data/characters_controller.dart';
import 'data/homebrew_store.dart';
import 'demo/demo_characters.dart';
import 'theme/app_theme.dart';
import 'ui/dashboard_screen.dart';

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

  void _toggleTheme() => setState(() =>
      _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fichas D&D 5e',
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
  _AppData(this.repo, this.controller, this.homebrew);
}

/// Carga el contenido oficial y los personajes persistidos antes del dashboard.
class _Bootstrap extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const _Bootstrap({required this.onToggleTheme});
  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> with WidgetsBindingObserver {
  late final Future<_AppData> _future = _init();
  _AppData? _data;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _data?.controller;
    if (controller != null) unawaited(controller.flush());
    super.dispose();
  }

  /// Al pasar a segundo plano/minimizar/cerrar, vacía los guardados con debounce
  /// pendientes para no perder hasta 400 ms del último cambio. En escritorio sin
  /// plugins es la mejor red disponible (no se puede interceptar el cierre de
  /// ventana); cubre minimizar y la mayoría de los cierres ordenados.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      final controller = _data?.controller;
      if (controller != null) unawaited(controller.flush());
    }
  }

  Future<_AppData> _init() async {
    final repo = await AssetContentLoader.loadOfficial();
    // Fusiona el contenido homebrew sobre el oficial (mismo esquema).
    final homebrew = HomebrewStore();
    await homebrew.load();
    repo.addAll(homebrew.toRepository());

    final controller = CharactersController(CharacterStore());
    await controller.load();
    // Primera ejecución: sembramos el personaje de ejemplo y lo persistimos.
    if (controller.characters.isEmpty) {
      controller.add(demoSagan());
    }
    final data = _AppData(repo, controller, homebrew);
    _data = data;
    return data;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AppData>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            body: Center(child: Text('Error al iniciar:\n${snap.error}')),
          );
        }
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return DashboardScreen(
          repo: snap.data!.repo,
          controller: snap.data!.controller,
          homebrew: snap.data!.homebrew,
          onToggleTheme: widget.onToggleTheme,
        );
      },
    );
  }
}
