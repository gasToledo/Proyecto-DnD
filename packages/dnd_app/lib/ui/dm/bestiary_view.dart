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
                      trailing: c.cr == null ? null : Text('VD ${_cr(c.cr!)}'),
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

        // Los números que se comparan entre sí van en `StatTile`, que los pinta
        // en sans con cifras tabulares. Georgia queda para el nombre.
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final tile in [
              (label: 'CA', value: c.ac, icon: Icons.shield_outlined),
              (label: 'PG', value: c.hp, icon: Icons.favorite_outline),
              if (c.cr != null)
                (
                  label: 'VD',
                  value: _cr(c.cr!),
                  icon: Icons.local_fire_department_outlined,
                ),
              if (c.passivePerceptionValue case final p?)
                (
                  label: 'Perc. pasiva',
                  value: '$p',
                  icon: Icons.visibility_outlined,
                ),
            ])
              SizedBox(
                width: 120,
                child: StatTile(
                  icon: tile.icon,
                  label: tile.label,
                  value: tile.value,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in Ability.values)
              AbilityPlaque(
                abbr: a.abbr,
                score: c.abilityScores[a] ?? 10,
                modifier: c.abilityModifierFor(a),
                saveProficient: c.savingThrows.containsKey(a),
              ),
          ],
        ),
        const SizedBox(height: 16),

        DenseRows(
          children: [
            if (c.speed.isNotEmpty) _row('Velocidad', c.speed),
            if (c.savingThrows.isNotEmpty)
              _row(
                'Salvaciones',
                [
                  for (final e in c.savingThrows.entries)
                    '${e.key.abbr} ${_signed(e.value)}',
                ].join(', '),
              ),
            if (c.skills.isNotEmpty)
              _row(
                'Habilidades',
                [
                  for (final e in c.skills.entries)
                    '${e.key.label} ${_signed(e.value)}',
                ].join(', '),
              ),
            if (c.senses.isNotEmpty) _row('Sentidos', c.senses),
            if (c.languages.isNotEmpty) _row('Idiomas', c.languages),
            if (c.defenses.isNotEmpty) _row('Defensas', c.defenses),
          ],
        ),

        for (final trait in c.traits) ...[
          if (trait == c.traits.first) ...[
            const SizedBox(height: 16),
            const Eyebrow('Atributos'),
          ],
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${trait.name}. ',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  TextSpan(text: trait.description),
                ],
              ),
              style: TextStyle(fontSize: 13, color: pal.textMuted),
            ),
          ),
        ],

        // Agrupadas por tipo y en el orden del libro: un perfil es un formato
        // que el DM reconoce de un vistazo, y cambiarlo cuesta más de lo que
        // rinde.
        for (final kind in CreatureActionKind.values)
          if (c.actions.where((a) => a.kind == kind).toList() case final group
              when group.isNotEmpty) ...[
            const SizedBox(height: 16),
            Eyebrow(_sectionLabel(kind, c)),
            for (final a in group)
              CreatureActionRow(
                name: a.name,
                description: a.description,
                attackBonus: a.attackBonus == null ? null : '+${a.attackBonus}',
                damage: a.damage,
                damageType: a.damageType,
                reach: a.reach,
              ),
          ],
      ],
    );
  }

  /// El encabezado de las legendarias lleva el presupuesto por ronda, que es la
  /// forma en que lo imprime el libro y el dato que el DM necesita ahí mismo.
  String _sectionLabel(CreatureActionKind kind, Creature c) {
    if (kind != CreatureActionKind.legendary) {
      return switch (kind) {
        CreatureActionKind.action => 'Acciones',
        CreatureActionKind.bonus => 'Acciones adicionales',
        CreatureActionKind.reaction => 'Reacciones',
        _ => 'Acciones',
      };
    }
    final uses = c.legendaryActionsPerRound;
    return uses == null
        ? 'Acciones legendarias'
        : 'Acciones legendarias · $uses por ronda';
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          TextSpan(text: value),
        ],
      ),
      style: const TextStyle(fontSize: 13),
    ),
  );
}

String _signed(int v) => v >= 0 ? '+$v' : '$v';

/// El valor de desafío se guarda como número para poder compararlo, pero se
/// lee como la fracción que imprime el libro.
String _cr(num cr) {
  if (cr == 0.125) return '1/8';
  if (cr == 0.25) return '1/4';
  if (cr == 0.5) return '1/2';
  return cr == cr.roundToDouble() ? '${cr.round()}' : '$cr';
}
