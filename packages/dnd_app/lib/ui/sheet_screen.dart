import 'dart:io';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/characters_controller.dart';
import '../levelup/level_up_screen.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import '../theme/class_visuals.dart';
import 'portrait_screen.dart';
import 'spell_edit_screen.dart';

/// Condición: etiqueta + qué le hace al personaje (reglas 2024), para el
/// gestor de estados en combate.
class _ConditionInfo {
  final String label;
  final String description;
  const _ConditionInfo(this.label, this.description);
}

const _conditions = <String, _ConditionInfo>{
  'blinded': _ConditionInfo(
    'Cegado',
    'No podés ver y fallás automáticamente cualquier prueba que requiera vista. '
        'Los ataques contra vos tienen ventaja, y tus ataques tienen desventaja.',
  ),
  'charmed': _ConditionInfo(
    'Hechizado',
    'No podés atacar a quien te hechizó ni dirigirle habilidades u efectos '
        'dañinos. Esa criatura tiene ventaja en pruebas sociales contra vos.',
  ),
  'deafened': _ConditionInfo(
    'Ensordecido',
    'No podés oír y fallás automáticamente cualquier prueba que requiera oído.',
  ),
  'frightened': _ConditionInfo(
    'Asustado',
    'Tenés desventaja en pruebas de característica y ataques mientras la '
        'fuente de tu miedo esté a la vista. No podés acercarte voluntariamente a ella.',
  ),
  'grappled': _ConditionInfo(
    'Agarrado',
    'Tu velocidad se vuelve 0 y no podés beneficiarte de ningún bonus a la '
        'velocidad. La condición termina si quien te agarra queda incapacitado.',
  ),
  'incapacitated': _ConditionInfo(
    'Incapacitado',
    'No podés realizar acciones ni reacciones. (En 2024 tampoco te movés ni hablás.)',
  ),
  'invisible': _ConditionInfo(
    'Invisible',
    'Sos imposible de ver sin magia o sentidos especiales. A efectos de '
        'esconderte, se te considera fuertemente oscurecido. Tus ataques tienen '
        'ventaja; los ataques contra vos tienen desventaja.',
  ),
  'paralyzed': _ConditionInfo(
    'Paralizado',
    'Estás incapacitado y no podés moverte ni hablar. Fallás automáticamente '
        'las salvaciones de Fuerza y Destreza. Los ataques contra vos tienen '
        'ventaja, y todo impacto cuerpo a cuerpo es crítico si el atacante está a 5 pies.',
  ),
  'petrified': _ConditionInfo(
    'Petrificado',
    'Te transformás en sustancia sólida inanimada (junto a tu equipo). '
        'Incapacitado, no podés moverte ni hablar, sos inconsciente de tu entorno. '
        'Los ataques contra vos tienen ventaja, fallás salvaciones de Fuerza y '
        'Destreza, tenés resistencia a todo el daño e inmunidad a veneno y enfermedad.',
  ),
  'poisoned': _ConditionInfo(
    'Envenenado',
    'Tenés desventaja en tiradas de ataque y en pruebas de característica.',
  ),
  'prone': _ConditionInfo(
    'Derribado',
    'Solo podés moverte arrastrándote (o levantarte). Tenés desventaja al '
        'atacar. Los ataques cuerpo a cuerpo contra vos tienen ventaja; los '
        'ataques a distancia contra vos tienen desventaja.',
  ),
  'restrained': _ConditionInfo(
    'Apresado',
    'Tu velocidad se vuelve 0. Los ataques contra vos tienen ventaja y tus '
        'ataques tienen desventaja. Tenés desventaja en salvaciones de Destreza.',
  ),
  'stunned': _ConditionInfo(
    'Aturdido',
    'Estás incapacitado, no podés moverte y hablás solo entrecortadamente. '
        'Fallás automáticamente las salvaciones de Fuerza y Destreza. Los '
        'ataques contra vos tienen ventaja.',
  ),
  'unconscious': _ConditionInfo(
    'Inconsciente',
    'Estás incapacitado, no podés moverte ni hablar, y no sos consciente de tu '
        'entorno. Soltás lo que sostenías y caés derribado. Fallás automáticamente '
        'las salvaciones de Fuerza y Destreza. Los ataques contra vos tienen '
        'ventaja, y todo impacto cuerpo a cuerpo es crítico si el atacante está a 5 pies.',
  ),
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

  // La ficha compilada depende solo de los datos de construcción, no del estado
  // de combate (que se muta in situ conservando el mismo objeto _c). Se cachea
  // por identidad de _c: las ediciones de equipo/nivel producen un _c nuevo vía
  // copyWith e invalidan la caché, evitando recompilar varias veces por build.
  Character? _sheetFor;
  ComputedSheet? _sheetCache;
  ComputedSheet get sheet {
    if (!identical(_sheetFor, _c)) {
      _sheetCache = CharacterCompiler(repo).compile(_c);
      _sheetFor = _c;
    }
    return _sheetCache!;
  }

  final _amountCtrl = TextEditingController();
  // Controlador propio de las notas: sobrevive los cambios de tab y evita el
  // footgun de TextFormField(initialValue:), que ignora cambios posteriores.
  late final _notesCtrl = TextEditingController(text: widget.character.notes);

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
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

  Future<void> _editName() async {
    final newName = await showRenameDialog(context, _c.name);
    if (newName == null || newName == _c.name) return;
    _replace(_c.copyWith(name: newName));
  }

  void _openLevelUp() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            LevelUpScreen(character: _c, repo: repo, onDone: _replace),
      ),
    );
  }

  void _openPortraitViewer(String path) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, _, _) => _PortraitViewer(path: path),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  void _openPortrait() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PortraitScreen(character: _c, repo: repo, onUpdated: _replace),
      ),
    );
  }

  void _snack(String msg) =>
      showAppMessage(context, msg, duration: const Duration(seconds: 2));

  @override
  Widget build(BuildContext context) {
    final hasSpells = sheet.spellcasting != null;
    return DefaultTabController(
      length: hasSpells ? 5 : 4,
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
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              const Tab(text: 'General'),
              const Tab(text: 'Combate'),
              if (hasSpells) const Tab(text: 'Conjuros'),
              const Tab(text: 'Inventario'),
              const Tab(text: 'Notas'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildGeneral(),
            _buildCombat(),
            if (hasSpells) _buildSpells(),
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
    final portrait = _c.portraitPaths.isNotEmpty
        ? _c.portraitPaths.first
        : null;
    final hasPortrait = portrait != null && File(portrait).existsSync();
    final race = repo.race(_c.raceId)?.name ?? _c.raceId;
    final klassObj = repo.characterClass(_c.classId);
    final klass = klassObj?.name ?? _c.classId;
    final accent = classAccent(klassObj, pal.gold);
    final sub = _c.subclassId == null
        ? null
        : repo.subclass(_c.subclassId!)?.name;
    final klassLine = sub == null ? klass : '$klass ($sub)';
    final bg = repo.background(_c.backgroundId)?.name ?? '';
    final subtitle = [race, klassLine, if (bg.isNotEmpty) bg].join(' · ');

    return PageBody(
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: hasPortrait ? () => _openPortraitViewer(portrait) : null,
              child: MouseRegion(
                cursor: hasPortrait
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
                child: ClassMedallion(
                  klass: klassObj,
                  image: hasPortrait ? FileImage(File(portrait)) : null,
                  fallback: _c.name.characters.first,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: _editName,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _c.name,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.edit_outlined, size: 16, color: muted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(classIcon(klassObj), size: 16, color: accent),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(subtitle, style: TextStyle(color: muted)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Text(
                  '${_c.level}',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 28,
                    height: 1,
                    color: pal.gold,
                  ),
                ),
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
          _chips(s.skillProficiencies.map(Skill.labelFor).toList()),
        ],
        if (warnings.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Eyebrow('Advertencias'),
          DenseRows(
            children: [
              for (final w in warnings)
                ListTile(
                  dense: true,
                  leading: Icon(Icons.warning_amber, color: pal.crimson),
                  title: Text(w.message),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _statPlaques(ComputedSheet s) {
    final pal = context.palette;
    final c = _c.combat;
    Widget box(Widget child) => SizedBox(width: 108, child: child);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        box(
          StatPlaque(
            label: 'Puntos de golpe',
            value: '${c.currentHp}/${s.maxHp}',
            valueColor: pal.crimson,
            footer: ThinBar(
              ratio: s.maxHp == 0 ? 0 : c.currentHp / s.maxHp,
              color: pal.crimson,
              track: pal.plaque,
            ),
          ),
        ),
        box(_acPlaque(s.armorClass)),
        box(StatPlaque(label: 'Velocidad', value: '${s.speed}')),
        box(StatPlaque(label: 'Iniciativa', value: _signed(s.initiative))),
        box(StatPlaque(label: 'Perc. pasiva', value: '${s.passivePerception}')),
        box(StatPlaque(label: 'Competencia', value: '+${s.proficiencyBonus}')),
        if (s.darkvision != null)
          box(StatPlaque(label: 'Visión osc.', value: '${s.darkvision}')),
      ],
    );
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
          Text(
            'ARMADURA',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.2,
              color: pal.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          ShieldBadge('$ac'),
        ],
      ),
    );
  }

  Widget _abilityRow(ComputedSheet s) {
    final a = Ability.values;
    return Row(
      children: [
        for (var i = 0; i < a.length; i++) ...[
          Expanded(
            child: Tooltip(
              message: '${a[i].label}\n${a[i].description}',
              waitDuration: const Duration(milliseconds: 400),
              child: AbilityPlaque(
                abbr: a[i].abbr,
                score: s.abilityScores[a[i]]!,
                modifier: s.abilityModifiers[a[i]]!,
                saveProficient: s.savingThrowProficiencies.contains(a[i]),
              ),
            ),
          ),
          if (i < a.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _attackRow(Attack a) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${a.damage} ${_title(a.damageType)}',
                      style: TextStyle(color: muted, fontSize: 13),
                    ),
                    if (a.mastery != null)
                      GoldPill('Maestría: ${_title(a.mastery!)}'),
                  ],
                ),
              ],
            ),
          ),
          Text(
            _signed(a.attackBonus),
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 20,
              color: context.palette.gold,
            ),
          ),
        ],
      ),
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
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return PageBody(
      children: [
        _hpPanel(s, combat),
        const SizedBox(height: 14),
        _hpControls(s),
        const SizedBox(height: 22),
        if (combat.currentHp <= 0) ...[
          const Eyebrow('Salvaciones de muerte'),
          _deathSaves(combat),
          const SizedBox(height: 22),
        ],
        const Eyebrow('Descansos y recuperación'),
        Text(
          'El descanso corto no cura PG: recarga recursos de recarga corta. '
          'Para curarte, gastá dados de golpe.',
          style: TextStyle(fontSize: 13, color: muted),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _shortRest(s),
              icon: const Icon(Icons.local_cafe, size: 18),
              label: const Text('Descanso corto'),
            ),
            FilledButton.icon(
              onPressed: () => _longRest(s),
              icon: const Icon(Icons.bedtime, size: 18),
              label: const Text('Descanso largo'),
            ),
            OutlinedButton.icon(
              onPressed: _c.combat.hitDiceUsed >= _c.level
                  ? null
                  : () {
                      final healed = CombatOps.spendHitDie(
                        _c.combat,
                        s,
                        _c.level,
                      );
                      _mutateCombat(() {});
                      _snack('Recuperaste $healed PG (dado de golpe)');
                    },
              icon: const Icon(Icons.casino, size: 18),
              label: Text(
                'Dado de golpe (${_c.level - _c.combat.hitDiceUsed}/${_c.level})',
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        if (s.resources.isNotEmpty) ...[
          const Eyebrow('Recursos'),
          DenseRows(children: [for (final r in s.resources) _resourceRow(r)]),
          const SizedBox(height: 22),
        ],
        const Eyebrow('Condiciones'),
        _conditionChips(combat),
        const SizedBox(height: 22),
        if (s.attacks.isNotEmpty) ...[
          const Eyebrow('Ataques'),
          DenseRows(children: [for (final a in s.attacks) _attackRow(a)]),
        ],
      ],
    );
  }

  Widget _hpPanel(ComputedSheet s, CombatState combat) {
    final pal = context.palette;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final ratio = s.maxHp == 0 ? 0.0 : combat.currentHp / s.maxHp;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${combat.currentHp}',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 40,
                  height: 1,
                  color: pal.crimson,
                ),
              ),
              Text(
                ' / ${s.maxHp} PG',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 18,
                  color: muted,
                ),
              ),
              const Spacer(),
              if (combat.tempHp > 0) GoldPill('+${combat.tempHp} temp'),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0, 1),
              minHeight: 8,
              backgroundColor: pal.plaque,
              valueColor: AlwaysStoppedAnimation(pal.crimson),
            ),
          ),
        ],
      ),
    );
  }

  void _shortRest(ComputedSheet s) {
    final restored = s.resources
        .where((r) => r.recharge == RechargeOn.shortRest)
        .map((r) => r.name)
        .toList();
    _mutateCombat(
      () => CombatOps.shortRest(
        _c.combat,
        s.resources,
        spellcasting: s.spellcasting,
      ),
    );
    final msg = restored.isEmpty
        ? 'Descanso corto. No cura PG: gastá dados de golpe para curarte.'
        : 'Descanso corto: recuperaste ${restored.join(", ")}. '
              'Para curarte, gastá dados de golpe.';
    _snack(msg);
  }

  void _longRest(ComputedSheet s) {
    _mutateCombat(
      () => CombatOps.longRest(_c.combat, s.maxHp, s.resources, _c.level),
    );
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
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: context.palette.crimson,
            foregroundColor: Colors.white,
          ),
          onPressed: () => _mutateCombat(() {
            CombatOps.applyDamage(_c.combat, _amount);
            _amountCtrl.clear();
          }),
          icon: const Icon(Icons.remove, size: 18),
          label: const Text('Daño'),
        ),
        OutlinedButton.icon(
          onPressed: () => _mutateCombat(() {
            CombatOps.applyHealing(_c.combat, s.maxHp, _amount);
            _amountCtrl.clear();
          }),
          icon: const Icon(Icons.add, size: 18),
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
        ),
      ),
    );
    return Row(
      children: [
        pips(combat.deathSuccesses, context.palette.gold),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () => _mutateCombat(() {
            final r = CombatOps.recordDeathSave(_c.combat, success: true);
            if (r == 'stable') _snack('¡Estabilizado!');
          }),
          child: const Text('+Éxito'),
        ),
        const Spacer(),
        pips(combat.deathFailures, context.palette.crimson),
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
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final used = _c.combat.resourceUsage[r.id] ?? 0;
    final hasInfo = r.description.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      child: Row(
        children: [
          Expanded(
            child: Tooltip(
              message: hasInfo ? r.description : '',
              waitDuration: const Duration(milliseconds: 400),
              child: InkWell(
                onTap: hasInfo
                    ? () => _showInfoDialog(r.name, r.description)
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          r.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        if (hasInfo) ...[
                          const SizedBox(width: 5),
                          Icon(Icons.info_outline, size: 14, color: muted),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    UsagePips(
                      max: r.max,
                      filled: r.max - used,
                      filledIcon: Icons.bolt,
                      emptyIcon: Icons.bolt_outlined,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SpendRecoverButtons(
            spendTooltip: 'Usar',
            onSpend: used >= r.max
                ? null
                : () => _mutateCombat(
                    () => _c.combat.resourceUsage[r.id] = used + 1,
                  ),
            onRecover: used <= 0
                ? null
                : () => _mutateCombat(
                    () => _c.combat.resourceUsage[r.id] = used - 1,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _conditionChips(CombatState combat) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _conditions.entries.map((e) {
        final active = combat.conditions.contains(e.key);
        return Tooltip(
          message: e.value.description,
          waitDuration: const Duration(milliseconds: 400),
          child: FilterChip(
            label: Text(e.value.label),
            selected: active,
            onSelected: (v) => _mutateCombat(() {
              if (v) {
                combat.conditions.add(e.key);
              } else {
                combat.conditions.remove(e.key);
              }
            }),
          ),
        );
      }).toList(),
    );
  }

  /// Diálogo de información reutilizable (título + contenido desplazable + Cerrar).
  void _infoDialog(String title, Widget content) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(String title, String description) =>
      _infoDialog(title, Text(description));

  // ------------------------------------------------------------- Conjuros

  Widget _buildSpells() {
    final sc = sheet.spellcasting!;
    final combat = _c.combat;
    final pal = context.palette;
    final abbr = sc.ability.abbr;

    final cantrips =
        _c.cantripIds.map((id) => repo.spell(id)).whereType<Spell>().toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final spells =
        _c.spellIds.map((id) => repo.spell(id)).whereType<Spell>().toList()
          ..sort(
            (a, b) => a.level != b.level
                ? a.level.compareTo(b.level)
                : a.name.compareTo(b.name),
          );

    final slotLevels = sc.slotsByLevel.keys.toList()..sort();

    return PageBody(
      children: [
        Row(
          children: [
            const Expanded(child: Eyebrow('Lanzamiento de conjuros')),
            TextButton.icon(
              onPressed: () => _openSpellEditor(sc),
              icon: const Icon(Icons.edit, size: 16),
              label: Text(
                sc.preparation == SpellPreparation.prepared
                    ? 'Preparar'
                    : 'Editar',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: StatPlaque(label: 'CD SALV.', value: '${sc.saveDc}'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatPlaque(
                label: 'ATAQUE',
                value: '${sc.attackBonus >= 0 ? '+' : ''}${sc.attackBonus}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatPlaque(label: 'APTITUD', value: abbr),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          [
            sc.preparation == SpellPreparation.prepared
                ? 'Preparados: ${_c.spellIds.length} / ${sc.preparedCount}'
                : 'Conocidos: ${_c.spellIds.length}',
            if (sc.cantripsKnown > 0)
              'Trucos: ${cantrips.length} / ${sc.cantripsKnown}',
          ].join(' · '),
          style: Theme.of(context).textTheme.bodySmall,
        ),

        if (combat.concentratingOn != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: pal.gold),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.blur_on, size: 18, color: pal.gold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Concentrándote en ${combat.concentratingOn}'),
                ),
                TextButton(
                  onPressed: () =>
                      _mutateCombat(() => CombatOps.endConcentration(combat)),
                  child: const Text('Terminar'),
                ),
              ],
            ),
          ),
        ],

        if (slotLevels.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Eyebrow('Espacios de conjuro'),
          DenseRows(children: [for (final lv in slotLevels) _slotRow(sc, lv)]),
        ],

        if (cantrips.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Eyebrow('Trucos'),
          DenseRows(children: [for (final s in cantrips) _spellRow(s)]),
        ],

        if (spells.isNotEmpty) ...[
          const SizedBox(height: 20),
          Eyebrow(
            sc.preparation == SpellPreparation.prepared
                ? 'Conjuros preparados'
                : 'Conjuros conocidos',
          ),
          DenseRows(children: [for (final s in spells) _spellRow(s)]),
        ],

        if (cantrips.isEmpty && spells.isEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Todavía no elegiste conjuros. Editá al subir de nivel o al crear.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  void _openSpellEditor(Spellcasting sc) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SpellEditScreen(
          character: _c,
          repo: repo,
          spellcasting: sc,
          onSave: (cantrips, spells) =>
              _replace(_c.copyWith(cantripIds: cantrips, spellIds: spells)),
        ),
      ),
    );
  }

  Widget _slotRow(Spellcasting sc, int level) {
    final pal = context.palette;
    final combat = _c.combat;
    final max = sc.slotsByLevel[level] ?? 0;
    final used = combat.spellSlotsUsed[level] ?? 0;
    final remaining = CombatOps.spellSlotsRemaining(combat, sc, level);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(
              'Nivel $level',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: UsagePips(
              max: max,
              filled: remaining,
              filledIcon: Icons.circle,
              emptyIcon: Icons.circle_outlined,
              size: 16,
            ),
          ),
          Text(
            '$remaining/$max',
            style: TextStyle(color: pal.textMuted, fontSize: 12),
          ),
          SpendRecoverButtons(
            spendTooltip: 'Gastar espacio',
            recoverTooltip: 'Recuperar espacio',
            onSpend: remaining <= 0
                ? null
                : () => _mutateCombat(
                    () => CombatOps.spendSpellSlot(combat, sc, level),
                  ),
            onRecover: used <= 0
                ? null
                : () => _mutateCombat(
                    () => CombatOps.recoverSpellSlot(combat, level),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _spellRow(Spell s) {
    final pal = context.palette;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _showSpellDialog(s),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                s.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (s.concentration) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.blur_on, size: 14, color: pal.gold),
                            ],
                            if (s.ritual) ...[
                              const SizedBox(width: 4),
                              Text(
                                '(R)',
                                style: TextStyle(fontSize: 11, color: muted),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${s.isCantrip ? "Truco" : "Nivel ${s.level}"} · ${s.school}',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.info_outline, size: 14, color: muted),
                ],
              ),
            ),
          ),
          if (s.concentration)
            TextButton(
              onPressed: () => _mutateCombat(
                () => CombatOps.startConcentration(_c.combat, s.name),
              ),
              child: const Text('Concentrar'),
            ),
        ],
      ),
    );
  }

  void _showSpellDialog(Spell s) {
    _infoDialog(
      s.name,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${s.isCantrip ? "Truco" : "Nivel ${s.level}"} · ${s.school}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          _spellMeta('Lanzamiento', s.castingTime),
          _spellMeta('Alcance', s.range),
          _spellMeta('Componentes', s.components),
          _spellMeta('Duración', s.duration),
          const SizedBox(height: 10),
          Text(s.description),
        ],
      ),
    );
  }

  Widget _spellMeta(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  // ----------------------------------------------------------- Inventario

  Widget _buildInventory() {
    final armors = repo.armor.values.where((a) => !a.isShield).toList();
    final weapons = repo.weapons.values.toList();
    return PageBody(
      children: [
        const Eyebrow('Armadura equipada'),
        DropdownButtonFormField<String?>(
          key: ValueKey('armor-${_c.equippedArmorId}'),
          initialValue: _c.equippedArmorId,
          isExpanded: true,
          decoration: const InputDecoration(isDense: true),
          items: [
            const DropdownMenuItem(value: null, child: Text('Sin armadura')),
            ...armors.map(
              (a) => DropdownMenuItem(
                value: a.id,
                child: Text('${a.name} (CA ${a.baseAc})'),
              ),
            ),
          ],
          onChanged: (v) => _replace(_c.copyWith(equippedArmorId: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Escudo (+2 CA)'),
          value: _c.shieldEquipped,
          onChanged: (v) => _replace(_c.copyWith(shieldEquipped: v)),
        ),
        const SizedBox(height: 16),
        const Eyebrow('Arma equipada'),
        DropdownButtonFormField<String?>(
          key: ValueKey(
            'weapon-'
            '${_c.equippedWeaponIds.isEmpty ? null : _c.equippedWeaponIds.first}',
          ),
          initialValue: _c.equippedWeaponIds.isEmpty
              ? null
              : _c.equippedWeaponIds.first,
          isExpanded: true,
          decoration: const InputDecoration(isDense: true),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('Sin arma (puños)'),
            ),
            ...weapons.map(
              (w) => DropdownMenuItem(
                value: w.id,
                child: Text('${w.name} (${w.damageDice})'),
              ),
            ),
          ],
          onChanged: (v) => _replace(_c.copyWith(equippedWeaponIds: [?v])),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            SizedBox(width: 108, child: _acPlaque(sheet.armorClass)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'La Clase de Armadura se recalcula automáticamente según la '
                'armadura, el escudo y tu modificador de Destreza.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- Notas

  Widget _buildNotes() {
    return PageBody(
      children: [
        const Eyebrow('Notas del personaje'),
        TextField(
          controller: _notesCtrl,
          minLines: 12,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            hintText: 'Historia, objetivos, recordatorios de la mesa…',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (v) {
            _c.notes = v;
            ctrl.touch(_c);
          },
        ),
      ],
    );
  }

  Widget _chips(List<String> labels) => labels.isEmpty
      ? const Text('—')
      : Wrap(
          spacing: 6,
          runSpacing: 6,
          children: labels.map((l) => Chip(label: Text(l))).toList(),
        );
}

// ---------------------------------------------------------------- Widgets

/// Visor de retrato a pantalla completa, con zoom/pan y cierre con Escape,
/// clic afuera o el botón de cerrar.
class _PortraitViewer extends StatelessWidget {
  final String path;
  const _PortraitViewer({required this.path});

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.escape): const _DismissViewerIntent(),
      },
      child: Actions(
        actions: {
          _DismissViewerIntent: CallbackAction<_DismissViewerIntent>(
            onInvoke: (_) => Navigator.of(context).pop(),
          ),
        },
        child: Focus(
          autofocus: true,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Stack(
                children: [
                  Center(
                    child: GestureDetector(
                      onTap:
                          () {}, // absorbe el tap para no cerrar sobre la imagen
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: Image.file(File(path), fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DismissViewerIntent extends Intent {
  const _DismissViewerIntent();
}

String _signed(int v) => v >= 0 ? '+$v' : '$v';

String _title(String s) => s.isEmpty
    ? s
    : s
          .split(RegExp(r'[-_ ]'))
          .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
