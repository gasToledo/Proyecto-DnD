import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Buscador de monstruos del bestiario para sumarlos al combate.
///
/// Devuelve la criatura elegida y cuántas copias sumar, o `null` si se
/// canceló. Tirar la iniciativa de cada copia es responsabilidad de quien
/// llama (`rollInitiative`, una por copia): acá solo se elige qué sumar.
Future<({Creature creature, int count})?> showAddMonsterDialog(
  BuildContext context,
  ContentRepository repo,
) {
  return showDialog<({Creature creature, int count})>(
    context: context,
    builder: (context) => _AddMonsterDialog(repo: repo),
  );
}

class _AddMonsterDialog extends StatefulWidget {
  final ContentRepository repo;
  const _AddMonsterDialog({required this.repo});

  @override
  State<_AddMonsterDialog> createState() => _AddMonsterDialogState();
}

class _AddMonsterDialogState extends State<_AddMonsterDialog> {
  String _query = '';
  Creature? _selected;
  int _count = 1;

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return AlertDialog(
      title: const Text('Sumar monstruo'),
      content: SizedBox(
        width: 360,
        child: selected == null
            ? _search(context)
            : _quantity(context, selected),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        if (selected != null)
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop((creature: selected, count: _count)),
            child: const Text('Sumar'),
          ),
      ],
    );
  }

  Widget _search(BuildContext context) {
    final results = widget.repo.creaturesSorted
        .where((c) => c.name.toLowerCase().contains(_query.toLowerCase()))
        .take(30)
        .toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Buscar en el bestiario',
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 280,
          child: results.isEmpty
              ? const Center(child: Text('Sin resultados.'))
              : ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final creature = results[i];
                    return ListTile(
                      title: Text(creature.name),
                      subtitle: Text(creature.kind),
                      onTap: () => setState(() => _selected = creature),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _quantity(BuildContext context, Creature creature) {
    final pal = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                creature.name,
                style: const TextStyle(fontFamily: 'Georgia', fontSize: 18),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _selected = null),
              child: const Text('Cambiar'),
            ),
          ],
        ),
        Text(creature.kind, style: TextStyle(color: pal.textMuted)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: _count > 1 ? () => setState(() => _count--) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            SizedBox(
              width: 40,
              child: Text(
                '$_count',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20),
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _count++),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ],
    );
  }
}
