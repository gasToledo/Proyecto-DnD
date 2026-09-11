import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/api_models.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';
import '../../theme/class_visuals.dart';
import '../conditions.dart';
import '../portrait_image.dart';

const double _wideWidth = 720;

String _signed(int v) => v >= 0 ? '+$v' : '$v';

/// La ficha completa de un personaje vinculado, de solo lectura.
///
/// Es la versión ampliada de la tarjeta de la Mesa (`_MemberCard`, que ya se
/// documenta a sí misma como «la ficha de un jugador, de un vistazo»): acá
/// entra quien quiere el resto de lo que sirve en combate —salvaciones,
/// habilidades, ataques, espacios de conjuro, condiciones—, sin ningún
/// control de edición. No hay ni un botón gris: la ausencia de edición no se
/// explica, se nota, porque nunca se construyó ninguno (el DM no escribe la
/// ficha de otra cuenta, ver `docs/arquitectura/modo-dm.md`).
///
/// Se pide **una sola vez**, al abrir, y no se vuelve a sondear. A diferencia
/// de los PG en combate —que el DM tiene que ver caer en vivo—, gastar un
/// espacio de conjuro no es un evento que nadie presencie en esta pantalla:
/// el jugador dice «lo lanzo» y listo. Un pip que cambia solo, sin que pase
/// nada delante del DM, se lee como un error y no como información. Cerrar y
/// volver a abrir alcanza para una foto nueva.
class MemberSheetScreen extends StatefulWidget {
  final String campaignId;
  final String memberId;
  final String characterName;
  final ContentRepository repo;
  final ApiClient api;

  const MemberSheetScreen({
    super.key,
    required this.campaignId,
    required this.memberId,
    required this.characterName,
    required this.repo,
    required this.api,
  });

  @override
  State<MemberSheetScreen> createState() => _MemberSheetScreenState();
}

class _MemberSheetScreenState extends State<MemberSheetScreen> {
  CampaignMember? _member;
  bool _notFound = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _notFound = false;
    });
    try {
      final members = await widget.api.listCampaignMembers(widget.campaignId);
      final found = members
          .where((m) => m.memberId == widget.memberId)
          .firstOrNull;
      if (!mounted) return;
      setState(() {
        _member = found;
        _notFound = found == null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.characterName)),
    body: _body(),
  );

  Widget _body() {
    if (_error != null) {
      return AppErrorView(
        message: 'No se pudo leer la ficha.',
        details: '$_error',
        onRetry: _load,
      );
    }
    if (_notFound) {
      return const AppEmptyState(
        icon: Icons.person_off_outlined,
        message: 'Ya no ves esta ficha. Puede que te hayan cortado el vínculo.',
      );
    }
    final member = _member;
    if (member == null) {
      return const Center(child: AppBusyLabel('Cargando la ficha…'));
    }
    return _sheet(member);
  }

  Widget _sheet(CampaignMember member) {
    final character = member.character;
    final sheet = CharacterCompiler(widget.repo).compile(character);
    final klass = widget.repo.characterClass(character.classId);
    final race = widget.repo.race(character.raceId);
    final portraitKey = character.portraitPaths.firstOrNull;
    final portraitUrlBase = portraitKey == null
        ? null
        : PortraitImage.urlForMember(
            widget.campaignId,
            member.memberId,
            portraitKey,
          );

    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= _wideWidth;
        final side = _defenses(
          context,
          character: character,
          sheet: sheet,
          klass: klass,
          race: race,
          portraitKey: portraitKey,
          portraitUrlBase: portraitUrlBase,
        );
        final main = _details(context, character: character, sheet: sheet);

        if (!wide) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            children: [side, const SizedBox(height: 18), ...main],
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 236, child: side),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < main.length; i++) ...[
                        if (i > 0) const SizedBox(height: 18),
                        main[i],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// El panel angosto: quién es y cómo aguanta. Mismo radio que el lateral
  /// (9) porque cumple el mismo papel — un panel que acompaña, no una
  /// tarjeta de contenido — y queda fijo a la izquierda en pantalla ancha.
  Widget _defenses(
    BuildContext context, {
    required Character character,
    required ComputedSheet sheet,
    required CharacterClass? klass,
    required Race? race,
    required String? portraitKey,
    required String? portraitUrlBase,
  }) {
    final pal = context.palette;
    final maxHp = sheet.maxHp;
    final currentHp = character.combat.currentHp;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: pal.hairline),
        borderRadius: BorderRadius.circular(9),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              ClassMedallion(
                klass: klass,
                portraitKey: portraitKey,
                portraitUrlBase: portraitUrlBase,
                fallback: character.name.characters.firstOrNull ?? '?',
                size: 56,
              ),
              const SizedBox(height: 10),
              Text(
                character.name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Georgia', fontSize: 17),
              ),
              const SizedBox(height: 3),
              Text(
                [
                  if (race != null) race.name,
                  if (klass != null) klass.name,
                  'Nivel ${character.level}',
                ].join(' · '),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: pal.textMuted),
              ),
              if (character.combat.heroicInspiration) ...[
                const SizedBox(height: 8),
                const GoldPill('Inspiración Heroica'),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icon: Icons.shield,
                  label: 'Armadura',
                  value: '${sheet.armorClass}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  icon: Icons.bolt,
                  label: 'Iniciativa',
                  value: _signed(sheet.initiative),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StatTile(
            label: 'Puntos de golpe',
            labelTrailing: maxHp == 0
                ? null
                : '${(currentHp / maxHp * 100).round()}%',
            value: '$currentHp',
            suffix: ' / $maxHp',
            valueColor: pal.crimson,
            footer: ThinBar(
              ratio: maxHp == 0 ? 0 : currentHp / maxHp,
              color: pal.crimson,
              track: Theme.of(context).colorScheme.surface,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icon: Icons.keyboard_double_arrow_right,
                  label: 'Velocidad',
                  value: '${sheet.speed}',
                  suffix: ' pies',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  icon: Icons.visibility_outlined,
                  label: 'Perc. pasiva',
                  value: '${sheet.passivePerception}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Eyebrow('Salvaciones'),
          DenseRows(
            children: [
              for (final a in Ability.values) _saveRow(context, sheet, a),
            ],
          ),
        ],
      ),
    );
  }

  Widget _saveRow(BuildContext context, ComputedSheet sheet, Ability a) {
    final pal = context.palette;
    final proficient = sheet.savingThrowProficiencies.contains(a);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              a.label,
              style: TextStyle(
                fontSize: 12.5,
                color: proficient ? null : pal.textMuted,
              ),
            ),
          ),
          Text(
            _signed(sheet.savingThrow(a)),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: proficient ? pal.gold : null,
            ),
          ),
        ],
      ),
    );
  }

  /// Las tarjetas de la columna principal: condiciones (si hay), habilidades,
  /// ataques y conjuros (si es lanzador). Devuelve una lista y no un solo
  /// widget porque quien arma la pantalla decide si van una debajo de otra o
  /// apiladas junto al panel angosto.
  List<Widget> _details(
    BuildContext context, {
    required Character character,
    required ComputedSheet sheet,
  }) {
    final activeConditions = character.combat.conditions;
    final proficientSkills = [
      for (final s in Skill.values)
        if (sheet.skillProficiencies.contains(s.id)) s,
    ];

    return [
      if (activeConditions.isNotEmpty)
        _card(
          context,
          icon: Icons.warning_amber_rounded,
          title: 'Condiciones activas',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in activeConditions) _conditionPill(context, id),
            ],
          ),
        ),
      _card(
        context,
        icon: Icons.checklist_rtl,
        title: 'Habilidades competentes',
        child: proficientSkills.isEmpty
            ? Text(
                'Ninguna.',
                style: TextStyle(color: context.palette.textMuted),
              )
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final skill in proficientSkills)
                    _skillChip(context, sheet, skill),
                ],
              ),
      ),
      _card(
        context,
        icon: Icons.gps_fixed,
        title: 'Ataques',
        child: sheet.attacks.isEmpty
            ? Text(
                'No tiene ataques cargados.',
                style: TextStyle(color: context.palette.textMuted),
              )
            : DenseRows(
                children: [
                  for (final a in sheet.attacks) _attackRow(context, a),
                ],
              ),
      ),
      if (sheet.spellcasting case final sc?)
        _spellSlotsCard(context, character.combat, sc),
    ];
  }

  Widget _card(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    final pal = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: pal.hairline),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: pal.gold),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontFamily: 'Georgia', fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _conditionPill(BuildContext context, String id) {
    final pal = context.palette;
    final info = conditions[id];
    final label = info?.label ?? id;
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: pal.crimson.withAlpha(30),
        border: Border.all(color: pal.crimson),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: pal.crimson, fontSize: 12.5)),
    );
    return info == null
        ? pill
        : Tooltip(message: info.description, child: pill);
  }

  Widget _skillChip(BuildContext context, ComputedSheet sheet, Skill skill) {
    final pal = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: pal.plaque,
        border: Border.all(color: pal.hairline),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text.rich(
        TextSpan(
          text: '${skill.label} ',
          style: const TextStyle(fontSize: 12.5),
          children: [
            TextSpan(
              text: _signed(sheet.skillModifier(skill.id)),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: pal.gold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _attackRow(BuildContext context, Attack a) {
    final pal = context.palette;
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
                Text(
                  '${a.damage} ${DamageType.labelFor(a.damageType)}',
                  style: TextStyle(color: pal.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          Text(
            _signed(a.attackBonus),
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 20,
              color: pal.gold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _spellSlotsCard(
    BuildContext context,
    CombatState combat,
    Spellcasting sc,
  ) {
    final levels = sc.slotsByLevel.keys.toList()..sort();
    return _card(
      context,
      icon: Icons.auto_awesome,
      title: 'Espacios de conjuro',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final level in levels) _slotRow(context, combat, sc, level),
        ],
      ),
    );
  }

  Widget _slotRow(
    BuildContext context,
    CombatState combat,
    Spellcasting sc,
    int level,
  ) {
    final pal = context.palette;
    final max = sc.slotsByLevel[level] ?? 0;
    final remaining = CombatOps.spellSlotsRemaining(combat, sc, level);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 64, child: Text('Nivel $level')),
          Expanded(
            child: UsagePips(
              max: max,
              filled: remaining,
              filledIcon: Icons.circle,
              emptyIcon: Icons.circle_outlined,
              size: 15,
            ),
          ),
          Text(
            '$remaining/$max',
            style: TextStyle(color: pal.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
