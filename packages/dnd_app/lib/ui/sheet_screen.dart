import 'dart:io';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../data/characters_controller.dart';
import '../levelup/level_up_screen.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import 'portrait_screen.dart';

/// Condiciones 2024 (id → etiqueta) para el gestor de estados en combate.
const _conditions = {
  'blinded': 'Cegado',
  'charmed': 'Hechizado',
  'deafened': 'Ensordecido',
  'frightened': 'Asustado',
  'grappled': 'Agarrado',
  'incapacitated': 'Incapacitado',
  'invisible': 'Invisible',
  'paralyzed': 'Paralizado',
  'petrified': 'Petrificado',
  'poisoned': 'Envenenado',
  'prone': 'Derribado',
  'restrained': 'Apresado',
  'stunned': 'Aturdido',
  'unconscious': 'Inconsciente',
};

/// Ficha editable. Combate/Inventario/Notas modifican el personaje y disparan
/// el autoguardado del [CharactersController]. General lee de la [ComputedSheet].
class SheetScreen extends StatefulWidget {
  final Character character;
  final ContentRepository repo;
  final CharactersController controller;
  const SheetScreen({
    super.key,
    required this.character,
    required this.repo,
    required this.controller,
  });

  @override
  State<SheetScreen> createState() => _SheetScreenState();
}

class _SheetScreenState extends State<SheetScreen> {
  late Character _c = widget.character;

  ContentRepository get repo => widget.repo;
  CharactersController get ctrl => widget.controller;
  ComputedSheet get sheet => CharacterCompiler(repo).compile(_c);

  final _amountCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  int get _amount => int.tryParse(_amountCtrl.text.trim()) ?? 0;

  void _mutateCombat(void Function() change) {
    setState(change);
    ctrl.touch(_c);
  }

  void _replace(Character next) {
    setState(() => _c = next);
    ctrl.replace(next);
  }

  void _openLevelUp() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LevelUpScreen(
          character: _c,
          repo: repo,
          onDone: _replace,
        ),
      ),
    );
  }

  void _openPortrait() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PortraitScreen(
          character: _c,
          repo: repo,
          onUpdated: _replace,
        ),
      ),
    );
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${_c.name} · Nivel ${_c.level}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.face_retouching_natural),
              tooltip: 'Generar retrato',
              onPressed: _openPortrait,
            ),
            IconButton(
              icon: const Icon(Icons.arrow_upward),
              tooltip: 'Subir de nivel',
              onPressed: _openLevelUp,
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'General'),
              Tab(text: 'Combate'),
              Tab(text: 'Inventario'),
              Tab(text: 'Notas'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildGeneral(),
            _buildCombat(),
            _buildInventory(),
            _buildNotes(),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------- General

  Widget _buildGeneral() {
    final s = sheet;
    final pal = context.palette;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final warnings = CharacterValidator(repo).validate(_c);
    final portrait = _c.portraitPaths.isNotEmpty ? _c.portraitPaths.first : null;
    final hasPortrait = portrait != null && File(portrait).existsSync();
    final race = repo.race(_c.raceId)?.name ?? _c.raceId;
    final klass = repo.characterClass(_c.classId)?.name ?? _c.classId;
    final bg = repo.background(_c.backgroundId)?.name ?? '';
    final subtitle = [race, klass, if (bg.isNotEmpty) bg].join(' · ');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Medallion(
              image: hasPortrait ? FileImage(File(portrait)) : null,
              fallback: _c.name.characters.first,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_c.name,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: muted)),
                ],
              ),
            ),
            Column(
              children: [
                Text('${_c.level}',
                    style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 28,
                        height: 1,
                        color: pal.gold)),
                const SizedBox(height: 4),
                const Eyebrow('Nivel'),
              ],
            ),
          ],
        ),
        const SectionRule(),
        _statPlaques(s),
        const SectionRule(),
        const Eyebrow('Características'),
        _abilityRow(s),
        const SizedBox(height: 20),
        if (s.attacks.isNotEmpty) ...[
          const Eyebrow('Ataques'),
          DenseRows(children: [for (final a in s.attacks) _attackRow(a)]),
          const SizedBox(height: 20),
        ],
        if (s.passives.isNotEmpty) ...[
          const Eyebrow('Rasgos pasivos'),
          DenseRows(children: [for (final t in s.passives) _passiveRow(t)]),
          const SizedBox(height: 20),
        ],
        if (s.skillProficiencies.isNotEmpty) ...[
          const Eyebrow('Competencias'),
          _chips(s.skillProficiencies.map(_title).toList()),
        ],
        if (warnings.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Eyebrow('Advertencias'),
          DenseRows(children: [
            for (final w in warnings)
              ListTile(
                dense: true,
                leading: Icon(Icons.warning_amber, color: pal.crimson),
                title: Text(w.message),
              ),
          ]),
        ],
      ],
    );
  }

  Widget _statPlaques(ComputedSheet s) {
    final pal = context.palette;
    final c = _c.combat;
    Widget box(Widget child) => SizedBox(width: 104, child: child);
    return Wrap(spacing: 10, runSpacing: 10, children: [
      box(StatPlaque(
        label: 'Puntos de golpe',
        value: '${c.currentHp}/${s.maxHp}',
        valueColor: pal.crimson,
        footer: ThinBar(
          ratio: s.maxHp == 0 ? 0 : c.currentHp / s.maxHp,
          color: pal.crimson,
          track: pal.plaque,
        ),
      )),
      box(_acPlaque(s.armorClass)),
      box(StatPlaque(label: 'Velocidad', value: '${s.speed}')),
      box(StatPlaque(label: 'Iniciativa', value: _signed(s.initiative))),
      box(StatPlaque(label: 'Perc. pasiva', value: '${s.passivePerception}')),
      box(StatPlaque(label: 'Competencia', value: '+${s.proficiencyBonus}')),
      if (s.darkvision != null)
        box(StatPlaque(label: 'Visión osc.', value: '${s.darkvision}')),
    ]);
  }

  Widget _acPlaque(int ac) {
    final pal = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: pal.plaque,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.hairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('ARMADURA',
              style: TextStyle(
                  fontSize: 10, letterSpacing: 1.2, color: pal.textMuted)),
          const SizedBox(height: 6),
          ShieldBadge('$ac'),
        ],
      ),
    );
  }

  Widget _abilityRow(ComputedSheet s) {
    final a = Ability.values;
    return Row(children: [
      for (var i = 0; i < a.length; i++) ...[
        Expanded(
          child: AbilityPlaque(
            abbr: a[i].abbr,
            score: s.abilityScores[a[i]]!,
            modifier: s.abilityModifiers[a[i]]!,
            saveProficient: s.savingThrowProficiencies.contains(a[i]),
          ),
        ),
        if (i < a.length - 1) const SizedBox(width: 8),
      ],
    ]);
  }

  Widget _attackRow(Attack a) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.name, style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 3),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('${a.damage} ${_title(a.damageType)}',
                      style: TextStyle(color: muted, fontSize: 13)),
                  if (a.mastery != null)
                    GoldPill('Maestría: ${_title(a.mastery!)}'),
                ],
              ),
            ],
          ),
        ),
        Text(_signed(a.attackBonus),
            style: TextStyle(
                fontFamily: 'Georgia', fontSize: 20, color: context.palette.gold)),
      ]),
    );
  }

  Widget _passiveRow(PassiveTrait t) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.name, style: const TextStyle(fontWeight: FontWeight.w500)),
          if (t.description.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(t.description, style: TextStyle(color: muted, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------- Combate

  Widget _buildCombat() {
    final s = sheet;
    final combat = _c.combat;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _HpCard(current: combat.currentHp, max: s.maxHp, temp: combat.tempHp),
        const SizedBox(height: 12),
        _hpControls(s),
        const SizedBox(height: 16),
        if (combat.currentHp <= 0) ...[
          const _SectionTitle('Salvaciones de muerte'),
          _deathSaves(combat),
          const SizedBox(height: 16),
        ],
        const _SectionTitle('Descansos y recuperación'),
        Text(
          'El descanso corto no cura PG: recarga recursos de recarga corta. '
          'Para curarte, gastá dados de golpe.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
            onPressed: () => _shortRest(s),
            icon: const Icon(Icons.local_cafe),
            label: const Text('Descanso corto'),
          ),
          FilledButton.icon(
            onPressed: () => _longRest(s),
            icon: const Icon(Icons.bedtime),
            label: const Text('Descanso largo'),
          ),
          OutlinedButton.icon(
            onPressed: _c.combat.hitDiceUsed >= _c.level
                ? null
                : () {
                    final healed =
                        CombatOps.spendHitDie(_c.combat, s, _c.level);
                    _mutateCombat(() {});
                    _snack('Recuperaste $healed PG (dado de golpe)');
                  },
            icon: const Icon(Icons.casino),
            label: Text(
                'Dado de golpe (${_c.level - _c.combat.hitDiceUsed}/${_c.level})'),
          ),
        ]),
        const SizedBox(height: 16),
        const _SectionTitle('Recursos'),
        if (s.resources.isEmpty)
          const Text('—')
        else
          ...s.resources.map(_resourceRow),
        const SizedBox(height: 16),
        const _SectionTitle('Condiciones'),
        _conditionChips(combat),
        const SizedBox(height: 16),
        const _SectionTitle('Ataques'),
        ...s.attacks.map((a) => Card(
              child: ListTile(
                title: Text(a.name),
                subtitle: Text('Daño ${a.damage} (${_title(a.damageType)})'
                    '${a.mastery != null ? ' · Maestría: ${_title(a.mastery!)}' : ''}'),
                trailing: Text(_signed(a.attackBonus),
                    style: Theme.of(context).textTheme.titleLarge),
              ),
            )),
      ],
    );
  }

  void _shortRest(ComputedSheet s) {
    final restored = s.resources
        .where((r) => r.recharge == RechargeOn.shortRest)
        .map((r) => r.name)
        .toList();
    _mutateCombat(() => CombatOps.shortRest(_c.combat, s.resources));
    final msg = restored.isEmpty
        ? 'Descanso corto. No cura PG: gastá dados de golpe para curarte.'
        : 'Descanso corto: recuperaste ${restored.join(", ")}. '
            'Para curarte, gastá dados de golpe.';
    _snack(msg);
  }

  void _longRest(ComputedSheet s) {
    _mutateCombat(
        () => CombatOps.longRest(_c.combat, s.maxHp, s.resources, _c.level));
    _snack('Descanso largo: PG al máximo y recursos recargados.');
  }

  Widget _hpControls(ComputedSheet s) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 90,
          child: TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Cantidad',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer),
          onPressed: () => _mutateCombat(() {
            CombatOps.applyDamage(_c.combat, _amount);
            _amountCtrl.clear();
          }),
          icon: const Icon(Icons.remove),
          label: const Text('Daño'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => _mutateCombat(() {
            CombatOps.applyHealing(_c.combat, s.maxHp, _amount);
            _amountCtrl.clear();
          }),
          icon: const Icon(Icons.add),
          label: const Text('Curar'),
        ),
        OutlinedButton(
          onPressed: () => _mutateCombat(() {
            CombatOps.setTempHp(_c.combat, _amount);
            _amountCtrl.clear();
          }),
          child: const Text('PG temp'),
        ),
      ],
    );
  }

  Widget _deathSaves(CombatState combat) {
    Widget pips(int filled, Color color) => Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
              3,
              (i) => Icon(
                    i < filled ? Icons.circle : Icons.circle_outlined,
                    color: color,
                    size: 20,
                  )),
        );
    return Row(
      children: [
        pips(combat.deathSuccesses, Colors.greenAccent),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () => _mutateCombat(() {
            final r = CombatOps.recordDeathSave(_c.combat, success: true);
            if (r == 'stable') _snack('¡Estabilizado!');
          }),
          child: const Text('+Éxito'),
        ),
        const Spacer(),
        pips(combat.deathFailures, Colors.redAccent),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () => _mutateCombat(() {
            final r = CombatOps.recordDeathSave(_c.combat, success: false);
            if (r == 'dead') _snack('El personaje ha muerto.');
          }),
          child: const Text('+Fallo'),
        ),
      ],
    );
  }

  Widget _resourceRow(CharacterResource r) {
    final used = _c.combat.resourceUsage[r.id] ?? 0;
    return Card(
      child: ListTile(
        dense: true,
        title: Text(r.name),
        subtitle: Row(
          children: List.generate(
              r.max,
              (i) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      i < r.max - used ? Icons.bolt : Icons.bolt_outlined,
                      size: 18,
                      color: i < r.max - used
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                    ),
                  )),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Usar',
              onPressed: used >= r.max
                  ? null
                  : () => _mutateCombat(
                      () => _c.combat.resourceUsage[r.id] = used + 1),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            IconButton(
              tooltip: 'Restaurar',
              onPressed: used <= 0
                  ? null
                  : () => _mutateCombat(
                      () => _c.combat.resourceUsage[r.id] = used - 1),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conditionChips(CombatState combat) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _conditions.entries.map((e) {
        final active = combat.conditions.contains(e.key);
        return FilterChip(
          label: Text(e.value),
          selected: active,
          onSelected: (v) => _mutateCombat(() {
            if (v) {
              combat.conditions.add(e.key);
            } else {
              combat.conditions.remove(e.key);
            }
          }),
        );
      }).toList(),
    );
  }

  // ----------------------------------------------------------- Inventario

  Widget _buildInventory() {
    final armors = repo.armor.values.where((a) => !a.isShield).toList();
    final weapons = repo.weapons.values.toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const _SectionTitle('Armadura equipada'),
        DropdownButton<String?>(
          isExpanded: true,
          value: _c.equippedArmorId,
          hint: const Text('Sin armadura'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Sin armadura')),
            ...armors.map((a) => DropdownMenuItem(
                value: a.id, child: Text('${a.name} (CA ${a.baseAc})'))),
          ],
          onChanged: (v) => _replace(_c.copyWith(equippedArmorId: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Escudo (+2 CA)'),
          value: _c.shieldEquipped,
          onChanged: (v) => _replace(_c.copyWith(shieldEquipped: v)),
        ),
        const SizedBox(height: 12),
        const _SectionTitle('Arma equipada'),
        DropdownButton<String>(
          isExpanded: true,
          value:
              _c.equippedWeaponIds.isEmpty ? null : _c.equippedWeaponIds.first,
          hint: const Text('Sin arma'),
          items: weapons
              .map((w) => DropdownMenuItem(
                  value: w.id, child: Text('${w.name} (${w.damageDice})')))
              .toList(),
          onChanged: (v) =>
              _replace(_c.copyWith(equippedWeaponIds: [?v])),
        ),
        const SizedBox(height: 16),
        Text('CA actual: ${sheet.armorClass}',
            style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }

  // ---------------------------------------------------------------- Notas

  Widget _buildNotes() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextFormField(
        initialValue: _c.notes,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        decoration: const InputDecoration(
          labelText: 'Notas del personaje',
          alignLabelWithHint: true,
          border: OutlineInputBorder(),
        ),
        onChanged: (v) {
          _c.notes = v;
          ctrl.touch(_c);
        },
      ),
    );
  }

  Widget _chips(List<String> labels) => labels.isEmpty
      ? const Text('—')
      : Wrap(
          spacing: 6,
          runSpacing: 6,
          children: labels.map((l) => Chip(label: Text(l))).toList());
}

// ---------------------------------------------------------------- Widgets

class _HpCard extends StatelessWidget {
  final int current;
  final int max;
  final int temp;
  const _HpCard({required this.current, required this.max, required this.temp});

  @override
  Widget build(BuildContext context) {
    final ratio = max == 0 ? 0.0 : (current / max).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('$current',
                    style: Theme.of(context).textTheme.displaySmall),
                Text(' / $max PG',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (temp > 0)
                  Chip(
                    avatar: const Icon(Icons.shield, size: 16),
                    label: Text('+$temp temp'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: ratio, minHeight: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

String _signed(int v) => v >= 0 ? '+$v' : '$v';

String _title(String s) => s.isEmpty
    ? s
    : s
        .split(RegExp(r'[-_ ]'))
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
