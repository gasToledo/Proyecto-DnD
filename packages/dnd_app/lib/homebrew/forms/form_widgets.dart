part of '../homebrew_screen.dart';

// ---------------------------------------------------------- Helpers de form

/// Ancho a partir del cual un formulario con [_FormScaffold.panel] lo muestra
/// al costado. Es el corte de shell de toda la aplicación (`diseno-web.md`
/// §7.2): por debajo tampoco entra el panel lateral de 236 px.
const double _panelBreakpoint = 900;

/// Armazón de los formularios homebrew.
///
/// Es un [Form] de verdad y no una lista de campos sueltos: la validación va
/// pegada a cada campo, así el error se lee donde está el problema en vez de
/// resumirse en un aviso que no dice cuál es. El botón Guardar queda siempre
/// habilitado —uno gris no explica qué le falta— y al pulsarlo se enciende la
/// validación continua para que corregir se vea al instante.
///
/// Con [panel], desde [_panelBreakpoint] el formulario se parte en dos: los
/// campos a la izquierda y el panel a la derecha, con scroll propio. Más
/// angosto el panel no se muestra, y cada formulario decide qué de lo que dice
/// lleva adentro de los campos (ver [_WithoutPanel]).
class _FormScaffold extends StatefulWidget {
  final String title;

  /// Se llama solo si todos los campos validan.
  final VoidCallback onSave;

  /// Se llama cuando guardar falla, antes de avisar. Existe para que un
  /// formulario con secciones plegadas las abra: un campo en rojo adentro de
  /// una tarjeta cerrada no se ve.
  final VoidCallback? onInvalid;
  final Widget? panel;
  final List<Widget> children;
  const _FormScaffold({
    required this.title,
    required this.onSave,
    required this.children,
    this.onInvalid,
    this.panel,
  });

  @override
  State<_FormScaffold> createState() => _FormScaffoldState();
}

class _FormScaffoldState extends State<_FormScaffold> {
  final _form = GlobalKey<FormState>();

  /// Arranca apagada: marcar en rojo un campo que todavía se está tipeando es
  /// ruido. Se enciende en el primer intento de guardar que falla.
  var _autovalidate = AutovalidateMode.disabled;

  /// Si se tocó algo desde que se abrió el formulario. Sin esto, salir con la
  /// flecha tira a la basura un rato de trabajo sin preguntar: el aviso de
  /// «No se guardó ningún cambio» llega cuando ya no hay nada que hacer.
  ///
  /// ponytail: lo arma solo lo que pasa por un campo del [Form] — todos los
  /// `_text` y los `_idDropdown`, que es donde se tipea. Un cambio hecho
  /// únicamente en el editor de efectos o en un chip no lo arma, porque esos
  /// no son `FormField`. Si alguna vez duele, esos widgets tienen que recibir
  /// un `markDirty` del formulario y llamarlo en su `onChanged`.
  var _dirty = false;

  /// Pregunta antes de tirar lo escrito. Devuelve por [Navigator.pop] directo
  /// y no por `maybePop`, que volvería a entrar acá.
  Future<void> _confirmDiscard() async {
    final pal = context.palette;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        icon: Icons.warning_amber_rounded,
        iconColor: pal.crimson,
        title: '¿Salir sin guardar?',
        content: Text('Lo que escribiste en «${widget.title}» se pierde.'),
        actions: [
          DialogAction(
            'Seguir editando',
            keyHint: 'Esc',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          DialogAction(
            'Salir sin guardar',
            primary: true,
            color: pal.crimson,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  void _save() {
    if (_form.currentState!.validate()) {
      widget.onSave();
      return;
    }
    widget.onInvalid?.call();
    setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
    showAppMessage(
      context,
      'No se guardó nada: revisá los campos marcados en rojo.',
      tone: AppMessageTone.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Cubre la flecha del AppBar y el gesto de atrás del navegador, que es
      // por donde de verdad se sale de acá sin querer.
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: _scaffold(context),
    );
  }

  Widget _scaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Form(
        key: _form,
        autovalidateMode: _autovalidate,
        onChanged: () => _dirty = true,
        child: LayoutBuilder(
          builder: (context, box) {
            final panel = widget.panel;
            final side = panel != null && box.maxWidth >= _panelBreakpoint;
            final fields = _SidePanelScope(
              visible: side,
              // 680 y no 760 con panel: 640 de campos más el margen, que es la
              // medida con la que se diseñó la columna al lado de 400.
              child: PageBody(
                maxWidth: side ? 680 : 760,
                children: widget.children,
              ),
            );
            if (!side) return fields;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: fields),
                Container(
                  width: 400,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      left: BorderSide(color: context.palette.hairline),
                    ),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [panel],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Cancelar explícito: la flecha del AppBar hace lo mismo, pero
              // ahí arriba no se lee como "salir sin guardar".
              //
              // `maybePop` y no `pop`: es lo único que consulta al [PopScope],
              // así que un `pop` directo se saltearía la pregunta.
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.maybePop(context),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Si el panel de [_FormScaffold] se está mostrando.
class _SidePanelScope extends InheritedWidget {
  final bool visible;
  const _SidePanelScope({required this.visible, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SidePanelScope>()?.visible ??
      false;

  @override
  bool updateShouldNotify(_SidePanelScope old) => visible != old.visible;
}

/// Muestra [child] solo cuando no hay panel lateral: es el lugar de repuesto,
/// dentro de los campos, de lo que el panel dice en una pantalla ancha.
///
/// Es un widget y no una consulta en el `build` del formulario porque ese
/// `build` corre arriba del [_FormScaffold], donde el panel todavía no se
/// decidió.
class _WithoutPanel extends StatelessWidget {
  final Widget child;
  const _WithoutPanel(this.child);

  @override
  Widget build(BuildContext context) =>
      _SidePanelScope.of(context) ? const SizedBox.shrink() : child;
}

/// Sección plegable de un formulario: lo opcional, que no tiene por qué estar
/// abierto para crear algo simple.
///
/// Tiene la forma de la tarjeta de la ficha (`sheetCard`), con una diferencia
/// deliberada: plegada **no desmonta** su contenido. Los campos de adentro
/// siguen siendo parte del [Form], así que un peso ilegible en una tarjeta
/// cerrada igual frena el guardado; con `sheetCard`, que los quita del árbol,
/// se habría guardado sin mirarlo.
///
/// Cerrada, la cabecera muestra [summary]: lo que ya tiene cargado, para no
/// abrirla a ver si falta algo.
class _FormSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String summary;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;
  const _FormSection({
    required this.icon,
    required this.title,
    required this.summary,
    required this.expanded,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onToggle,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 13, 8, 13),
                decoration: BoxDecoration(
                  border: expanded
                      ? Border(bottom: BorderSide(color: pal.hairline))
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: pal.gold),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        expanded ? '' : summary,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: pal.textMuted),
                      ),
                    ),
                    AnimatedRotation(
                      turns: expanded ? 0 : -0.25,
                      duration: context.motion(
                        const Duration(milliseconds: 150),
                      ),
                      child: Icon(
                        Icons.expand_more,
                        size: 20,
                        color: pal.textMuted,
                        semanticLabel: expanded ? 'Plegar' : 'Desplegar',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Visibility(
              visible: expanded,
              maintainState: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Separa lo que hace falta para guardar de lo que se puede dejar para después.
const _optionalRule = [
  SectionRule(),
  Center(child: Eyebrow('Lo demás es opcional')),
];

/// Lo que significa algo que se puede elegir: una propiedad, un tipo de daño,
/// una maestría.
///
/// [note] es lo que vale para todas las opciones del mismo tipo («solo la
/// aprovecha quien tiene el rasgo…») y va atenuado debajo.
typedef _Explained = ({String kicker, String title, String text, String? note});

/// La explicación de lo que se está eligiendo.
///
/// Quien arma su primera arma elige «Sutil» o «Derribar» sin saber qué hacen,
/// y ese es el momento de decírselo. Va en el panel lateral cuando lo hay y
/// debajo del campo cuando no, siempre con la misma forma.
class _Explanation extends StatelessWidget {
  final _Explained explained;
  const _Explanation(this.explained);

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: pal.plaque,
        borderRadius: BorderRadius.circular(12),
      ),
      // Región viva: cambia sola al tocar otra opción, y quien no la ve tiene
      // que enterarse de que cambió.
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              explained.kicker.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w500,
                color: pal.gold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              explained.title,
              style: const TextStyle(fontFamily: 'Georgia', fontSize: 20),
            ),
            const SizedBox(height: 6),
            Text(
              explained.text,
              style: const TextStyle(fontSize: 13.5, height: 1.55),
            ),
            if (explained.note case final note?) ...[
              const SizedBox(height: 6),
              Text(
                note,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: pal.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// El recordatorio de lo que ya se eligió, cada cosa con su explicación corta.
class _ChosenList extends StatelessWidget {
  final List<_Explained> items;
  const _ChosenList(this.items);

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Eyebrow('Lo que ya elegiste'),
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: pal.hairline)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: item.title,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      TextSpan(
                        text: '  ${item.kicker.toLowerCase()}',
                        style: TextStyle(fontSize: 11, color: pal.textMuted),
                      ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 13.5),
                ),
                const SizedBox(height: 2),
                Text(
                  item.text,
                  style: TextStyle(fontSize: 12.5, height: 1.5, color: muted),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Lo que comparten los formularios que explican lo que se elige: qué se está
/// tocando, qué secciones están abiertas y el panel lateral.
///
/// Cada formulario pone lo suyo en [explain] (qué significa cada clave) y en
/// [chosenKeys] (qué lleva elegido); el resto —dónde va la explicación según
/// haya panel o no, abrir todo si guardar falla— es igual en los ocho.
mixin _GuidedForm<T extends StatefulWidget> on State<T> {
  /// Qué se está tocando, como clave que entiende [explain]. Null hasta la
  /// primera elección.
  String? focus;

  final Set<String> _open = {};
  final Set<String> _sections = {};
  final List<TextEditingController> _watched = [];

  /// La explicación de [key], o null si no hay texto que dar: un valor que
  /// trajo un pack y el glosario no conoce.
  _Explained? explain(String key);

  /// Las claves de lo ya elegido, en el orden en que se listan en el panel.
  Iterable<String> get chosenKeys;

  /// Controlador que la vista previa refleja: cada tecla redibuja, y se
  /// libera con el formulario.
  TextEditingController watch(String text) {
    final c = TextEditingController(text: text)..addListener(redraw);
    _watched.add(c);
    return c;
  }

  @override
  void dispose() {
    for (final c in _watched) {
      c.dispose();
    }
    super.dispose();
  }

  void redraw() => setState(() {});

  void focusOn(String key) => setState(() => focus = key);

  /// Para [_FormScaffold.onInvalid]: un campo en rojo adentro de una sección
  /// cerrada no se ve.
  void openAllSections() => setState(() => _open.addAll(_sections));

  /// Una [_FormSection] cuyo estado abierto lleva el formulario, por título.
  Widget section({
    required IconData icon,
    required String title,
    required String summary,
    required List<Widget> children,
  }) {
    _sections.add(title);
    return _FormSection(
      icon: icon,
      title: title,
      summary: summary,
      expanded: _open.contains(title),
      onToggle: () => setState(
        () => _open.contains(title) ? _open.remove(title) : _open.add(title),
      ),
      children: children,
    );
  }

  /// La explicación debajo del campo, para cuando no hay panel lateral.
  /// [here] dice si el foco actual es de este lugar del formulario.
  Widget explainHere(bool Function(String focus) here) {
    final key = focus;
    final explained = key == null || !here(key) ? null : explain(key);
    if (explained == null) return const SizedBox.shrink();
    return _WithoutPanel(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: _Explanation(explained),
      ),
    );
  }

  /// El panel lateral: [preview] bajo [previewTitle], lo que se está tocando
  /// (o [hint] mientras no se tocó nada) y lo que ya se eligió.
  Widget guidePanel({
    required String previewTitle,
    required Widget preview,
    required String hint,
  }) {
    final key = focus;
    final explained = key == null ? null : explain(key);
    final chosen = [
      for (final k in chosenKeys)
        if (k != key) ?explain(k),
    ];
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Eyebrow(previewTitle),
        preview,
        const SizedBox(height: 16),
        if (explained != null)
          _Explanation(explained)
        else
          Text(
            hint,
            style: TextStyle(fontSize: 13, height: 1.45, color: muted),
          ),
        if (chosen.isNotEmpty) ...[
          const SizedBox(height: 18),
          _ChosenList(chosen),
        ],
      ],
    );
  }
}

/// La fila de la lista tal como va a quedar, para la vista previa de los
/// formularios cuyo contenido se ve así (arma, armadura, objeto).
Widget _rowPreview(
  String name, {
  List<String> pills = const [],
  List<(String, String)> stats = const [],
}) => Builder(
  builder: (context) => DenseRows(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _previewName(context, name),
            if (pills.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final pill in pills) GoldPill(pill, highlighted: false),
                ],
              ),
            ],
            if (stats.isNotEmpty) ...[
              const SizedBox(height: 8),
              _statBand(context, stats, wide: false),
            ],
          ],
        ),
      ),
    ],
  ),
);

/// El nombre de lo que se está armando, o un aviso atenuado mientras falta.
Widget _previewName(BuildContext context, String name, {double? size}) => Text(
  name.trim().isEmpty ? 'Todavía sin nombre' : name.trim(),
  style: TextStyle(
    fontWeight: size == null ? FontWeight.w500 : null,
    fontFamily: size == null ? null : 'Georgia',
    fontSize: size,
    color: name.trim().isEmpty
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : null,
  ),
);

/// El resumen de una sección cerrada: [parts] unidas, o [none] si no hay nada.
String _orNone(List<String> parts, String none) =>
    parts.isEmpty ? none : parts.join(' · ');

/// Lo que concede una lista de efectos tal como lo lee el jugador al crear un
/// personaje: los rasgos con su texto, o los efectos descritos si no hay
/// rasgos. Es [readableTraits], la misma lectura que usa la creación.
List<Widget> _traitsPreview(
  BuildContext context,
  List<Effect> effects,
  ContentRepository repo,
) {
  final muted = Theme.of(context).colorScheme.onSurfaceVariant;
  final traits = readableTraits(effects, repo);
  if (traits.isEmpty) {
    return [
      Text(
        'Todavía no concede nada.',
        style: TextStyle(fontSize: 13, color: muted),
      ),
    ];
  }
  return [
    for (final t in traits)
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: t.name,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              if (t.description.isNotEmpty)
                TextSpan(
                  text: '  ${t.description}',
                  style: TextStyle(color: muted),
                ),
            ],
          ),
          style: const TextStyle(fontSize: 13, height: 1.45),
        ),
      ),
  ];
}

/// Una explicación armada con los glosarios del motor.
_Explained _explained(
  String kicker,
  String title,
  String text, [
  String? note,
]) => (kicker: kicker, title: title, text: text, note: note);

/// Las cifras de una fila de contenido: rótulo chico arriba y valor en cifras
/// tabulares. Las comparten la lista y la vista previa del formulario, que
/// tiene que verse igual que la fila que va a quedar.
Widget _statBand(
  BuildContext context,
  List<(String, String)> stats, {
  required bool wide,
}) {
  final pal = context.palette;
  return Wrap(
    spacing: 18,
    runSpacing: 6,
    children: [
      for (final (label, value) in stats)
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: wide
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 8.5,
                letterSpacing: 1.2,
                color: pal.textMuted,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
    ],
  );
}

// ------------------------------------------------------------- Validadores
//
// Devuelven el mensaje de error, o null si el valor sirve. Nunca corrigen: un
// valor inválido tiene que quedar a la vista y frenar el guardado, no
// reemplazarse por un defecto que nadie pidió (que es lo que hacía el
// `int.tryParse(...) ?? 10` de antes).

String? _requiredText(String? value, String what) =>
    (value ?? '').trim().isEmpty ? 'Escribí $what.' : null;

/// Dado de daño con la forma `NdM` (p.ej. `1d8`, `2d6`).
final _dicePattern = RegExp(r'^\d+d\d+$');

String? _diceValue(String? value, {required bool optional}) {
  final text = (value ?? '').trim();
  if (text.isEmpty) {
    return optional ? null : 'Escribí un dado, por ejemplo 1d8.';
  }
  return _dicePattern.hasMatch(text)
      ? null
      : 'Formato de dado inválido: se espera algo como 1d8.';
}

String? _intInRange(String? value, int min, int max, {required bool optional}) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return optional ? null : 'Escribí un número.';
  final n = int.tryParse(text);
  if (n == null) return 'Tiene que ser un número entero.';
  return n < min || n > max ? 'Tiene que estar entre $min y $max.' : null;
}

/// Peso en libras. Admite fracciones decimales porque el catálogo incluye
/// objetos de media libra y de un cuarto de libra.
String? _weightValue(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return 'Escribí un peso, 0 si no cuenta.';
  final n = double.tryParse(text);
  if (n == null) return 'Tiene que ser un número.';
  return n < 0 ? 'No puede ser negativo.' : null;
}

// ------------------------------------------------------------------ Campos

Widget _text(
  TextEditingController c,
  String label, {
  bool number = false,
  int maxLines = 1,
  String? Function(String?)? validator,
  VoidCallback? onTap,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: TextFormField(
    controller: c,
    keyboardType: number ? TextInputType.number : null,
    maxLines: maxLines,
    validator: validator,
    onTap: onTap,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
  ),
);

/// Campos en una fila mientras entren y, más angosto, uno debajo del otro.
///
/// [flex] reparte el ancho: un dado ocupa menos que un desplegable. El corte
/// es el de las filas de la lista ([_rowWideWidth]): por debajo, tres campos
/// lado a lado ya recortan sus rótulos.
Widget _fieldRow(List<Widget> fields, {List<int>? flex}) => LayoutBuilder(
  builder: (context, box) {
    if (box.maxWidth < _rowWideWidth) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: fields,
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < fields.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(flex: flex?[i] ?? 1, child: fields[i]),
        ],
      ],
    );
  },
);

/// Tipo de daño como desplegable en español. El valor persistido sigue siendo
/// el id en inglés; escribirlo a mano obligaba a conocerlo y un tipeo hacía
/// pasar un tipo desconocido sin aviso.
Widget _damageTypeDropdown(
  String value,
  ValueChanged<String> onChanged, {
  VoidCallback? onTap,
}) {
  // Un arma homebrew vieja puede tener un tipo fuera del catálogo: se conserva
  // como opción para que editarla no lo cambie por la espalda.
  final ids = [
    for (final t in DamageType.values) t.id,
    if (DamageType.fromId(value) == null) value,
  ];
  return _idDropdown(
    label: 'Tipo de daño',
    value: value,
    options: {for (final id in ids) id: DamageType.labelFor(id)},
    onChanged: onChanged,
    onTap: onTap,
  );
}

/// Desplegable de un valor cerrado: se elige por su etiqueta en español, pero
/// lo que se guarda es el id interno. Los ids son parte del contrato con el
/// motor de reglas, así que no se traducen — solo se dejan de mostrar.
///
/// [onTap] avisa que se abrió, antes de elegir: es lo que le permite a un
/// formulario explicar las opciones mientras se miran.
Widget _idDropdown({
  required String label,
  required String value,
  required Map<String, String> options,
  required ValueChanged<String> onChanged,
  VoidCallback? onTap,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: DropdownButtonFormField<String>(
    // Un id fuera del catálogo (homebrew viejo, importado) se conserva como
    // opción abajo, así que siempre hay exactamente una que corresponde a
    // `value`: abrir el formulario no puede cambiarlo por la espalda.
    initialValue: value,
    isExpanded: true,
    onTap: onTap,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    items: [
      for (final entry in options.entries)
        DropdownMenuItem(value: entry.key, child: Text(entry.value)),
      if (!options.containsKey(value))
        DropdownMenuItem(value: value, child: Text('$value (desconocido)')),
    ],
    onChanged: (v) => onChanged(v ?? value),
  ),
);

Widget _categoryDropdown(
  Map<String, String> options,
  String value,
  ValueChanged<String> onChanged, {
  VoidCallback? onTap,
}) => _idDropdown(
  label: 'Categoría',
  value: value,
  options: options,
  onChanged: onChanged,
  onTap: onTap,
);

/// Chips de selección múltiple sobre ids con etiqueta en español.
///
/// [onTap] recibe el id tocado, se haya marcado o desmarcado: lo usa quien
/// explica la opción al tocarla.
Widget _idChips(
  Map<String, String> options,
  Set<String> selected,
  VoidCallback onChanged, {
  ValueChanged<String>? onTap,
}) => Wrap(
  spacing: 6,
  runSpacing: 6,
  children: [
    for (final entry in options.entries)
      FilterChip(
        label: Text(entry.value),
        selected: selected.contains(entry.key),
        onSelected: (v) {
          v ? selected.add(entry.key) : selected.remove(entry.key);
          onTap?.call(entry.key);
          onChanged();
        },
      ),
  ],
);
