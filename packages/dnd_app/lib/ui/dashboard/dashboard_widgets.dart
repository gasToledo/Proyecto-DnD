part of '../dashboard_screen.dart';

class ImportPreviewDialog extends StatelessWidget {
  final BackupBundle bundle;
  final int characterCollisions;
  final int homebrewTotal;
  final int homebrewCollisions;

  const ImportPreviewDialog({
    super.key,
    required this.bundle,
    required this.characterCollisions,
    required this.homebrewTotal,
    required this.homebrewCollisions,
  });

  @override
  Widget build(BuildContext context) {
    final hasAdditionalData =
        bundle.homebrew != null || bundle.preferences != null;
    final names = bundle.characters
        .take(6)
        .map((entry) => '• ${entry.character.name}')
        .join('\n');
    final remaining = bundle.characters.length - 6;
    return AlertDialog(
      title: const Text('Revisar importación'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${bundle.characters.length} personaje(s) y '
                '${bundle.portraitCount} retrato(s).',
              ),
              if (names.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(names),
                if (remaining > 0) Text('…y $remaining más.'),
              ],
              if (characterCollisions > 0) ...[
                const SizedBox(height: 12),
                Text(
                  '$characterCollisions personaje(s) ya existen. Se '
                  'importarán como copias nuevas; no se sobrescribirán.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
              if (bundle.homebrew != null) ...[
                const SizedBox(height: 16),
                Text('Homebrew: $homebrewTotal elemento(s).'),
                if (homebrewCollisions > 0)
                  Text(
                    '$homebrewCollisions elemento(s) existentes serán '
                    'reemplazados al restaurar todo.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
              if (bundle.preferences != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'Preferencias: proveedor y modelo de imágenes. '
                  'Las credenciales locales se conservarán.',
                ),
              ],
              const SizedBox(height: 18),
              Text(
                hasAdditionalData
                    ? 'Elegí qué parte del respaldo querés restaurar.'
                    : 'Confirmá para importar este contenido.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        if (hasAdditionalData)
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Solo personajes'),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(context, hasAdditionalData),
          child: Text(hasAdditionalData ? 'Restaurar todo' : 'Importar'),
        ),
      ],
    );
  }
}

class _SaveStatusIndicator extends StatelessWidget {
  final CharactersController controller;

  const _SaveStatusIndicator({required this.controller});

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final state = controller.saveState;
    final (icon, label, color) = switch (state) {
      CharacterSaveState.saving => (Icons.sync, 'Guardando…', pal.gold),
      CharacterSaveState.error => (
        Icons.error_outline,
        'Error al guardar',
        Theme.of(context).colorScheme.error,
      ),
      CharacterSaveState.saved => (
        Icons.cloud_done_outlined,
        'Guardado',
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    };

    return Semantics(
      label: 'Estado del guardado: $label',
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: Container(
          key: ValueKey(state),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: pal.plaque,
            border: Border.all(color: pal.hairline),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 7),
              Text(label, style: TextStyle(fontSize: 12, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Tarjeta
// ----------------------------------------------------------------------------

/// Tarjeta de personaje: identidad arriba (retrato, nombre, especie·clase,
/// trasfondo y nivel) y los datos de combate abajo (PG, CA, velocidad,
/// iniciativa), para no tener que abrir la ficha para verlos.
class _CharacterCard extends StatefulWidget {
  final Character character;
  final ComputedSheet sheet;
  final ContentRepository repo;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onExport;
  final VoidCallback onDelete;
  const _CharacterCard({
    required this.character,
    required this.sheet,
    required this.repo,
    required this.onTap,
    required this.onRename,
    required this.onExport,
    required this.onDelete,
  });

  @override
  State<_CharacterCard> createState() => _CharacterCardState();
}

class _CharacterCardState extends State<_CharacterCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.character;
    final s = widget.sheet;
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final klassObj = widget.repo.characterClass(c.classId);
    final klass = klassObj?.name ?? c.classId;
    final accent = classAccent(klassObj, pal.gold);
    final race = widget.repo.race(c.raceId)?.name ?? c.raceId;
    final background = widget.repo.background(c.backgroundId)?.name;
    final portrait = c.portraitPaths.isNotEmpty ? c.portraitPaths.first : null;
    final hasPortrait = portrait != null && File(portrait).existsSync();
    final hp = c.combat.currentHp;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(color: _hover ? pal.gold : pal.hairline),
          borderRadius: BorderRadius.circular(14),
          boxShadow: _hover
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(70),
                    blurRadius: 26,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClassMedallion(
                        klass: klassObj,
                        image: hasPortrait ? FileImage(File(portrait)) : null,
                        fallback: c.name.characters.first,
                        size: 56,
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 18,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  classIcon(klassObj),
                                  size: 14,
                                  color: accent,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    '$race · $klass',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (background != null) ...[
                              const SizedBox(height: 6),
                              GoldPill(background),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Medallion(fallback: '${c.level}', size: 40),
                          const SizedBox(height: 3),
                          Text(
                            'NIVEL',
                            style: TextStyle(
                              fontSize: 8.5,
                              letterSpacing: 1,
                              color: pal.textMuted,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        width: 32,
                        child: PopupMenuButton<String>(
                          tooltip: 'Acciones',
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.more_vert, size: 18, color: muted),
                          onSelected: (v) {
                            if (v == 'rename') widget.onRename();
                            if (v == 'export') widget.onExport();
                            if (v == 'delete') widget.onDelete();
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'rename',
                              child: Text('Renombrar'),
                            ),
                            PopupMenuItem(
                              value: 'export',
                              child: Text('Exportar'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Eliminar'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    color: pal.hairline,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // Rótulo flexible: con 3 columnas la tarjeta es
                                // angosta y el valor nunca debe quedar tapado.
                                Expanded(
                                  child: Text(
                                    'PG',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      letterSpacing: 1,
                                      color: pal.textMuted,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$hp/${s.maxHp}',
                                  style: TextStyle(
                                    fontFamily: 'Georgia',
                                    fontSize: 13,
                                    height: 1,
                                    color: pal.crimson,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            ThinBar(
                              ratio: s.maxHp == 0 ? 0 : hp / s.maxHp,
                              color: pal.crimson,
                              track: pal.plaque,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      ShieldBadge('${s.armorClass}'),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 56,
                        child: StatPlaque(
                          label: 'Vel',
                          value: '${s.speed}',
                          dense: true,
                          valueColor: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 56,
                        child: StatPlaque(
                          label: 'Inic',
                          value: _signed(s.initiative),
                          dense: true,
                          valueColor: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
