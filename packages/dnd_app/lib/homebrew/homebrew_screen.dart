import 'dart:convert';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/homebrew_store.dart';
import '../data/transfer_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import '../web/browser.dart' as browser;
import 'effect_editor.dart';

part 'forms/armor_form.dart';
part 'forms/background_form.dart';
part 'forms/creature_form.dart';
part 'forms/feat_form.dart';
part 'forms/form_widgets.dart';
part 'forms/item_form.dart';
part 'forms/race_form.dart';
part 'forms/spell_form.dart';
part 'forms/weapon_form.dart';
part 'homebrew_sections.dart';

// Los ids son el contrato con el motor de reglas y no cambian; lo que cambia
// es que dejan de estar a la vista. Las habilidades salen de `Skill`, que ya es
// la única fuente de la traducción (ver `skill.dart`) — repetirlas acá era
// arriesgarse a que las dos listas se separaran.
final _skillOptions = {for (final id in Skill.allIds) id: Skill.labelFor(id)};

const _weaponPropOptions = {
  'finesse': 'Sutil',
  'versatile': 'Versátil',
  'two-handed': 'A dos manos',
  'light': 'Ligera',
  'heavy': 'Pesada',
  'thrown': 'Arrojadiza',
  'ranged': 'A distancia',
  'ammunition': 'Munición',
  'reach': 'Alcance',
  'loading': 'Recarga',
};

const _weaponCategories = {'simple': 'Simple', 'martial': 'Marcial'};

const _armorCategories = {
  'light': 'Ligera',
  'medium': 'Media',
  'heavy': 'Pesada',
  'shield': 'Escudo',
};

/// Familias de objeto. `magic` no está: lo que hace mágico a un objeto es
/// tener rareza, y ofrecer las dos cosas dejaría guardar un objeto de categoría
/// mágica sin rareza, que el motor trata como mundano.
const _itemCategories = {
  'gear': 'Equipo',
  'tool': 'Herramienta',
  'ammunition': 'Munición',
  'focus': 'Canalizador',
  'pack': 'Paquete',
  'container': 'Contenedor',
};

/// Valor del desplegable de rareza que significa "no es mágico". Va como texto
/// y no como null porque el desplegable no acepta una opción nula.
const _mundane = 'mundane';

const _itemRarities = {
  _mundane: 'Mundano',
  'common': 'Común',
  'uncommon': 'Infrecuente',
  'rare': 'Raro',
  'very-rare': 'Muy raro',
  'legendary': 'Legendario',
  'artifact': 'Artefacto',
};

const _featCategories = {
  'origin': 'De origen',
  'general': 'General',
  'fighting-style': 'Estilo de combate',
  'dragonmark': 'Marca dracónica',
  'epic-boon': 'Don épico',
};

/// Tamaños que el contenido oficial usa. A diferencia del resto, acá el valor
/// guardado ya está en español (`Race.size`), así que id y etiqueta coinciden.
const _raceSizes = {
  'Pequeño': 'Pequeño',
  'Mediano': 'Mediano',
  'Grande': 'Grande',
};

/// Las ocho categorías de contenido propio, en el orden en que se muestran.
///
/// Tenerlas acá —con su rótulo, su ícono y el verbo de agregar— es lo que
/// mantiene juntos el panel, la portada y el contenido: sumar una categoría es
/// sumar un valor y su `case`, no acordarse de tres listas paralelas que
/// después se separan (que es lo que pasaba con las ocho pestañas escritas a
/// mano al lado de las ocho vistas).
enum _Category {
  weapons('Armas', Icons.hardware, 'Agregar arma'),
  armor('Armaduras', Icons.shield_outlined, 'Agregar armadura'),
  items('Objetos', Icons.inventory_2_outlined, 'Agregar objeto'),
  feats('Dotes', Icons.military_tech, 'Agregar dote'),
  races('Razas', Icons.diversity_3, 'Agregar raza'),
  backgrounds('Trasfondos', Icons.history_edu, 'Agregar trasfondo'),
  spells('Conjuros', Icons.auto_stories, 'Agregar conjuro'),
  creatures('Criaturas', Icons.pets_outlined, 'Agregar criatura');

  final String label;
  final IconData icon;
  final String addLabel;

  const _Category(this.label, this.icon, this.addLabel);
}

/// Editor de contenido homebrew. Lo creado se fusiona en el [ContentRepository]
/// compartido, así queda disponible de inmediato en el wizard y la ficha.
class HomebrewScreen extends StatefulWidget {
  final ContentRepository repo;
  final HomebrewStore store;
  const HomebrewScreen({super.key, required this.repo, required this.store});

  @override
  State<HomebrewScreen> createState() => _HomebrewScreenState();
}

class _HomebrewScreenState extends State<HomebrewScreen> {
  /// Ancho a partir del cual el panel de categorías entra al lado del
  /// contenido. Es el mismo corte que el Modo DM y el dashboard.
  static const double _wideBreakpoint = 900;

  ContentRepository get repo => widget.repo;
  HomebrewStore get store => widget.store;

  /// Categoría abierta, o **null para la portada**.
  ///
  /// La portada es la entrada por defecto y no una categoría más: no tiene
  /// lista ni botón de agregar, y representarla como la ausencia de categoría
  /// evita darle a `_Category` un valor que ninguna de las ocho vistas sabría
  /// atender. Es el mismo trato que le da el Modo DM al Bestiario.
  _Category? _section;

  /// Lo que se está buscando, **en todas las categorías a la vez**.
  ///
  /// Con contenido propio uno se acuerda del nombre, no de en qué categoría lo
  /// guardó, así que la búsqueda no vive dentro de una sección: mientras haya
  /// texto, el contenido son los resultados y el panel cuenta coincidencias.
  final _searchController = TextEditingController();
  String _query = '';

  String get _needle => _query.trim();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  /// Abre una categoría, o la portada con `null`. Vive en el estado y no en la
  /// extensión porque `setState` es protegido: desde afuera de la clase no se
  /// puede llamar.
  ///
  /// Elegir una sección **cancela la búsqueda**: pedir una categoría y seguir
  /// viendo resultados mezclados sería contestar otra cosa.
  void _open(_Category? section) {
    _searchController.clear();
    setState(() {
      _section = section;
      _query = '';
    });
  }

  void _search(String value) => setState(() => _query = value);

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  /// Confirma un guardado. Sin este aviso, guardar y salir del formulario se
  /// ve igual que cancelar: se vuelve a la misma lista.
  void _saved(String name) {
    _refresh();
    if (mounted) {
      showAppMessage(
        context,
        '«$name» se guardó.',
        tone: AppMessageTone.success,
      );
    }
  }

  /// Y su contrario: salir del formulario sin guardar tiene que decirlo, o
  /// queda la duda de si el cambio entró.
  void _discarded() {
    if (mounted) showAppMessage(context, 'No se guardó ningún cambio.');
  }

  /// Ejecuta una escritura en disco del store homebrew; si falla (permisos,
  /// disco lleno) lo muestra en vez de dejar la excepción sin capturar.
  Future<bool> _persist(Future<void> Function() write) async {
    try {
      await write();
      return true;
    } catch (e) {
      if (mounted) {
        showAppMessage(
          context,
          'No se pudo guardar el contenido homebrew: $e',
          tone: AppMessageTone.error,
        );
      }
      return false;
    }
  }

  Future<void> _exportHomebrew() async {
    final content = store.exportContent();
    final total = content.values.fold<int>(0, (s, l) => s + l.length);
    if (total == 0) {
      showAppMessage(context, 'No hay contenido homebrew para exportar.');
      return;
    }
    final transfer = TransferService(store.api);
    browser.downloadBytes(
      transfer.exportHomebrew(content),
      fileName: transfer.homebrewExportFileName(),
      mimeType: 'application/json',
    );
    showAppMessage(
      context,
      'Homebrew exportado ($total entrada(s)).',
      tone: AppMessageTone.success,
      duration: const Duration(seconds: 4),
    );
  }

  Future<void> _importHomebrew() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
      dialogTitle: 'Elegí un pack homebrew (.json)',
    );
    final file = picked?.files.singleOrNull;
    if (file?.bytes == null || !mounted) return;
    try {
      final content = TransferService.parseHomebrewImport(
        utf8.decode(file!.bytes!),
      );
      if (!mounted) return;
      // No pisar homebrew existente sin avisar: si hay ids en colisión, pedir
      // confirmación antes de sobrescribir.
      final collisions = store.countCollisions(content);
      if (collisions > 0) {
        final overwrite = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Sobrescribir homebrew'),
            content: Text(
              '$collisions entrada(s) del pack comparten id con '
              'contenido que ya tenés. Al importar se reemplazarán. '
              '¿Continuar?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Sobrescribir'),
              ),
            ],
          ),
        );
        if (overwrite != true || !mounted) return;
      }
      final count = await store.importContent(content, repository: repo);
      // Fusiona lo importado en el repo compartido, así queda disponible de
      // inmediato en el wizard y las fichas (igual que al guardar un ítem).
      repo.addAll(store.toRepository());
      if (!mounted) return;
      setState(() {});
      showAppMessage(
        context,
        'Importadas $count entradas de homebrew.',
        tone: AppMessageTone.success,
      );
    } catch (e) {
      if (mounted) {
        showAppMessage(
          context,
          'No se pudo importar el homebrew: $e',
          tone: AppMessageTone.error,
        );
      }
    }
  }

  Future<void> _deleteInvalid(HomebrewLoadIssue issue) async {
    final deleted = await _persist(() => store.deleteInvalid(issue));
    if (deleted && mounted) setState(() {});
  }

  Widget _loadIssues() => Material(
    color: Theme.of(context).colorScheme.errorContainer,
    child: ExpansionTile(
      leading: const Icon(Icons.warning_amber_rounded),
      title: Text(
        '${store.loadIssues.length} entrada(s) homebrew inválida(s) se omitieron',
      ),
      subtitle: const Text(
        'Podés revisarlas y borrarlas sin impedir el inicio.',
      ),
      children: [
        for (final issue in store.loadIssues)
          ListTile(
            dense: true,
            title: Text('${issue.category} · ${issue.id}'),
            subtitle: Text(issue.message),
            trailing: IconButton(
              tooltip: 'Borrar entrada inválida',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteInvalid(issue),
            ),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    // `LayoutBuilder` y no `MediaQuery`: esta pantalla también se abre desde el
    // dashboard, que ya se comió 236 px de panel que `MediaQuery` no descuenta.
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= _wideBreakpoint;
        return Scaffold(
          appBar: AppBar(title: const Text('Contenido homebrew')),
          // Angosto: el panel se pliega al Drawer y el AppBar se gana solo su
          // botón de menú.
          drawer: wide
              ? null
              : Drawer(child: SafeArea(child: _rail(context, inDrawer: true))),
          body: Column(
            children: [
              // El aviso va arriba de todo y a lo ancho: habla del contenido
              // entero, no de la categoría que se esté mirando.
              if (store.loadIssues.isNotEmpty) _loadIssues(),
              Expanded(
                child: wide
                    ? Row(
                        children: [
                          _rail(context),
                          Expanded(child: _content()),
                        ],
                      )
                    : _content(),
              ),
            ],
          ),
        );
      },
    );
  }
}
