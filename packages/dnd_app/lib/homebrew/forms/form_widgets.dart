part of '../homebrew_screen.dart';

// ---------------------------------------------------------- Helpers de form

class _FormScaffold extends StatelessWidget {
  final String title;
  final VoidCallback? onSave;
  final List<Widget> children;
  const _FormScaffold({
    required this.title,
    required this.onSave,
    required this.children,
  });

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

Widget _text(
  TextEditingController c,
  String label, {
  bool number = false,
  int maxLines = 1,
  VoidCallback? onChanged,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: TextField(
    controller: c,
    keyboardType: number ? TextInputType.number : null,
    maxLines: maxLines,
    onChanged: onChanged == null ? null : (_) => onChanged(),
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
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Tipo de daño',
        border: OutlineInputBorder(),
      ),
      items: ids
          .map(
            (id) => DropdownMenuItem(
              value: id,
              child: Text(DamageType.labelFor(id)),
            ),
          )
          .toList(),
      onChanged: (v) => onChanged(v ?? value),
    ),
  );
}

Widget _categoryDropdown(
  List<String> options,
  String value,
  ValueChanged<String> onChanged,
) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: DropdownButtonFormField<String>(
    initialValue: value,
    decoration: const InputDecoration(
      labelText: 'Categoría',
      border: OutlineInputBorder(),
    ),
    items: options
        .map((o) => DropdownMenuItem(value: o, child: Text(o)))
        .toList(),
    onChanged: (v) => onChanged(v ?? value),
  ),
);
