import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../../../api/api_client.dart';
import '../../../api/api_exception.dart';
import '../../../api/api_models.dart';
import '../../../creation/creation_wizard.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_widgets.dart';

/// Piezas que comparten las pantallas de PNJ: cómo se nombra el tipo de un
/// PNJ, qué retrato lo representa, sus números de combate y el flujo de
/// creación.

/// La línea que dice qué es un PNJ, bajo su nombre: «Sin estadísticas»,
/// «Caballero · CA 18 · PG 52» o «Ficha de personaje · Mago 7».
String npcTypeLine(Npc npc, Character? sheet, ContentRepository repo) {
  switch (npc.sheetKind) {
    case NpcSheetKind.none:
      return NpcSheetKind.none.label;
    case NpcSheetKind.block:
      final block = npc.block;
      if (block == null) return NpcSheetKind.block.label;
      final base = npc.baseCreatureName ?? block.name;
      return '$base · CA ${block.ac} · PG ${block.hp}';
    case NpcSheetKind.character:
      if (sheet == null) return NpcSheetKind.character.label;
      final classes = sheet.classHistory
          .toSet()
          .map(
            (id) =>
                '${repo.characterClass(id)?.name ?? id} ${sheet.classLevel(id)}',
          )
          .join(' · ');
      return 'Ficha de personaje · $classes';
  }
}

/// El retrato que representa al PNJ: el propio, o el de su ficha si la tiene.
String? npcPortraitKey(Npc npc, Character? sheet) =>
    npc.sheetKind == NpcSheetKind.character
    ? sheet?.portraitPaths.firstOrNull
    : npc.portraitPaths.firstOrNull;

/// PG máximos con los que el PNJ entra a un combate, o 0 si no tiene con qué
/// pelear. Un bloque recién creado y todavía vacío cuenta como sin PG: entra
/// neutral hasta que el DM lo complete.
int npcMaxHp(Npc npc, Character? sheet, ContentRepository repo) {
  switch (npc.sheetKind) {
    case NpcSheetKind.none:
      return 0;
    case NpcSheetKind.block:
      final block = npc.block;
      if (block == null) return 0;
      try {
        return block.resolve(const CreatureVars({})).maxHp;
      } on FormatException {
        return 0;
      }
    case NpcSheetKind.character:
      return sheet == null ? 0 : CharacterCompiler(repo).compile(sheet).maxHp;
  }
}

/// La CA a mostrar en la mesa, o `null` si no tiene.
String? npcArmorClass(Npc npc, Character? sheet, ContentRepository repo) =>
    switch (npc.sheetKind) {
      NpcSheetKind.none => null,
      NpcSheetKind.block => npc.block?.ac,
      NpcSheetKind.character =>
        sheet == null
            ? null
            : '${CharacterCompiler(repo).compile(sheet).armorClass}',
    };

Color npcStatusColor(NpcStatus status, AppPalette pal) => switch (status) {
  NpcStatus.alive => pal.verdant,
  NpcStatus.dead => pal.crimson,
  NpcStatus.unknown => pal.textMuted,
};

/// Vivo · Muerto · Desconocido en una sola fila. El estado se lee por el texto
/// además del color: quien no distingue el verde del rojo tiene que poder
/// saber igual si el PNJ sigue vivo.
class NpcStatusSelector extends StatelessWidget {
  final NpcStatus status;
  final ValueChanged<NpcStatus>? onChanged;
  final String semanticLabel;

  const NpcStatusSelector({
    super.key,
    required this.status,
    required this.onChanged,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Semantics(
      label: semanticLabel,
      child: SegmentedButton<NpcStatus>(
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(fontSize: 12),
          selectedForegroundColor: npcStatusColor(status, pal),
          selectedBackgroundColor: pal.goldSoft,
        ),
        segments: [
          for (final s in NpcStatus.values)
            ButtonSegment(value: s, label: Text(s.label)),
        ],
        selected: {status},
        onSelectionChanged: onChanged == null
            ? null
            : (selection) => onChanged!(selection.single),
      ),
    );
  }
}

Color combatantSideColor(CombatantSide side, AppPalette pal) => switch (side) {
  CombatantSide.ally => pal.verdant,
  CombatantSide.enemy => pal.crimson,
  CombatantSide.neutral => pal.textMuted,
};

/// Aliado · Enemigo · Neutral. Sin [side] no hay ninguno elegido: un PNJ no
/// tiene bando por defecto. Con [onChanged] en null queda fijo.
class SideSelector extends StatelessWidget {
  final CombatantSide? side;
  final ValueChanged<CombatantSide>? onChanged;
  final String label;

  const SideSelector({
    super.key,
    required this.side,
    required this.onChanged,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Semantics(
      label: label,
      child: SegmentedButton<CombatantSide>(
        emptySelectionAllowed: true,
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(fontSize: 12),
          selectedForegroundColor: side == null
              ? null
              : combatantSideColor(side!, pal),
          selectedBackgroundColor: pal.goldSoft,
        ),
        segments: [
          for (final s in CombatantSide.values)
            ButtonSegment(value: s, label: Text(s.label)),
        ],
        selected: {?side},
        onSelectionChanged: onChanged == null
            ? null
            : (selection) {
                if (selection.isNotEmpty) onChanged!(selection.single);
              },
      ),
    );
  }
}

/// Los tags de un PNJ como pastillas neutras.
Widget npcTagPills(Npc npc) => Wrap(
  spacing: 6,
  runSpacing: 4,
  children: [for (final tag in npc.tags) GoldPill(tag, highlighted: false)],
);

/// Lo que se eligió en el diálogo «Nuevo PNJ».
typedef NewNpcChoice = ({String name, NpcSheetKind kind, Creature? base});

/// Un bloque para empezar de cero. CA y PG en 0 y no en blanco: el evaluador
/// de fórmulas no acepta un campo vacío, y un 0 dice «falta completar» sin
/// inventar un número que el DM pueda confundir con uno elegido.
Creature emptyNpcBlock(String name) => Creature(
  id: 'bloque-propio',
  name: name,
  source: ContentSource.homebrew,
  ac: '0',
  hp: '0',
  availableToCharacters: false,
);

/// Crea un PNJ de principio a fin: el diálogo, el creador de personajes si
/// hace falta, el alta en el servidor y, con [campaignId], el vínculo con esa
/// campaña. Devuelve el PNJ creado, o `null` si se canceló o falló (el error
/// ya se mostró).
Future<NpcEntry?> createNpcFlow(
  BuildContext context, {
  required ApiClient api,
  required ContentRepository repo,
  String? campaignId,
}) async {
  final choice = await showNewNpcDialog(context, repo: repo);
  if (choice == null || !context.mounted) return null;

  Character? sheet;
  if (choice.kind == NpcSheetKind.character) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreationWizard(
          repo: repo,
          initialName: choice.name,
          onCreate: (created) => sheet = created,
        ),
      ),
    );
    if (sheet == null || !context.mounted) return null;
  }

  // El creador arranca con el nombre del diálogo, así que el que sale de ahí
  // es el último que eligió el DM: si lo retocó en Detalles, vale el retoque.
  final name = sheet?.name ?? choice.name;
  final base = choice.base;
  final npc = Npc(
    id: 'nuevo',
    name: name,
    sheetKind: choice.kind,
    block: choice.kind == NpcSheetKind.block
        ? (base == null
              ? emptyNpcBlock(choice.name)
              : Creature.fromJson(base.toJson()))
        : null,
    baseCreatureId: choice.kind == NpcSheetKind.block ? base?.id : null,
    baseCreatureName: choice.kind == NpcSheetKind.block ? base?.name : null,
  );
  try {
    final created = await api.createNpc(npc, sheet: sheet);
    if (campaignId != null) {
      await api.linkCampaignNpc(campaignId, created.npc.id);
    }
    return created;
  } on ApiException catch (e) {
    if (context.mounted) {
      showAppMessage(context, e.message, tone: AppMessageTone.error);
    }
    return null;
  }
}

Future<NewNpcChoice?> showNewNpcDialog(
  BuildContext context, {
  required ContentRepository repo,
}) => showDialog<NewNpcChoice>(
  context: context,
  builder: (_) => _NewNpcDialog(repo: repo),
);

class _NewNpcDialog extends StatefulWidget {
  final ContentRepository repo;
  const _NewNpcDialog({required this.repo});

  @override
  State<_NewNpcDialog> createState() => _NewNpcDialogState();
}

class _NewNpcDialogState extends State<_NewNpcDialog> {
  final _name = TextEditingController();
  final _search = TextEditingController();
  NpcSheetKind _kind = NpcSheetKind.none;
  Creature? _base;

  @override
  void dispose() {
    _name.dispose();
    _search.dispose();
    super.dispose();
  }

  bool get _ready => _name.text.trim().isNotEmpty;

  void _submit() {
    if (!_ready) return;
    Navigator.of(context).pop((
      name: _name.text.trim(),
      kind: _kind,
      base: _kind == NpcSheetKind.block ? _base : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return AppDialog(
      title: 'Nuevo PNJ',
      width: 600,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nombre'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 18),
          const Eyebrow('¿Qué ficha lleva?'),
          RadioGroup<NpcSheetKind>(
            groupValue: _kind,
            onChanged: (v) => setState(() => _kind = v ?? _kind),
            child: Column(
              children: [
                for (final kind in NpcSheetKind.values)
                  RadioListTile<NpcSheetKind>(
                    value: kind,
                    contentPadding: EdgeInsets.zero,
                    title: Text(switch (kind) {
                      NpcSheetKind.none => 'PNJ sin estadísticas',
                      NpcSheetKind.block => 'PNJ con bloque',
                      NpcSheetKind.character => 'Personaje jugable',
                    }),
                    subtitle: Text(switch (kind) {
                      NpcSheetKind.none =>
                        'Solo nombre, trasfondo y notas. El tabernero, el '
                            'alcalde.',
                      NpcSheetKind.block =>
                        'Un bloque propio como los del bestiario: copiá el de '
                            'una criatura y retocalo, o arrancá vacío.',
                      NpcSheetKind.character =>
                        'Pasa por el creador de personajes: especie, clase, '
                            'niveles y dotes. El villano de un trasfondo.',
                    }),
                  ),
              ],
            ),
          ),
          if (_kind == NpcSheetKind.block) ...[
            const SizedBox(height: 6),
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                labelText: 'Partir de una criatura (opcional)',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 180,
              child: ListView(
                children: [
                  ListTile(
                    dense: true,
                    selected: _base == null,
                    title: const Text('Bloque vacío'),
                    subtitle: const Text('Lo completás después.'),
                    onTap: () => setState(() => _base = null),
                  ),
                  for (final creature
                      in widget.repo.creaturesSorted
                          .where(
                            (c) => c.name.toLowerCase().contains(
                              _search.text.trim().toLowerCase(),
                            ),
                          )
                          .take(30))
                    ListTile(
                      dense: true,
                      selected: _base?.id == creature.id,
                      title: Text(creature.name),
                      subtitle: Text('CA ${creature.ac} · PG ${creature.hp}'),
                      onTap: () => setState(() => _base = creature),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'El tipo no se cambia después: define con qué se edita.',
            style: TextStyle(fontSize: 12, color: pal.textMuted),
          ),
        ],
      ),
      actions: [
        DialogAction(
          'Cancelar',
          keyHint: 'Esc',
          onPressed: () => Navigator.of(context).pop(),
        ),
        DialogAction(
          _kind == NpcSheetKind.character ? 'Continuar al creador' : 'Crear',
          primary: true,
          onPressed: _ready ? _submit : null,
        ),
      ],
    );
  }
}
