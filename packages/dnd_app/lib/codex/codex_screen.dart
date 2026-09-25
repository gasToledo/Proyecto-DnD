import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';

part 'codex_category_view.dart';
part 'codex_entries.dart';

/// Las categorías del Códice, en el orden en que se muestran, con el grupo de
/// la portada al que pertenecen.
///
/// Mismo criterio que las categorías de Homebrew: el panel, la portada y el
/// contenido salen de acá, y sumar una categoría es sumar un valor y su `case`
/// en [codexEntries].
enum CodexCategory {
  races('Especies', Icons.diversity_3, _personaje),
  lineages('Linajes', Icons.account_tree_outlined, _personaje),
  classes('Clases', Icons.shield_outlined, _personaje),
  subclasses('Subclases', Icons.call_split, _personaje),
  backgrounds('Trasfondos', Icons.history_edu, _personaje),
  feats('Dotes', Icons.military_tech, _personaje),
  spells('Conjuros', Icons.auto_stories, _magia),
  magicItems('Objetos mágicos', Icons.auto_fix_high_outlined, _magia),
  weapons('Armas', Icons.hardware, _magia),
  armor('Armaduras', Icons.security, _magia),
  gear('Equipo', Icons.inventory_2_outlined, _magia);

  final String label;
  final IconData icon;
  final String group;

  const CodexCategory(this.label, this.icon, this.group);
}

const _personaje = 'Personaje';
const _magia = 'Magia y equipo';

/// Cuántas coincidencias de cada categoría muestra la búsqueda general antes
/// de ofrecer «Ver las N». Con una letra sola, «a» encuentra casi todo el
/// catálogo: listarlo entero sería una pared.
const _searchPreview = 5;

/// El Códice: todo el contenido del juego para leer, sin crear un personaje
/// ni editar nada.
///
/// Es de **solo lectura** a propósito. Agregar algo a una ficha ya tiene su
/// lugar (la creación, el inventario, la subida de nivel) y editar contenido
/// es Homebrew; acá se viene a leer qué hace algo.
///
/// Las criaturas no están, y es a propósito: el Códice lo abre cualquier
/// jugador, y los perfiles de los monstruos son del DM. Se consultan en el
/// Bestiario del Modo DM.
class CodexScreen extends StatefulWidget {
  final ContentRepository repo;

  const CodexScreen({super.key, required this.repo});

  @override
  State<CodexScreen> createState() => _CodexScreenState();
}

class _CodexScreenState extends State<CodexScreen> {
  /// Mismo corte que Homebrew y el dashboard para plegar el panel al Drawer.
  static const double _wideBreakpoint = 900;

  /// Categoría abierta, o null para la portada.
  CodexCategory? _section;

  /// La entrada abierta al entrar a la categoría (llegando desde la búsqueda
  /// general) y la búsqueda con que arranca su lista («Ver las N»).
  String? _openId;
  String _openQuery = '';

  final _searchController = TextEditingController();
  String _query = '';

  String get _needle => foldForSearch(_query.trim());

  /// Las entradas de cada categoría, armadas una vez: el catálogo no cambia
  /// mientras la pantalla está abierta, y el detalle se construye recién al
  /// abrirlo.
  late final Map<CodexCategory, List<CodexEntry>> _entries = {
    for (final c in CodexCategory.values) c: codexEntries(c, widget.repo),
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Abre una categoría (o la portada con null). Elegir una sección cancela la
  /// búsqueda general, igual que en Homebrew: pedir una categoría y seguir
  /// viendo resultados mezclados sería contestar otra cosa.
  void _open(CodexCategory? section, {String? id, String query = ''}) {
    _searchController.clear();
    setState(() {
      _section = section;
      _openId = id;
      _openQuery = query;
      _query = '';
    });
  }

  List<CodexEntry> _matches(CodexCategory c) {
    final needle = _needle;
    return [
      for (final e in _entries[c]!)
        if (foldForSearch(e.name).contains(needle)) e,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= _wideBreakpoint;
        return Scaffold(
          appBar: AppBar(title: const Text('Códice')),
          drawer: wide
              ? null
              : Drawer(child: SafeArea(child: _rail(context, inDrawer: true))),
          body: wide
              ? Row(
                  children: [
                    _rail(context),
                    Expanded(child: _content()),
                  ],
                )
              : _content(),
        );
      },
    );
  }

  Widget _rail(BuildContext context, {bool inDrawer = false}) {
    final pal = context.palette;
    final searching = _needle.isNotEmpty;
    void run(VoidCallback action) {
      if (inDrawer) Navigator.of(context).pop();
      action();
    }

    return Container(
      width: inDrawer ? null : 236,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(right: BorderSide(color: pal.hairline)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('codex-search'),
            controller: _searchController,
            decoration: InputDecoration(
              isDense: true,
              labelText: 'Buscar en todo el Códice',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: searching
                  ? IconButton(
                      tooltip: 'Limpiar búsqueda',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => run(() {
                        _searchController.clear();
                        setState(() => _query = '');
                      }),
                    )
                  : null,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 12),
          appNavItem(
            context,
            icon: Icons.menu_book_outlined,
            label: 'Portada',
            active: !searching && _section == null,
            onTap: () => run(() => _open(null)),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final c in CodexCategory.values) ...[
                  if (c == CodexCategory.values.first ||
                      c.group != CodexCategory.values[c.index - 1].group)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 14, 8, 0),
                      child: Eyebrow(c.group),
                    ),
                  appNavItem(
                    context,
                    icon: c.icon,
                    label: c.label,
                    active: !searching && _section == c,
                    // Buscando, el panel cuenta coincidencias: dice dónde
                    // hay algo sin tener que bajar por los resultados.
                    count:
                        '${searching ? _matches(c).length : _entries[c]!.length}',
                    onTap: () => run(() => _open(c)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    if (_needle.isNotEmpty) return _searchResults();
    final section = _section;
    if (section == null) return _portada();
    // La clave reconstruye la vista al cambiar de categoría o de entrada: su
    // búsqueda y su selección son de esa categoría, no se heredan.
    final key = ValueKey('${section.name}-$_openId-$_openQuery');
    return _CodexCategoryView(
      key: key,
      category: section,
      entries: _entries[section]!,
      initialId: _openId,
      initialQuery: _openQuery,
    );
  }

  Widget _portada() {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    return PageBody(
      maxWidth: 900,
      children: [
        Text(
          'Códice',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 24,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Todo el contenido del juego para leer, sin crear un personaje ni '
          'editar nada. Tu homebrew aparece mezclado con el resto, con su '
          'marca de procedencia.',
          style: TextStyle(fontSize: 13, color: pal.textMuted),
        ),
        for (final group in [_personaje, _magia]) ...[
          const SizedBox(height: 20),
          Eyebrow(group),
          LayoutBuilder(
            builder: (context, box) {
              final columns = box.maxWidth >= 720
                  ? 3
                  : box.maxWidth >= 460
                  ? 2
                  : 1;
              final width = (box.maxWidth - 12 * (columns - 1)) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final c in CodexCategory.values)
                    if (c.group == group)
                      SizedBox(width: width, child: _categoryCard(c)),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _categoryCard(CodexCategory c) {
    final pal = context.palette;
    final entries = _entries[c]!;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _open(c),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: pal.hairline),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(c.icon, size: 20, color: pal.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      c.label,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    '${entries.length}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: pal.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Una muestra y no un resumen: dice de qué se trata lo que hay
              // adentro sin prometer que estén todos.
              Text(
                entries.take(3).map((e) => e.name).join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: pal.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Los resultados de la búsqueda general, agrupados por categoría: el mismo
  /// nombre puede ser un conjuro y un objeto, y son cosas distintas.
  Widget _searchResults() {
    final pal = context.palette;
    final groups = {
      for (final c in CodexCategory.values)
        if (_matches(c) case final found when found.isNotEmpty) c: found,
    };
    final total = groups.values.fold(0, (sum, list) => sum + list.length);
    if (total == 0) {
      return AppEmptyState(
        icon: Icons.search_off,
        message: 'Nada del Códice coincide con «${_query.trim()}».',
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              _searchController.clear();
              setState(() => _query = '');
            },
            icon: const Icon(Icons.close, size: 20),
            label: const Text('Limpiar búsqueda'),
          ),
        ],
      );
    }
    return PageBody(
      children: [
        Text(
          total == 1 ? '1 resultado' : '$total resultados',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 18,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 14),
        for (final MapEntry(key: c, value: found) in groups.entries) ...[
          Eyebrow('${c.label} · ${found.length}'),
          DenseRows(
            children: [
              for (final e in found.take(_searchPreview))
                ListTile(
                  key: ValueKey('codex-result-${c.name}-${e.id}'),
                  dense: true,
                  title: Text(e.name),
                  subtitle: e.subtitle.isEmpty ? null : Text(e.subtitle),
                  onTap: () => _open(c, id: e.id),
                ),
              if (found.length > _searchPreview)
                ListTile(
                  dense: true,
                  title: Text(
                    'Ver las ${found.length} coincidencias en ${c.label}',
                    style: TextStyle(color: pal.gold),
                  ),
                  onTap: () => _open(c, query: _query.trim()),
                ),
            ],
          ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}
