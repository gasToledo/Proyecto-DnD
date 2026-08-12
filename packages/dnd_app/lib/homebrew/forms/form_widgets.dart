part of '../homebrew_screen.dart';

// ---------------------------------------------------------- Helpers de form

/// Armazón de los formularios homebrew.
///
/// Es un [Form] de verdad y no una lista de campos sueltos: la validación va
/// pegada a cada campo, así el error se lee donde está el problema en vez de
/// resumirse en un aviso que no dice cuál es. El botón Guardar queda siempre
/// habilitado —uno gris no explica qué le falta— y al pulsarlo se enciende la
/// validación continua para que corregir se vea al instante.
class _FormScaffold extends StatefulWidget {
  final String title;

  /// Se llama solo si todos los campos validan.
  final VoidCallback onSave;
  final List<Widget> children;
  const _FormScaffold({
    required this.title,
    required this.onSave,
    required this.children,
  });

  @override
  State<_FormScaffold> createState() => _FormScaffoldState();
}

class _FormScaffoldState extends State<_FormScaffold> {
  final _form = GlobalKey<FormState>();

  /// Arranca apagada: marcar en rojo un campo que todavía se está tipeando es
  /// ruido. Se enciende en el primer intento de guardar que falla.
  var _autovalidate = AutovalidateMode.disabled;

  void _save() {
    if (_form.currentState!.validate()) {
      widget.onSave();
      return;
    }
    setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
    showAppMessage(
      context,
      'No se guardó nada: revisá los campos marcados en rojo.',
      tone: AppMessageTone.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Form(
        key: _form,
        autovalidateMode: _autovalidate,
        child: PageBody(children: widget.children),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Cancelar explícito: la flecha del AppBar hace lo mismo, pero
              // ahí arriba no se lee como "salir sin guardar".
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
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

// ------------------------------------------------------------------ Campos

Widget _text(
  TextEditingController c,
  String label, {
  bool number = false,
  int maxLines = 1,
  String? Function(String?)? validator,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: TextFormField(
    controller: c,
    keyboardType: number ? TextInputType.number : null,
    maxLines: maxLines,
    validator: validator,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
  ),
);

/// Tipo de daño como desplegable en español. El valor persistido sigue siendo
/// el id en inglés; escribirlo a mano obligaba a conocerlo y un tipeo hacía
/// pasar un tipo desconocido sin aviso.
Widget _damageTypeDropdown(String value, ValueChanged<String> onChanged) {
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
  );
}

/// Desplegable de un valor cerrado: se elige por su etiqueta en español, pero
/// lo que se guarda es el id interno. Los ids son parte del contrato con el
/// motor de reglas, así que no se traducen — solo se dejan de mostrar.
Widget _idDropdown({
  required String label,
  required String value,
  required Map<String, String> options,
  required ValueChanged<String> onChanged,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: DropdownButtonFormField<String>(
    // Un id fuera del catálogo (homebrew viejo, importado) se conserva como
    // opción abajo, así que siempre hay exactamente una que corresponde a
    // `value`: abrir el formulario no puede cambiarlo por la espalda.
    initialValue: value,
    isExpanded: true,
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
  ValueChanged<String> onChanged,
) => _idDropdown(
  label: 'Categoría',
  value: value,
  options: options,
  onChanged: onChanged,
);

/// Chips de selección múltiple sobre ids con etiqueta en español.
Widget _idChips(
  Map<String, String> options,
  Set<String> selected,
  VoidCallback onChanged,
) => Wrap(
  spacing: 6,
  runSpacing: 6,
  children: [
    for (final entry in options.entries)
      FilterChip(
        label: Text(entry.value),
        selected: selected.contains(entry.key),
        onSelected: (v) {
          v ? selected.add(entry.key) : selected.remove(entry.key);
          onChanged();
        },
      ),
  ],
);
