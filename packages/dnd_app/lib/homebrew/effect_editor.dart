part of 'homebrew_screen.dart';

/// Editor de una lista de [Effect]. Permite agregar tipos comunes y quitarlos.
///
/// ponytail: no edita un efecto ya agregado —se quita y se vuelve a poner— ni
/// ofrece los efectos de **elección** (`ProficiencyChoiceEffect` y familia), que
/// piden un subformulario con su propia lista de opciones, ni la maquinaria de
/// clase (`SpellcastingEffect`, `ResourceEffect`, `CompanionEffect`), que no
/// aparece en una dote ni en una especie. Todo eso se sigue cargando por JSON e
/// importando el pack, y el editor lo conserva tal cual: lo que no sabe
/// describir lo muestra por su tipo, pero nunca lo borra.
class EffectEditor extends StatefulWidget {
  final List<Effect> effects;

  /// Para nombrar y ofrecer el contenido que un efecto puede conceder.
  final ContentRepository repo;
  final VoidCallback onChanged;
  const EffectEditor({
    super.key,
    required this.effects,
    required this.repo,
    required this.onChanged,
  });

  @override
  State<EffectEditor> createState() => _EffectEditorState();
}

class _EffectEditorState extends State<EffectEditor> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.effects.isEmpty)
          Text(
            'Sin efectos.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        else
          DenseRows(
            children: [
              for (final entry in widget.effects.asMap().entries)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        // Al jugador lo que no se puede describir no se le
                        // muestra; acá mira quien arma el contenido, y
                        // ocultarlo escondería un efecto que igual se guarda.
                        child: Text(
                          describeEffect(entry.value, widget.repo) ??
                              entry.value.toJson()['type'].toString(),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Quitar efecto',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          setState(() => widget.effects.removeAt(entry.key));
                          widget.onChanged();
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: const Text('Agregar efecto'),
        ),
      ],
    );
  }

  Future<void> _add() async {
    final effect = await showDialog<Effect>(
      context: context,
      builder: (_) => _AddEffectDialog(repo: widget.repo),
    );
    if (effect != null) {
      setState(() => widget.effects.add(effect));
      widget.onChanged();
    }
  }
}

/// Los tipos que el diálogo sabe construir, en el orden en que se ofrecen:
/// primero lo que toca los números de la ficha, después lo que concede
/// competencias, después la magia y por último lo narrativo.
enum _EffectKind {
  abilityBonus('Bonus a característica'),
  setAbilityScore('Fijar una característica'),
  hpPerLevel('PG máx por nivel'),
  hpFlat('PG máx, una vez'),
  acBonus('Bonus a CA'),
  speedBonus('Bonus de velocidad'),
  setSpeed('Fijar la velocidad'),
  darkvision('Visión en la oscuridad'),
  skillProf('Competencia en habilidad'),
  saveProf('Competencia en salvación'),
  saveBonus('Bonus a las salvaciones'),
  weaponProf('Competencia con armas'),
  armorProf('Competencia con armadura'),
  toolProf('Competencia con herramienta'),
  language('Idioma'),
  resistance('Resistencia a daño'),
  immunity('Inmunidad a daño'),
  grantSpell('Conceder un conjuro'),
  alwaysPrepared('Conjuro siempre preparado'),
  spellListAddition('Sumar un conjuro a tu lista'),
  grantFeat('Conceder una dote'),
  extraAttack('Ataque adicional'),
  masterySlots('Maestrías de arma'),
  passive('Rasgo pasivo');

  final String label;
  const _EffectKind(this.label);
}

class _AddEffectDialog extends StatefulWidget {
  final ContentRepository repo;
  const _AddEffectDialog({required this.repo});
  @override
  State<_AddEffectDialog> createState() => _AddEffectDialogState();
}

class _AddEffectDialogState extends State<_AddEffectDialog> {
  _EffectKind _kind = _EffectKind.abilityBonus;
  Ability _ability = Ability.strength;
  late String _skill = _skillOptions.keys.first;
  late String _damageType = DamageType.values.first.id;
  late String _weaponCategory = weaponProficiencyIds.first;
  late String _armorCategory = armorTrainingIds.first;
  late String _tool = toolProficiencyIds.first;
  late String _language = Language.values.first.id;

  /// Arrancan en la primera entrada del catálogo y no en null para que el botón
  /// Agregar nunca quede sin efecto que construir: el conjuro y la dote son
  /// listas largas, pero siempre hay uno elegido.
  late String _spellId = widget.repo.spellsSorted.first.id;
  late String? _featId = widget.repo.featsSorted.firstOrNull?.id;
  InnateSpellUse _spellUse = InnateSpellUse.atWill;

  final _amountCtrl = TextEditingController(text: '1');
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  int get _amount => int.tryParse(_amountCtrl.text.trim()) ?? 0;

  Effect? _build() => switch (_kind) {
    _EffectKind.abilityBonus => AbilityScoreBonusEffect(
      ability: _ability,
      amount: _amount,
    ),
    _EffectKind.setAbilityScore => SetAbilityScoreEffect(
      ability: _ability,
      score: _amount,
    ),
    _EffectKind.hpPerLevel => BonusMaxHpPerLevelEffect(_amount),
    _EffectKind.hpFlat => BonusMaxHpFlatEffect(_amount),
    _EffectKind.acBonus => ArmorClassBonusEffect(_amount),
    _EffectKind.speedBonus => SpeedBonusEffect(_amount),
    _EffectKind.setSpeed => SetSpeedEffect(_amount),
    _EffectKind.darkvision => DarkvisionEffect(_amount),
    _EffectKind.skillProf => SkillProficiencyEffect(_skill),
    _EffectKind.saveProf => SavingThrowProficiencyEffect(_ability),
    _EffectKind.saveBonus => SavingThrowBonusEffect(_amount),
    _EffectKind.weaponProf => WeaponProficiencyEffect(_weaponCategory),
    _EffectKind.armorProf => ArmorProficiencyEffect(_armorCategory),
    _EffectKind.toolProf => ToolProficiencyEffect(_tool),
    _EffectKind.language => LanguageEffect(_language),
    _EffectKind.resistance => ResistanceEffect(_damageType),
    _EffectKind.immunity => ImmunityEffect(_damageType),
    _EffectKind.grantSpell => GrantSpellEffect(
      spellId: _spellId,
      ability: _ability,
      use: _spellUse,
    ),
    _EffectKind.alwaysPrepared => AlwaysPreparedSpellEffect(spellId: _spellId),
    _EffectKind.spellListAddition => SpellListAdditionEffect(spellId: _spellId),
    // Sin dote elegida es "una dote a elección del jugador", que es un efecto
    // legítimo y no un formulario a medio llenar (la dote de origen 2024).
    _EffectKind.grantFeat => GrantFeatEffect(featId: _featId),
    _EffectKind.extraAttack => ExtraAttackEffect(_amount),
    _EffectKind.masterySlots => WeaponMasterySlotsEffect(_amount),
    _EffectKind.passive =>
      _nameCtrl.text.trim().isEmpty
          ? null
          : PassiveTraitEffect(
              name: _nameCtrl.text.trim(),
              description: _descCtrl.text.trim(),
            ),
  };

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Agregar efecto',
      width: 460,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _idDropdown(
            label: 'Tipo',
            value: _kind.name,
            options: {for (final k in _EffectKind.values) k.name: k.label},
            onChanged: (v) =>
                setState(() => _kind = _EffectKind.values.byName(v)),
          ),
          ..._fields(),
        ],
      ),
      actions: [
        DialogAction(
          'Cancelar',
          keyHint: 'Esc',
          onPressed: () => Navigator.of(context).pop(),
        ),
        DialogAction(
          'Agregar',
          primary: true,
          onPressed: () {
            final e = _build();
            // Antes el botón no hacía nada y el diálogo se quedaba abierto sin
            // decir por qué: un control que no responde se lee como roto.
            if (e == null) {
              showAppMessage(
                context,
                'Escribí el nombre del rasgo.',
                tone: AppMessageTone.error,
              );
              return;
            }
            Navigator.of(context).pop(e);
          },
        ),
      ],
    );
  }

  List<Widget> _fields() => switch (_kind) {
    _EffectKind.abilityBonus ||
    _EffectKind.setAbilityScore => [_abilityDropdown(), _amountField()],
    _EffectKind.hpPerLevel ||
    _EffectKind.hpFlat ||
    _EffectKind.acBonus ||
    _EffectKind.speedBonus ||
    _EffectKind.setSpeed ||
    _EffectKind.darkvision ||
    _EffectKind.saveBonus ||
    _EffectKind.extraAttack ||
    _EffectKind.masterySlots => [_amountField()],
    _EffectKind.saveProf => [_abilityDropdown()],
    _EffectKind.skillProf => [
      _idDropdown(
        label: 'Habilidad',
        value: _skill,
        options: _skillOptions,
        onChanged: (v) => setState(() => _skill = v),
      ),
    ],
    _EffectKind.weaponProf => [
      _idDropdown(
        label: 'Armas',
        value: _weaponCategory,
        options: {
          for (final id in weaponProficiencyIds) id: weaponProficiencyLabel(id),
          // Un rasgo también puede conceder **un arma concreta** (el Bardo con
          // el estoque), y ahí el id es el del arma, no una categoría.
          for (final w in widget.repo.weaponsSorted) w.id: w.name,
        },
        onChanged: (v) => setState(() => _weaponCategory = v),
      ),
    ],
    _EffectKind.armorProf => [
      _idDropdown(
        label: 'Armadura',
        value: _armorCategory,
        options: {
          for (final id in armorTrainingIds) id: armorTrainingLabel(id),
        },
        onChanged: (v) => setState(() => _armorCategory = v),
      ),
    ],
    _EffectKind.toolProf => [
      _idDropdown(
        label: 'Herramienta',
        value: _tool,
        options: {
          for (final id in toolProficiencyIds) id: toolProficiencyLabel(id),
        },
        onChanged: (v) => setState(() => _tool = v),
      ),
    ],
    _EffectKind.language => [
      _idDropdown(
        label: 'Idioma',
        value: _language,
        options: {for (final l in Language.values) l.id: l.label},
        onChanged: (v) => setState(() => _language = v),
      ),
    ],
    _EffectKind.resistance || _EffectKind.immunity => [
      // Desplegable y no texto libre: escrito a mano, "fuego" no coincide con
      // el id `fire` y el efecto quedaba guardado sin hacer nada.
      _damageTypeDropdown(_damageType, (v) => setState(() => _damageType = v)),
    ],
    _EffectKind.grantSpell => [
      _spellDropdown(),
      _idDropdown(
        label: 'Cómo se usa',
        value: _spellUse.name,
        options: {
          for (final entry in innateSpellUseLabels.entries)
            entry.key.name: entry.value,
        },
        onChanged: (v) =>
            setState(() => _spellUse = InnateSpellUse.values.byName(v)),
      ),
      _abilityDropdown(label: 'Característica para lanzarlo'),
    ],
    _EffectKind.alwaysPrepared ||
    _EffectKind.spellListAddition => [_spellDropdown()],
    _EffectKind.grantFeat => [
      _idDropdown(
        label: 'Dote',
        value: _featId ?? _anyFeat,
        options: {
          _anyFeat: 'A elección del jugador',
          for (final f in widget.repo.featsSorted) f.id: f.name,
        },
        onChanged: (v) => setState(() => _featId = v == _anyFeat ? null : v),
      ),
    ],
    _EffectKind.passive => [
      _text(_nameCtrl, 'Nombre del rasgo'),
      _text(_descCtrl, 'Descripción', maxLines: 2),
    ],
  };

  Widget _spellDropdown() => _idDropdown(
    label: 'Conjuro',
    value: _spellId,
    options: {
      for (final s in widget.repo.spellsSorted)
        s.id: s.isCantrip
            ? '${s.name} (truco)'
            : '${s.name} (nivel ${s.level})',
    },
    onChanged: (v) => setState(() => _spellId = v),
  );

  Widget _abilityDropdown({String label = 'Característica'}) => _idDropdown(
    label: label,
    value: _ability.name,
    // El nombre completo y no la abreviatura: acá se está eligiendo, y "STR"
    // obliga a saber inglés para tomar la decisión. El resumen del efecto ya
    // creado sí usa la abreviatura, que ahí es un rótulo compacto.
    options: {for (final a in Ability.values) a.name: a.label},
    onChanged: (v) => setState(() => _ability = Ability.values.byName(v)),
  );

  Widget _amountField() => _text(_amountCtrl, 'Valor', number: true);
}

/// Valor del desplegable de dote que significa "la elige el jugador". Va como
/// texto y no como null por lo mismo que [_mundane]: el desplegable no acepta
/// una opción nula.
const _anyFeat = 'any';
