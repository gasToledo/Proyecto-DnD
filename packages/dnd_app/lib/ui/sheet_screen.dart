import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/characters_controller.dart';
import '../levelup/level_up_screen.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import '../theme/class_visuals.dart';
import 'portrait_image.dart';
import 'portrait_screen.dart';
import 'spell_edit_screen.dart';

part 'sheet/combat_section.dart';
part 'sheet/general_section.dart';
part 'sheet/inventory_section.dart';
part 'sheet/notes_section.dart';
part 'sheet/sheet_navigation.dart';
part 'sheet/sheet_widgets.dart';
part 'sheet/spells_section.dart';

/// Ancho a partir del cual el panel lateral queda fijo (igual que el
/// dashboard). Por debajo se colapsa a un Drawer.
const _kSheetWideBreakpoint = 900.0;

enum _SheetTab {
  personaje('Personaje', Icons.person),
  combate('Combate', Icons.sports_martial_arts),
  inventario('Inventario', Icons.backpack),
  notas('Notas', Icons.edit_note);

  const _SheetTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

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
  final VoidCallback onToggleTheme;
  const SheetScreen({
    super.key,
    required this.character,
    required this.repo,
    required this.controller,
    required this.onToggleTheme,
  });

  @override
  State<SheetScreen> createState() => _SheetScreenState();
}

class _SheetScreenState extends State<SheetScreen> {
  late Character _c = widget.character;
  _SheetTab _tab = _SheetTab.personaje;

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

  void _selectTab(_SheetTab tab) => setState(() => _tab = tab);

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

  void _openPortraitViewer(String portraitKey) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, _, _) => _PortraitViewer(portraitKey: portraitKey),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  void _openPortrait() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PortraitScreen(
          character: _c,
          repo: repo,
          api: ctrl.api,
          onUpdated: _replace,
        ),
      ),
    );
  }

  void _snack(String msg) =>
      showAppMessage(context, msg, duration: const Duration(seconds: 2));

  Widget _tabContent(_SheetTab tab) => switch (tab) {
    _SheetTab.personaje => _buildPersonaje(),
    _SheetTab.combate => _buildCombat(),
    _SheetTab.inventario => _buildInventory(),
    _SheetTab.notas => _buildNotes(),
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= _kSheetWideBreakpoint;
        if (wide) {
          return Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sidebar(context),
                Expanded(child: _sheetBody()),
              ],
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text('${_c.name} · Nivel ${_c.level}')),
          drawer: Drawer(
            child: SafeArea(
              child: Builder(builder: (ctx) => _sidebar(ctx, inDrawer: true)),
            ),
          ),
          body: _sheetBody(),
        );
      },
    );
  }
}
