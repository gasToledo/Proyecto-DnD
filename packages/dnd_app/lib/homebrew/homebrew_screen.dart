import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../data/homebrew_store.dart';
import '../data/transfer_service.dart';
import '../theme/app_widgets.dart';
import '../ui/import_dialog.dart';
import 'effect_editor.dart';

const _skills = [
  'acrobatics', 'animal-handling', 'arcana', 'athletics', 'deception',
  'history', 'insight', 'intimidation', 'investigation', 'medicine',
  'nature', 'perception', 'performance', 'persuasion', 'religion',
  'sleight-of-hand', 'stealth', 'survival',
];
const _weaponProps = [
  'finesse', 'versatile', 'two-handed', 'light', 'heavy', 'thrown',
  'ranged', 'ammunition', 'reach', 'loading',
];

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
  ContentRepository get repo => widget.repo;
  HomebrewStore get store => widget.store;

  /// Ejecuta una escritura en disco del store homebrew; si falla (permisos,
  /// disco lleno) lo muestra en vez de dejar la excepción sin capturar.
  Future<void> _persist(Future<void> Function() write) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await write();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    }
  }

  Future<void> _exportHomebrew() async {
    final content = store.exportContent();
    final total = content.values.fold<int>(0, (s, l) => s + l.length);
    if (total == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay contenido homebrew para exportar.')));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await TransferService().exportHomebrew(content);
      messenger.showSnackBar(SnackBar(
          content: Text('Homebrew exportado ($total) en:\n$path'),
          duration: const Duration(seconds: 4)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error al exportar: $e')));
    }
  }

  Future<void> _importHomebrew() async {
    final transfer = TransferService();
    final path = await showDialog<String>(
      context: context,
      builder: (_) => ImportDialog(transfer: transfer),
    );
    if (path == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final content = await transfer.importHomebrewFromFile(path);
      if (!mounted) return;
      // No pisar homebrew existente sin avisar: si hay ids en colisión, pedir
      // confirmación antes de sobrescribir.
      final collisions = store.countCollisions(content);
      if (collisions > 0) {
        final overwrite = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Sobrescribir homebrew'),
            content: Text('$collisions entrada(s) del pack comparten id con '
                'contenido que ya tenés. Al importar se reemplazarán. '
                '¿Continuar?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Sobrescribir')),
            ],
          ),
        );
        if (overwrite != true || !mounted) return;
      }
      final count = await store.importContent(content);
      // Fusiona lo importado en el repo compartido, así queda disponible de
      // inmediato en el wizard y las fichas (igual que al guardar un ítem).
      repo.addAll(store.toRepository());
      if (!mounted) return;
      setState(() {});
      messenger.showSnackBar(
          SnackBar(content: Text('Importadas $count entradas de homebrew.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error al importar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Contenido homebrew'),
          actions: [
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: 'Exportar homebrew',
              onPressed: _exportHomebrew,
            ),
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Importar homebrew',
              onPressed: _importHomebrew,
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Armas'),
              Tab(text: 'Armaduras'),
              Tab(text: 'Dotes'),
              Tab(text: 'Razas'),
              Tab(text: 'Trasfondos'),
              Tab(text: 'Conjuros'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _weaponsTab(),
            _armorTab(),
            _featsTab(),
            _racesTab(),
            _backgroundsTab(),
            _spellsTab(),
          ],
        ),
      ),
    );
  }

  Widget _list({
    required String addLabel,
    required VoidCallback onAdd,
    required List<Widget> items,
  }) {
    return PageBody(
      children: [
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: Text(addLabel),
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text('Todavía no agregaste nada aquí.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          )
        else
          DenseRows(children: items),
      ],
    );
  }

  Widget _tile(String title, String subtitle,
      {required VoidCallback onEdit, required VoidCallback onDelete}) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: muted)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------- Armas
  Widget _weaponsTab() => _list(
        addLabel: 'Agregar arma',
        onAdd: () => _editWeapon(),
        items: store.weapons.values
            .map((w) => _tile(w.name, '${w.category} · ${w.damageDice} ${w.damageType}',
                onEdit: () => _editWeapon(w),
                onDelete: () => _delete(() => store.deleteWeapon(w.id),
                    () => repo.weapons.remove(w.id))))
            .toList(),
      );

  Future<void> _editWeapon([Weapon? initial]) async {
    final w = await Navigator.of(context).push<Weapon>(
        MaterialPageRoute(builder: (_) => WeaponForm(initial: initial)));
    if (w == null) return;
    await _persist(() => store.saveWeapon(w));
    repo.weapons[w.id] = w;
    setState(() {});
  }

  // ---------------------------------------------------------- Armaduras
  Widget _armorTab() => _list(
        addLabel: 'Agregar armadura',
        onAdd: () => _editArmor(),
        items: store.armor.values
            .map((a) => _tile(a.name, '${a.category} · CA ${a.baseAc}',
                onEdit: () => _editArmor(a),
                onDelete: () => _delete(() => store.deleteArmor(a.id),
                    () => repo.armor.remove(a.id))))
            .toList(),
      );

  Future<void> _editArmor([Armor? initial]) async {
    final a = await Navigator.of(context).push<Armor>(
        MaterialPageRoute(builder: (_) => ArmorForm(initial: initial)));
    if (a == null) return;
    await _persist(() => store.saveArmor(a));
    repo.armor[a.id] = a;
    setState(() {});
  }

  // --------------------------------------------------------------- Dotes
  Widget _featsTab() => _list(
        addLabel: 'Agregar dote',
        onAdd: () => _editFeat(),
        items: store.feats.values
            .map((f) => _tile(f.name, '${f.category} · ${f.effects.length} efecto(s)',
                onEdit: () => _editFeat(f),
                onDelete: () => _delete(() => store.deleteFeat(f.id),
                    () => repo.feats.remove(f.id))))
            .toList(),
      );

  Future<void> _editFeat([Feat? initial]) async {
    final f = await Navigator.of(context)
        .push<Feat>(MaterialPageRoute(builder: (_) => FeatForm(initial: initial)));
    if (f == null) return;
    await _persist(() => store.saveFeat(f));
    repo.feats[f.id] = f;
    setState(() {});
  }

  // --------------------------------------------------------------- Razas
  Widget _racesTab() => _list(
        addLabel: 'Agregar raza',
        onAdd: () => _editRace(),
        items: store.races.values
            .map((r) => _tile(r.name, '${r.size} · ${r.speed} ft · ${r.effects.length} rasgo(s)',
                onEdit: () => _editRace(r),
                onDelete: () => _delete(() => store.deleteRace(r.id),
                    () => repo.races.remove(r.id))))
            .toList(),
      );

  Future<void> _editRace([Race? initial]) async {
    final r = await Navigator.of(context)
        .push<Race>(MaterialPageRoute(builder: (_) => RaceForm(initial: initial)));
    if (r == null) return;
    await _persist(() => store.saveRace(r));
    repo.races[r.id] = r;
    setState(() {});
  }

  // ---------------------------------------------------------- Trasfondos
  Widget _backgroundsTab() => _list(
        addLabel: 'Agregar trasfondo',
        onAdd: () => _editBackground(),
        items: store.backgrounds.values
            .map((b) => _tile(b.name, b.skillProficiencies.join(', '),
                onEdit: () => _editBackground(b),
                onDelete: () => _delete(() => store.deleteBackground(b.id),
                    () => repo.backgrounds.remove(b.id))))
            .toList(),
      );

  Future<void> _editBackground([Background? initial]) async {
    final b = await Navigator.of(context).push<Background>(MaterialPageRoute(
        builder: (_) => BackgroundForm(initial: initial, repo: repo)));
    if (b == null) return;
    await _persist(() => store.saveBackground(b));
    repo.backgrounds[b.id] = b;
    setState(() {});
  }

  // ---------------------------------------------------------- Conjuros
  Widget _spellsTab() => _list(
        addLabel: 'Agregar conjuro',
        onAdd: () => _editSpell(),
        items: (store.spells.values.toList()
              ..sort((a, b) => a.level != b.level
                  ? a.level.compareTo(b.level)
                  : a.name.compareTo(b.name)))
            .map((s) => _tile(
                s.name,
                '${s.isCantrip ? "Truco" : "Nivel ${s.level}"}'
                    '${s.school.isEmpty ? "" : " · ${s.school}"}'
                    '${s.classes.isEmpty ? "" : " · ${s.classes.join(", ")}"}',
                onEdit: () => _editSpell(s),
                onDelete: () => _delete(() => store.deleteSpell(s.id),
                    () => repo.spells.remove(s.id))))
            .toList(),
      );

  Future<void> _editSpell([Spell? initial]) async {
    final s = await Navigator.of(context)
        .push<Spell>(MaterialPageRoute(builder: (_) => SpellForm(initial: initial)));
    if (s == null) return;
    await _persist(() => store.saveSpell(s));
    repo.spells[s.id] = s;
    setState(() {});
  }

  Future<void> _delete(
      Future<void> Function() fromStore, VoidCallback fromRepo) async {
    await _persist(fromStore);
    fromRepo();
    setState(() {});
  }
}

// ============================================================ Formularios

class WeaponForm extends StatefulWidget {
  final Weapon? initial;
  const WeaponForm({super.key, this.initial});
  @override
  State<WeaponForm> createState() => _WeaponFormState();
}

class _WeaponFormState extends State<WeaponForm> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _dice = TextEditingController(text: widget.initial?.damageDice ?? '1d6');
  late final _type =
      TextEditingController(text: widget.initial?.damageType ?? 'slashing');
  late final _versatile =
      TextEditingController(text: widget.initial?.versatileDice ?? '');
  late final _mastery =
      TextEditingController(text: widget.initial?.mastery ?? '');
  late String _category = widget.initial?.category ?? 'simple';
  late final Set<String> _props = {...?widget.initial?.properties};

  @override
  Widget build(BuildContext context) {
    return _FormScaffold(
      title: 'Arma',
      onSave: _name.text.trim().isEmpty ? null : _save,
      children: [
        _text(_name, 'Nombre', onChanged: () => setState(() {})),
        _categoryDropdown(['simple', 'martial'], _category,
            (v) => setState(() => _category = v)),
        _text(_dice, 'Dado de daño (p.ej. 1d8)'),
        _text(_type, 'Tipo de daño (slashing/piercing/bludgeoning)'),
        _text(_versatile, 'Dado versátil (opcional, p.ej. 1d10)'),
        _text(_mastery, 'Maestría (opcional, p.ej. sap)'),
        const SizedBox(height: 8),
        const Eyebrow('Propiedades'),
        Wrap(
          spacing: 6,
          children: _weaponProps
              .map((p) => FilterChip(
                    label: Text(p),
                    selected: _props.contains(p),
                    onSelected: (v) => setState(
                        () => v ? _props.add(p) : _props.remove(p)),
                  ))
              .toList(),
        ),
      ],
    );
  }

  void _save() {
    Navigator.of(context).pop(Weapon(
      id: widget.initial?.id ?? homebrewId(_name.text),
      name: _name.text.trim(),
      source: ContentSource.homebrew,
      category: _category,
      damageDice: _dice.text.trim(),
      damageType: _type.text.trim(),
      properties: _props.toList(),
      versatileDice: _versatile.text.trim().isEmpty ? null : _versatile.text.trim(),
      mastery: _mastery.text.trim().isEmpty ? null : _mastery.text.trim(),
    ));
  }
}

class ArmorForm extends StatefulWidget {
  final Armor? initial;
  const ArmorForm({super.key, this.initial});
  @override
  State<ArmorForm> createState() => _ArmorFormState();
}

class _ArmorFormState extends State<ArmorForm> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _baseAc =
      TextEditingController(text: '${widget.initial?.baseAc ?? 11}');
  late final _maxDex = TextEditingController(
      text: widget.initial?.maxDexBonus?.toString() ?? '');
  late final _strReq = TextEditingController(
      text: widget.initial?.strengthRequirement?.toString() ?? '');
  late String _category = widget.initial?.category ?? 'light';
  late bool _addDex = widget.initial?.addDexMod ?? true;
  late bool _stealth = widget.initial?.stealthDisadvantage ?? false;

  @override
  Widget build(BuildContext context) {
    return _FormScaffold(
      title: 'Armadura',
      onSave: _name.text.trim().isEmpty ? null : _save,
      children: [
        _text(_name, 'Nombre', onChanged: () => setState(() {})),
        _categoryDropdown(['light', 'medium', 'heavy', 'shield'], _category,
            (v) => setState(() => _category = v)),
        _text(_baseAc, 'CA base', number: true),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Suma modificador de DEX'),
          value: _addDex,
          onChanged: (v) => setState(() => _addDex = v),
        ),
        _text(_maxDex, 'Tope de DEX (opcional, p.ej. 2)', number: true),
        _text(_strReq, 'Requisito de Fuerza (opcional)', number: true),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Desventaja en Sigilo'),
          value: _stealth,
          onChanged: (v) => setState(() => _stealth = v),
        ),
      ],
    );
  }

  void _save() {
    Navigator.of(context).pop(Armor(
      id: widget.initial?.id ?? homebrewId(_name.text),
      name: _name.text.trim(),
      source: ContentSource.homebrew,
      category: _category,
      baseAc: int.tryParse(_baseAc.text.trim()) ?? 10,
      addDexMod: _addDex,
      maxDexBonus: int.tryParse(_maxDex.text.trim()),
      strengthRequirement: int.tryParse(_strReq.text.trim()),
      stealthDisadvantage: _stealth,
    ));
  }
}

class FeatForm extends StatefulWidget {
  final Feat? initial;
  const FeatForm({super.key, this.initial});
  @override
  State<FeatForm> createState() => _FeatFormState();
}

class _FeatFormState extends State<FeatForm> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late String _category = widget.initial?.category ?? 'general';
  late final List<Effect> _effects = [...?widget.initial?.effects];

  @override
  Widget build(BuildContext context) {
    return _FormScaffold(
      title: 'Dote',
      onSave: _name.text.trim().isEmpty ? null : _save,
      children: [
        _text(_name, 'Nombre', onChanged: () => setState(() {})),
        _categoryDropdown(['origin', 'general', 'fighting-style'], _category,
            (v) => setState(() => _category = v)),
        const SizedBox(height: 12),
        const Eyebrow('Efectos'),
        EffectEditor(effects: _effects, onChanged: () => setState(() {})),
      ],
    );
  }

  void _save() {
    Navigator.of(context).pop(Feat(
      id: widget.initial?.id ?? homebrewId(_name.text),
      name: _name.text.trim(),
      source: ContentSource.homebrew,
      category: _category,
      effects: _effects,
    ));
  }
}

class RaceForm extends StatefulWidget {
  final Race? initial;
  const RaceForm({super.key, this.initial});
  @override
  State<RaceForm> createState() => _RaceFormState();
}

class _RaceFormState extends State<RaceForm> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _size =
      TextEditingController(text: widget.initial?.size ?? 'Mediano');
  late final _speed = TextEditingController(text: '${widget.initial?.speed ?? 30}');
  late final _skillCount =
      TextEditingController(text: '${widget.initial?.skillChoiceCount ?? 0}');
  late final List<Effect> _effects = [...?widget.initial?.effects];

  @override
  Widget build(BuildContext context) {
    return _FormScaffold(
      title: 'Raza / Especie',
      onSave: _name.text.trim().isEmpty ? null : _save,
      children: [
        _text(_name, 'Nombre', onChanged: () => setState(() {})),
        _text(_size, 'Tamaño (Pequeño/Mediano/Grande)'),
        _text(_speed, 'Velocidad (ft)', number: true),
        _text(_skillCount, 'Habilidades a elegir', number: true),
        const SizedBox(height: 12),
        const Eyebrow('Rasgos (efectos)'),
        EffectEditor(effects: _effects, onChanged: () => setState(() {})),
      ],
    );
  }

  void _save() {
    Navigator.of(context).pop(Race(
      id: widget.initial?.id ?? homebrewId(_name.text),
      name: _name.text.trim(),
      source: ContentSource.homebrew,
      size: _size.text.trim(),
      speed: int.tryParse(_speed.text.trim()) ?? 30,
      skillChoiceCount: int.tryParse(_skillCount.text.trim()) ?? 0,
      effects: _effects,
    ));
  }
}

class BackgroundForm extends StatefulWidget {
  final Background? initial;
  final ContentRepository repo;
  const BackgroundForm({super.key, this.initial, required this.repo});
  @override
  State<BackgroundForm> createState() => _BackgroundFormState();
}

class _BackgroundFormState extends State<BackgroundForm> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _tools = TextEditingController(
      text: widget.initial?.toolProficiencies.join(', ') ?? '');
  late final Set<Ability> _abilities = {...?widget.initial?.abilityOptions};
  late final Set<String> _skills2 = {...?widget.initial?.skillProficiencies};
  late String? _originFeatId = widget.initial?.originFeatId;
  late final List<Effect> _effects = [...?widget.initial?.effects];

  @override
  Widget build(BuildContext context) {
    final feats = widget.repo.feats.values.toList();
    return _FormScaffold(
      title: 'Trasfondo',
      onSave: _name.text.trim().isEmpty ? null : _save,
      children: [
        _text(_name, 'Nombre', onChanged: () => setState(() {})),
        const SizedBox(height: 8),
        const Eyebrow('Características (elegí 3)'),
        Wrap(
          spacing: 6,
          children: Ability.values
              .map((a) => FilterChip(
                    label: Text(a.abbr),
                    selected: _abilities.contains(a),
                    onSelected: (v) => setState(() {
                      if (v && _abilities.length < 3) {
                        _abilities.add(a);
                      } else {
                        _abilities.remove(a);
                      }
                    }),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        const Eyebrow('Competencias de habilidad'),
        Wrap(
          spacing: 6,
          children: _skills
              .map((s) => FilterChip(
                    label: Text(s),
                    selected: _skills2.contains(s),
                    onSelected: (v) => setState(
                        () => v ? _skills2.add(s) : _skills2.remove(s)),
                  ))
              .toList(),
        ),
        _text(_tools, 'Herramientas (separadas por coma)'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          initialValue: _originFeatId,
          decoration: const InputDecoration(
              labelText: 'Dote de origen', border: OutlineInputBorder()),
          items: [
            const DropdownMenuItem(value: null, child: Text('(ninguna)')),
            ...feats.map((f) =>
                DropdownMenuItem(value: f.id, child: Text(f.name))),
          ],
          onChanged: (v) => setState(() => _originFeatId = v),
        ),
        const SizedBox(height: 12),
        const Eyebrow('Efectos adicionales'),
        EffectEditor(effects: _effects, onChanged: () => setState(() {})),
      ],
    );
  }

  void _save() {
    final tools = _tools.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    Navigator.of(context).pop(Background(
      id: widget.initial?.id ?? homebrewId(_name.text),
      name: _name.text.trim(),
      source: ContentSource.homebrew,
      abilityOptions: _abilities.toList(),
      skillProficiencies: _skills2.toList(),
      toolProficiencies: tools,
      originFeatId: _originFeatId,
      effects: _effects,
    ));
  }
}

class SpellForm extends StatefulWidget {
  final Spell? initial;
  const SpellForm({super.key, this.initial});
  @override
  State<SpellForm> createState() => _SpellFormState();
}

/// Clases lanzadoras a las que se puede asignar un conjuro (id → etiqueta).
const _spellClasses = {
  'wizard': 'Mago',
  'sorcerer': 'Hechicero',
  'cleric': 'Clérigo',
  'druid': 'Druida',
  'bard': 'Bardo',
  'warlock': 'Brujo',
  'paladin': 'Paladín',
  'ranger': 'Explorador',
};

class _SpellFormState extends State<SpellForm> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _level = TextEditingController(text: '${widget.initial?.level ?? 0}');
  late final _school =
      TextEditingController(text: widget.initial?.school ?? '');
  late final _castingTime =
      TextEditingController(text: widget.initial?.castingTime ?? '1 acción');
  late final _range = TextEditingController(text: widget.initial?.range ?? '');
  late final _components =
      TextEditingController(text: widget.initial?.components ?? 'V, S');
  late final _duration =
      TextEditingController(text: widget.initial?.duration ?? 'Instantánea');
  late final _description =
      TextEditingController(text: widget.initial?.description ?? '');
  late bool _concentration = widget.initial?.concentration ?? false;
  late bool _ritual = widget.initial?.ritual ?? false;
  late final Set<String> _classes = {...?widget.initial?.classes};

  @override
  Widget build(BuildContext context) {
    return _FormScaffold(
      title: 'Conjuro',
      onSave: _name.text.trim().isEmpty ? null : _save,
      children: [
        _text(_name, 'Nombre', onChanged: () => setState(() {})),
        _text(_level, 'Nivel (0 = truco)', number: true),
        _text(_school, 'Escuela (p.ej. Evocación)'),
        _text(_castingTime, 'Tiempo de lanzamiento'),
        _text(_range, 'Alcance'),
        _text(_components, 'Componentes (p.ej. V, S, M)'),
        _text(_duration, 'Duración'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Concentración'),
          value: _concentration,
          onChanged: (v) => setState(() => _concentration = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Ritual'),
          value: _ritual,
          onChanged: (v) => setState(() => _ritual = v),
        ),
        const SizedBox(height: 8),
        const Eyebrow('Listas de clase'),
        Wrap(
          spacing: 6,
          children: _spellClasses.entries
              .map((e) => FilterChip(
                    label: Text(e.value),
                    selected: _classes.contains(e.key),
                    onSelected: (v) => setState(
                        () => v ? _classes.add(e.key) : _classes.remove(e.key)),
                  ))
              .toList(),
        ),
        const SizedBox(height: 12),
        const Eyebrow('Descripción'),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: TextField(
            controller: _description,
            minLines: 3,
            maxLines: null,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
      ],
    );
  }

  void _save() {
    Navigator.of(context).pop(Spell(
      id: widget.initial?.id ?? homebrewId(_name.text),
      name: _name.text.trim(),
      source: ContentSource.homebrew,
      level: int.tryParse(_level.text.trim())?.clamp(0, 9) ?? 0,
      school: _school.text.trim(),
      castingTime: _castingTime.text.trim(),
      range: _range.text.trim(),
      components: _components.text.trim(),
      duration: _duration.text.trim(),
      concentration: _concentration,
      ritual: _ritual,
      description: _description.text.trim(),
      classes: _classes.toList(),
    ));
  }
}

// ---------------------------------------------------------- Helpers de form

class _FormScaffold extends StatelessWidget {
  final String title;
  final VoidCallback? onSave;
  final List<Widget> children;
  const _FormScaffold(
      {required this.title, required this.onSave, required this.children});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PageBody(children: children),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.save),
            label: const Text('Guardar'),
          ),
        ),
      ),
    );
  }
}

Widget _text(TextEditingController c, String label,
        {bool number = false, VoidCallback? onChanged}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: c,
        keyboardType: number ? TextInputType.number : null,
        onChanged: onChanged == null ? null : (_) => onChanged(),
        decoration:
            InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );

Widget _categoryDropdown(
        List<String> options, String value, ValueChanged<String> onChanged) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: const InputDecoration(
            labelText: 'Categoría', border: OutlineInputBorder()),
        items: options
            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
            .toList(),
        onChanged: (v) => onChanged(v ?? value),
      ),
    );
