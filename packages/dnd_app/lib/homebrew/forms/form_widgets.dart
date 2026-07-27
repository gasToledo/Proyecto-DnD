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
  VoidCallback? onChanged,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: TextField(
    controller: c,
    keyboardType: number ? TextInputType.number : null,
    onChanged: onChanged == null ? null : (_) => onChanged(),
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
  ),
);

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
