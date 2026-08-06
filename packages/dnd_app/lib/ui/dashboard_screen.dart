import 'package:dnd_engine/dnd_engine.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../api/api_models.dart';
import '../creation/creation_wizard.dart';
import '../data/characters_controller.dart';
import '../data/homebrew_store.dart';
import '../data/settings_service.dart';
import '../data/transfer_service.dart';
import '../homebrew/homebrew_screen.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import '../theme/class_visuals.dart';
import '../web/browser.dart' as browser;
import 'settings_dialog.dart';
import 'sheet_screen.dart';

part 'dashboard/dashboard_actions.dart';
part 'dashboard/dashboard_content.dart';
part 'dashboard/dashboard_navigation.dart';
part 'dashboard/dashboard_widgets.dart';

/// Ancho a partir del cual el panel lateral queda fijo. Por debajo se colapsa a
/// un Drawer y la ventana angosta sigue siendo usable.
const _kWideBreakpoint = 900.0;

/// Medidas de la tarjeta de personaje. La base es el diseño que venía de la
/// aplicación de escritorio; en una pestaña del navegador sobra ancho, así que
/// `_kCardMaxExtent` deja que entren menos columnas y más anchas, y la tarjeta
/// escala hasta un 30% con el ancho que efectivamente le tocó (ver `_grid`).
/// Por debajo de la base no se achica: ahí el diseño ya está al límite.
const _kCardBaseWidth = 420.0;
const _kCardBaseHeight = 212.0;
const _kCardMaxExtent = 560.0;
const _kCardSpacing = 16.0;

/// Criterio de orden del roster. El nombre de la constante es lo que se guarda
/// en los ajustes (`AppSettings.sortMode`), así que renombrarla cambia lo que
/// ya está guardado: un valor desconocido cae a [name].
enum _SortMode {
  manual('Manual'),
  dateAdded('Más recientes'),
  name('Nombre'),
  level('Nivel'),
  klass('Clase');

  const _SortMode(this.label);
  final String label;

  static _SortMode parse(String value) =>
      _SortMode.values.firstWhere((m) => m.name == value, orElse: () => name);
}

String _signed(int v) => v >= 0 ? '+$v' : '$v';

/// Dashboard del roster: panel lateral con las secciones, buscador, orden y una
/// grilla de tarjetas que muestran los datos clave de cada personaje de un
/// vistazo (PG, CA, velocidad e iniciativa) sin tener que abrir la ficha.
class DashboardScreen extends StatefulWidget {
  final ContentRepository repo;
  final CharactersController controller;
  final HomebrewStore homebrew;

  /// Cuenta con la que se entró, para mostrarla en el panel lateral. Null solo
  /// en pruebas que no ejercitan la sesión.
  final AccountInfo? account;

  /// Ajustes de la cuenta ya cargados. De acá salen el favorito y el orden del
  /// roster, y acá se guardan al cambiarlos. Null en pruebas que no los
  /// ejercitan: entonces se arranca con los valores por defecto y no se
  /// persiste nada.
  final AppSettings? settings;
  final String? appVersion;
  final VoidCallback onToggleTheme;
  const DashboardScreen({
    super.key,
    required this.repo,
    required this.controller,
    required this.homebrew,
    this.account,
    this.settings,
    this.appVersion,
    required this.onToggleTheme,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  late _SortMode _sort;
  Object? _shownSaveError;
  String? _activeOperation;

  /// Copia viva de los ajustes: se edita acá y se manda al servidor. Si no
  /// vinieron (pruebas), se trabaja sobre un objeto suelto que no se persiste.
  late final AppSettings _settings = widget.settings ?? AppSettings();
  bool get _persistsSettings => widget.settings != null;

  void _updateState(VoidCallback update) => setState(update);

  @override
  void initState() {
    super.initState();
    _sort = _SortMode.parse(_settings.sortMode);
    widget.controller.addListener(_handleControllerState);
  }

  /// Guarda los ajustes sin bloquear la interacción: reordenar o marcar un
  /// favorito tiene que sentirse inmediato. Si falla, se avisa y el cambio
  /// queda solo en pantalla hasta la próxima carga — nunca se pierde en
  /// silencio.
  void _persistSettings() {
    if (!_persistsSettings) return;
    SettingsService(widget.controller.api).save(_settings).catchError((
      Object error,
    ) {
      if (mounted) {
        showAppMessage(
          context,
          'No se pudo guardar el orden del roster: $error',
          tone: AppMessageTone.error,
        );
      }
    });
  }

  /// Marca (o desmarca) el personaje fijado arriba del roster. Uno solo: el
  /// anterior queda desmarcado sin preguntar.
  void _toggleFavorite(Character c) {
    setState(() {
      _settings.favoriteCharacterId = _settings.favoriteCharacterId == c.id
          ? null
          : c.id;
    });
    _persistSettings();
  }

  bool _isFavorite(Character c) => _settings.favoriteCharacterId == c.id;

  /// Mueve [id] a la posición que ocupa [targetId] dentro del orden manual, y
  /// pasa a ese modo: arrastrar es la forma de pedirlo, no hace falta además
  /// elegirlo en el menú.
  void _reorder(String id, String targetId, List<Character> visible) {
    if (id == targetId) return;
    setState(() {
      // El orden guardado puede estar incompleto (personajes nuevos que nunca
      // se arrastraron): se parte del orden que se está viendo, que ya incluye
      // a todos, para que mover uno no reacomode al resto sin querer.
      final ids = [for (final c in visible) c.id];
      final from = ids.indexOf(id);
      final to = ids.indexOf(targetId);
      if (from < 0 || to < 0) return;
      ids.removeAt(from);
      ids.insert(to, id);
      _settings.characterOrder = ids;
      _sort = _SortMode.manual;
      _settings.sortMode = _sort.name;
    });
    _persistSettings();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerState);
    _searchCtrl.dispose();
    super.dispose();
  }

  ContentRepository get repo => widget.repo;
  CharactersController get controller => widget.controller;

  /// Un guardado fallido por sesión expirada (401) se trata distinto de
  /// cualquier otro error: no alcanza con un aviso, hay que ofrecer volver a
  /// autenticarse (ver capacidad `user-accounts`, sesión expirada durante el
  /// uso). El cambio sin guardar sigue en `controller.characters` — no se
  /// pierde nada, solo no se pudo confirmar contra el servidor.
  bool _sessionExpiredShown = false;

  void _handleControllerState() {
    final error = controller.lastSaveError;
    if (error == null || identical(error, _shownSaveError) || !mounted) return;
    _shownSaveError = error;
    final isAuthError = error.isAuthError;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (isAuthError) {
        _showSessionExpired();
      } else {
        showAppMessage(
          context,
          'No se pudieron guardar los últimos cambios: $error',
          tone: AppMessageTone.error,
        );
      }
    });
  }

  void _showSessionExpired() {
    if (_sessionExpiredShown) return;
    _sessionExpiredShown = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('La sesión terminó'),
        content: const Text(
          'Los cambios que todavía no se pudieron guardar siguen en '
          'pantalla. Iniciá sesión de nuevo para seguir editando.',
        ),
        actions: [
          FilledButton.icon(
            onPressed: () =>
                browser.redirectTo(controller.api.loginUri.toString()),
            icon: const Icon(Icons.login),
            label: const Text('Iniciar sesión'),
          ),
        ],
      ),
    );
  }

  String _klassName(Character c) =>
      repo.characterClass(c.classId)?.name ?? c.classId;
  String _raceName(Character c) => repo.race(c.raceId)?.name ?? c.raceId;

  /// Filtra por nombre/clase/especie y ordena según el criterio elegido.
  List<Character> _visible(List<Character> all) {
    final q = _query.trim().toLowerCase();
    final list = all.where((c) {
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          _klassName(c).toLowerCase().contains(q) ||
          _raceName(c).toLowerCase().contains(q);
    }).toList();
    final createdAt = widget.controller.createdAtOf;
    switch (_sort) {
      case _SortMode.manual:
        // Lo que no está en el orden guardado (personaje nuevo, o importado)
        // va al final en vez de desaparecer o encabezar por accidente.
        final rank = {
          for (final (i, id) in _settings.characterOrder.indexed) id: i,
        };
        final last = rank.length;
        list.sort((a, b) => (rank[a.id] ?? last).compareTo(rank[b.id] ?? last));
      case _SortMode.dateAdded:
        list.sort((a, b) => createdAt(b.id).compareTo(createdAt(a.id)));
      case _SortMode.name:
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case _SortMode.level:
        list.sort((a, b) => b.level.compareTo(a.level));
      case _SortMode.klass:
        list.sort((a, b) => _klassName(a).compareTo(_klassName(b)));
    }

    // El favorito encabeza cualquiera sea el criterio: para eso se marca.
    final favorite = _settings.favoriteCharacterId;
    if (favorite != null) {
      final i = list.indexWhere((c) => c.id == favorite);
      if (i > 0) list.insert(0, list.removeAt(i));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= _kWideBreakpoint;
        if (wide) {
          return Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sidebar(context),
                Expanded(child: _content(context)),
              ],
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            // Mismo par título/subtítulo que la cabecera del panel lateral,
            // que en este ancho no está a la vista.
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Milantus'),
                Text(
                  'Asistente de Aventuras',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.3,
                    color: context.palette.gold,
                  ),
                ),
              ],
            ),
          ),
          drawer: Drawer(
            child: SafeArea(
              child: Builder(builder: (ctx) => _sidebar(ctx, inDrawer: true)),
            ),
          ),
          body: _content(context),
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // Panel lateral
  // --------------------------------------------------------------------------
}
