part of '../creation_wizard.dart';

/// Paso 7 · Detalles: nombre y sabor (alineamiento y rasgo de personalidad).
class _DetailsStep extends StatefulWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _DetailsStep({required this.draft, required this.onChanged});

  @override
  State<_DetailsStep> createState() => _DetailsStepState();
}

class _DetailsStepState extends State<_DetailsStep> {
  late final _name = TextEditingController(text: widget.draft.name);
  late final _trait = TextEditingController(
    text: widget.draft.personalityTrait,
  );

  @override
  void dispose() {
    _name.dispose();
    _trait.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Emblema'),
        const SizedBox(height: 12),
        Row(
          children: [
            ClassMedallion(
              klass: d.klass,
              fallback: d.name.trim().isEmpty
                  ? '?'
                  : d.name.trim().characters.first,
              size: 72,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hasta que le pongas un retrato, tu personaje usa el '
                    'emblema de ${d.klass?.name ?? "su clase"}.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Podés generar o elegir un retrato después, desde la ficha.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        const _SectionHeader(title: 'Nombre'),
        const SizedBox(height: 12),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Nombre del personaje',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) {
            d.name = v;
            widget.onChanged();
          },
        ),
        const SizedBox(height: 24),
        const _SectionHeader(title: 'Alineamiento'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Sin definir'),
              selected: d.alignment == null,
              onSelected: (_) {
                setState(() => d.alignment = null);
                widget.onChanged();
              },
            ),
            for (final a in CharacterAlignment.values)
              ChoiceChip(
                label: Text(a.label),
                selected: d.alignment == a,
                onSelected: (_) {
                  setState(() => d.alignment = a);
                  widget.onChanged();
                },
              ),
          ],
        ),
        const SizedBox(height: 26),
        const _SectionHeader(title: 'Rasgo de personalidad'),
        const SizedBox(height: 12),
        TextField(
          controller: _trait,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText:
                'Una línea que lo defina. Ej: "Nunca deja una deuda sin pagar."',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) {
            d.personalityTrait = v;
            widget.onChanged();
          },
        ),
      ],
    );
  }
}

/// Pastilla de resumen: texto sobre placa, con ícono opcional.
class _SummaryPill extends StatelessWidget {
  final String text;
  final IconData? icon;
  const _SummaryPill(this.text, {this.icon});

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      decoration: BoxDecoration(
        color: pal.plaque,
        border: Border.all(color: pal.hairline),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: pal.gold),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Rótulo de bloque dentro de la tarjeta de resumen.
class _SummaryLabel extends StatelessWidget {
  final String text;
  const _SummaryLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        letterSpacing: 1,
        color: context.palette.textMuted,
      ),
    ),
  );
}
