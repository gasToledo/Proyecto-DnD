import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';
import 'add_monster_dialog.dart';

/// El bestiario: buscar un monstruo, leer su perfil y sumarlo al combate.
///
/// A diferencia de `ChaptersView` y `EncounterView`, esta sí tiene estado
/// propio, y por el mismo motivo por el que aquellas no lo tienen: sus datos
/// son remotos y los maneja quien las monta, mientras que las criaturas ya
/// están en memoria y lo único que hay para recordar acá es qué se buscó y qué
/// se está mirando. Nadie más arriba necesita saber eso.
///
/// Tampoco tiene estados de carga ni de error: `creaturesSorted` es una lectura
/// sincrónica de contenido ya parseado. Un `AppBusyLabel` o un `AppErrorView`
/// serían código muerto para una condición que no puede pasar.
///
/// Sumar al combate se hace **sin salir de acá**: armar un encuentro son
/// varias criaturas distintas, y cada ida y vuelta a Combate perdería la
/// búsqueda y los filtros. La regla de cómo entran las copias es la misma que
/// usa Combate (`withMonsters`, en el engine).
class BestiaryView extends StatefulWidget {
  final ContentRepository repo;
  final ApiClient api;

  /// La campaña a cuyo combate se suma, o null si el DM no tiene ninguna.
  final Campaign? campaign;

  const BestiaryView({
    super.key,
    required this.repo,
    required this.api,
    required this.campaign,
  });

  @override
  State<BestiaryView> createState() => _BestiaryViewState();
}

/// Ancho a partir del cual entran la lista y el perfil al mismo tiempo.
///
/// Es más chico que el de la app (900) porque acá se mide el **área de
/// contenido**, que ya viene descontado el panel de 236 px.
const double _splitWidth = 760;

const _todos = '__todos__';

/// Las criaturas de [all] que coinciden con los filtros, en el orden pedido.
///
/// Es la única regla de búsqueda de criaturas del Modo DM: la usan el
/// Bestiario y la solapa Bestiario de «Sumar al combate». Cuando eran dos, el
/// buscador del combate no plegaba acentos y «aguila» no encontraba «Águila».
///
/// Un rango de VD con cualquiera de los dos extremos deja afuera a las
/// criaturas sin VD: quien pide «de 1 a 3» no está buscando al compañero de
/// un conjuro, que no tiene desafío.
///
/// [all] tiene que venir ordenado por nombre, como `creaturesSorted`: el orden
/// por nombre es el de entrada.
List<Creature> filterCreatures(
  Iterable<Creature> all, {
  String query = '',
  String? typeId,
  num? minCr,
  num? maxCr,
  bool sortByCr = false,
}) {
  final needle = foldForSearch(query.trim());
  final ranged = minCr != null || maxCr != null;
  bool inRange(num? cr) =>
      !ranged ||
      (cr != null &&
          (minCr == null || cr >= minCr) &&
          (maxCr == null || cr <= maxCr));
  final results = [
    for (final c in all)
      if ((typeId == null || c.creatureType?.id == typeId) &&
          (needle.isEmpty || foldForSearch(c.name).contains(needle)) &&
          inRange(c.cr))
        c,
  ];
  if (sortByCr) {
    // `sort` no es estable: el desempate por nombre va explícito.
    results.sort((a, b) {
      final ca = a.cr, cb = b.cr;
      if (ca != cb) {
        if (ca == null) return 1;
        if (cb == null) return -1;
        return ca.compareTo(cb);
      }
      return compareContentNames(a.name, b.name);
    });
  }
  return results;
}

class _BestiaryViewState extends State<BestiaryView> {
  final _searchController = TextEditingController();
  String _query = '';
  String _type = _todos;
  num? _minCr;
  num? _maxCr;
  bool _sortByCr = false;
  Creature? _selected;

  /// Las sumas al combate, una detrás de otra. El diálogo se cierra antes de
  /// que el servidor responda, y dos sumas seguidas leerían el mismo combate:
  /// la segunda pisaría a la primera. Es el mismo arreglo que en Combate.
  Future<void> _writes = Future.value();
  int _idCounter = 0;

  String _newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

  Future<void> _addToCombat(Creature creature) async {
    final campaign = widget.campaign;
    if (campaign == null) return;
    final choice = await showAddMonsterDialog(
      context,
      creature: creature,
      campaignName: campaign.name,
    );
    if (choice == null || !mounted) return;
    _writes = _writes.then((_) async {
      try {
        // Se lee recién ahora, dentro de la fila: la numeración tiene que
        // continuar la del combate guardado, incluida la tanda anterior.
        final current = await widget.api.getEncounter(campaign.id);
        final next = (current ?? Encounter(id: _newId('encounter')))
            .withMonsters(
              choice.creature,
              choice.count,
              newId: () => _newId('c'),
              side: choice.side,
              rollHp: choice.rollHp,
            );
        await widget.api.saveEncounter(campaign.id, next);
        if (!mounted) return;
        final what = choice.count == 1
            ? choice.creature.name
            : '${choice.count} × ${choice.creature.name}';
        showAppMessage(
          context,
          'Sumaste $what al combate de ${campaign.name}.',
        );
      } catch (error) {
        if (!mounted) return;
        showAppMessage(
          context,
          failureMessage('No se pudo sumar al combate', error),
          tone: AppMessageTone.error,
        );
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// El catálogo que ve el DM. `creaturesSorted` ya deja afuera las
  /// invocaciones por fórmula, cuyas CA y PG dependen de quien las invoca y no
  /// significan nada sueltas.
  List<Creature> get _all => widget.repo.creaturesSorted;

  List<Creature> get _results => filterCreatures(
    _all,
    query: _query,
    typeId: _type == _todos ? null : _type,
    minCr: _minCr,
    maxCr: _maxCr,
    sortByCr: _sortByCr,
  );

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _type = _todos;
      _minCr = null;
      _maxCr = null;
    });
  }

  // Un rango invertido no se muestra como lista vacía: el extremo que no se
  // tocó se corre hasta el que sí. Quien pide «desde 5» teniendo «hasta 2» no
  // quiere cero resultados, quiere que el otro extremo lo acompañe.
  void _setMinCr(num? v) => setState(() {
    _minCr = v;
    if (v != null && _maxCr != null && _maxCr! < v) _maxCr = v;
  });

  void _setMaxCr(num? v) => setState(() {
    _maxCr = v;
    if (v != null && _minCr != null && _minCr! > v) _minCr = v;
  });

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= _splitWidth;
        if (!wide && _selected != null) {
          return _detail(
            context,
            _selected!,
            onBack: () {
              setState(() => _selected = null);
            },
          );
        }
        final list = _list(context, results);
        if (!wide) return list;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 300, child: list),
            VerticalDivider(width: 1, color: context.palette.hairline),
            Expanded(
              child: _selected == null
                  ? const AppEmptyState(
                      icon: Icons.pets_outlined,
                      message: 'Elegí una criatura para ver su perfil.',
                    )
                  : _detail(context, _selected!),
            ),
          ],
        );
      },
    );
  }

  Widget _list(BuildContext context, List<Creature> results) {
    final pal = context.palette;
    // Los tipos salen de lo que hay cargado, no de una lista fija: así el
    // filtro no ofrece un tipo vacío ni se olvida de uno nuevo.
    final types = <CreatureType>{for (final c in _all) ?c.creatureType}.toList()
      ..sort((a, b) => compareContentNames(a.label, b.label));
    // Igual con los VD: los que existen en lo cargado, homebrew incluido.
    final crs = <num>{for (final c in _all) ?c.cr}.toList()..sort();
    List<DropdownMenuItem<num?>> crItems() => [
      const DropdownMenuItem(value: null, child: Text('Cualquiera')),
      for (final cr in crs)
        DropdownMenuItem(value: cr, child: Text(challengeRatingLabel(cr))),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: 'Buscar criatura',
                  hintText: 'Nombre',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar búsqueda',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                // `initialValue` se lee una sola vez: la clave reconstruye el
                // campo cuando «Limpiar filtros» cambia el valor desde afuera,
                // que si no seguiría mostrando el tipo viejo.
                key: ValueKey('bestiary-type-$_type'),
                initialValue: _type,
                isDense: true,
                // Sin esto el desplegable se mide por su ítem más ancho y se
                // desborda de la columna de 300 px.
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Tipo',
                ),
                items: [
                  const DropdownMenuItem(
                    value: _todos,
                    child: Text('Todos los tipos'),
                  ),
                  for (final t in types)
                    DropdownMenuItem(value: t.id, child: Text(t.label)),
                ],
                onChanged: (v) => setState(() => _type = v ?? _todos),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<num?>(
                      key: ValueKey('bestiary-min-cr-$_minCr'),
                      initialValue: _minCr,
                      isDense: true,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'VD desde',
                      ),
                      items: crItems(),
                      onChanged: _setMinCr,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<num?>(
                      key: ValueKey('bestiary-max-cr-$_maxCr'),
                      initialValue: _maxCr,
                      isDense: true,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'VD hasta',
                      ),
                      items: crItems(),
                      onChanged: _setMaxCr,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  results.length == 1
                      ? '1 criatura'
                      : '${results.length} criaturas',
                  style: TextStyle(fontSize: 12, color: pal.textMuted),
                ),
              ),
              // El orden no es un filtro: «Limpiar filtros» no lo toca.
              SegmentedButton<bool>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: const [
                  ButtonSegment(value: false, label: Text('Nombre')),
                  ButtonSegment(value: true, label: Text('VD')),
                ],
                selected: {_sortByCr},
                onSelectionChanged: (s) => setState(() => _sortByCr = s.single),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: results.isEmpty
              ? AppEmptyState(
                  icon: Icons.search_off,
                  message: 'Ninguna criatura coincide con lo que buscaste.',
                  actions: [
                    OutlinedButton(
                      onPressed: _clearFilters,
                      child: const Text('Limpiar filtros'),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: results.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: pal.hairline),
                  itemBuilder: (context, i) {
                    final c = results[i];
                    return ListTile(
                      key: ValueKey('bestiary-${c.id}'),
                      selected: c.id == _selected?.id,
                      selectedTileColor: pal.goldSoft,
                      title: Text(
                        c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        c.kind,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: c.cr == null
                          ? null
                          : Text('VD ${challengeRatingLabel(c.cr!)}'),
                      onTap: () => setState(() => _selected = c),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _detail(BuildContext context, Creature c, {VoidCallback? onBack}) {
    final pal = context.palette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        if (onBack != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Volver al listado'),
            ),
          ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            Text(
              c.name,
              style: const TextStyle(fontFamily: 'Georgia', fontSize: 24),
            ),
            SourceBadge(c.source),
          ],
        ),
        const SizedBox(height: 6),
        Text(c.kind, style: TextStyle(fontSize: 13, color: pal.textMuted)),
        const SizedBox(height: 8),
        // La campaña va escrita en el botón: el combate es de una campaña y el
        // Bestiario no, así que decir a cuál se suma es lo que evita sumar a
        // la equivocada.
        if (widget.campaign case final campaign?)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => _addToCombat(c),
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                'Sumar al combate de ${campaign.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
        else
          Text(
            'Para sumarla a un combate, primero creá una campaña.',
            style: TextStyle(fontSize: 12.5, color: pal.textMuted),
          ),
        const SizedBox(height: 16),

        ...creatureProfileBody(context, widget.repo, c),
      ],
    );
  }
}
