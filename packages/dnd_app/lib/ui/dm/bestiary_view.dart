import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';

/// El bestiario: buscar un monstruo y leer su perfil.
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
/// Es **solo de consulta**. Sumar un monstruo al combate se hace desde Combate,
/// que ya tiene su propio buscador y sabe a qué encuentro sumarlo.
class BestiaryView extends StatefulWidget {
  final ContentRepository repo;

  const BestiaryView({super.key, required this.repo});

  @override
  State<BestiaryView> createState() => _BestiaryViewState();
}

/// Ancho a partir del cual entran la lista y el perfil al mismo tiempo.
///
/// Es más chico que el de la app (900) porque acá se mide el **área de
/// contenido**, que ya viene descontado el panel de 236 px.
const double _splitWidth = 760;

const _todos = '__todos__';

class _BestiaryViewState extends State<BestiaryView> {
  final _searchController = TextEditingController();
  String _query = '';
  String _type = _todos;
  Creature? _selected;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// El catálogo que ve el DM. `creaturesSorted` ya deja afuera las
  /// invocaciones por fórmula, cuyas CA y PG dependen de quien las invoca y no
  /// significan nada sueltas.
  List<Creature> get _all => widget.repo.creaturesSorted;

  List<Creature> get _results {
    final needle = foldForSearch(_query.trim());
    return [
      for (final c in _all)
        if ((_type == _todos || c.creatureType?.id == _type) &&
            (needle.isEmpty || foldForSearch(c.name).contains(needle)))
          c,
    ];
  }

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
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            results.length == 1 ? '1 criatura' : '${results.length} criaturas',
            style: TextStyle(fontSize: 12, color: pal.textMuted),
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
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _query = '';
                          _type = _todos;
                        });
                      },
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
        const SizedBox(height: 16),

        ...creatureProfileBody(context, c),
      ],
    );
  }
}
