part of '../sheet_screen.dart';

/// La pestaña **Campaña**: la vuelta del vínculo con el DM.
///
/// Hasta que existió, el jugador compartía su ficha y no veía nada a cambio —
/// solo avisos sueltos en la bandeja. Acá ve en qué mesa está, qué capítulos se
/// cerraron y qué batallas se pelearon.
///
/// Es de **solo lectura**, sin excepciones. Nada de esta pestaña escribe: ni la
/// ficha, ni la campaña. Lo que el capítulo repartió ya llegó como aviso y lo
/// anota el jugador en su inventario; esto es el recordatorio de qué pasó, no
/// el lugar donde se aplica.
///
/// Lo que **no** muestra, porque el servidor no lo manda: la descripción que el
/// DM escribió adentro de cada capítulo, los capítulos que todavía no cerró, y
/// el capítulo en marcha. De lo que están jugando ahora se entera en la mesa.
extension _CampaignSection on _SheetScreenState {
  Widget _buildCampana() {
    if (_campaignsError != null) {
      return AppErrorView(
        message: 'No se pudieron leer tus campañas.',
        details: '$_campaignsError',
        onRetry: _loadCampaigns,
      );
    }
    if (_loadingCampaigns && _campaigns == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: AppBusyLabel('Cargando tus campañas…')),
      );
    }

    final campaigns = _campaigns ?? const <PlayerCampaign>[];
    if (campaigns.isEmpty) {
      // Vacío con salida: el paso que falta es compartir la ficha, y es una
      // acción que ya existe en el panel lateral.
      return AppEmptyState(
        icon: Icons.flag_outlined,
        message:
            'Este personaje todavía no está en ninguna campaña.\n'
            'Compartilo con tu DM y acá va a aparecer lo que jueguen.',
        actions: [
          OutlinedButton.icon(
            onPressed: _shareCharacter,
            icon: const Icon(Icons.ios_share, size: 20),
            label: const Text('Compartir'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < campaigns.length; i++) ...[
          if (i > 0) const SizedBox(height: 24),
          ..._campaignBlock(campaigns[i]),
        ],
      ],
    );
  }

  /// Un bloque por campaña: la mesa, las batallas y los capítulos cerrados.
  ///
  /// Con varias campañas se apilan uno debajo del otro, sin selector: son una o
  /// dos, y un desplegable para elegir entre dos es un control que sobra.
  List<Widget> _campaignBlock(PlayerCampaign pc) {
    final pal = context.palette;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return [
      sheetCard(
        icon: Icons.flag_outlined,
        title: pc.campaign.name,
        collapseKey: 'campaign-${pc.memberId}',
        trailing: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GoldPill(
            pc.campaign.state.label,
            highlighted: pc.campaign.state == CampaignState.active,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pc.campaign.premise.isNotEmpty)
                Text(
                  pc.campaign.premise,
                  style: TextStyle(fontSize: 13, color: muted),
                ),
              if (pc.party.isNotEmpty) ...[
                if (pc.campaign.premise.isNotEmpty) const SizedBox(height: 8),
                Text(
                  'En la mesa también ${pc.party.length == 1 ? 'juega' : 'juegan'} '
                  '${_joinNames(pc.party)}.',
                  style: TextStyle(fontSize: 13, color: pal.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      _battlesCard(pc),
      const SizedBox(height: 16),
      _closedChaptersCard(pc),
    ];
  }

  /// Las batallas, agrupadas por el capítulo en que se pelearon.
  ///
  /// Son las de la **mesa entera** y no solo aquellas en las que estuvo este
  /// personaje: el registro guarda nombres, así que filtrar por nombre haría
  /// que renombrar un personaje le borrara el pasado.
  Widget _battlesCard(PlayerCampaign pc) {
    final pal = context.palette;
    final rounds = pc.battles.fold(0, (sum, b) => sum + b.rounds);

    // Un capítulo sin batallas no aporta un encabezado vacío.
    final groups = <(String, List<EncounterLog>)>[
      for (final chapter in pc.chapters)
        if (pc.battlesOf(chapter.id) case final list when list.isNotEmpty)
          (chapter.name, list),
      if (pc.looseBattles case final list when list.isNotEmpty)
        ('Sin capítulo', list),
    ];

    return sheetCard(
      icon: Icons.sports_martial_arts,
      title: 'Batallas',
      collapseKey: 'battles-${pc.memberId}',
      trailing: Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Text(
          pc.battles.isEmpty
              ? '—'
              : '${pc.battles.length} · $rounds ${rounds == 1 ? 'ronda' : 'rondas'}',
          style: TextStyle(
            fontSize: 12,
            color: pal.textMuted,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: groups.isEmpty
            ? Text(
                'Todavía no pelearon ninguna.',
                style: TextStyle(fontSize: 13, color: pal.textMuted),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < groups.length; i++) ...[
                    if (i > 0) const SizedBox(height: 16),
                    Eyebrow(groups[i].$1),
                    for (final log in groups[i].$2)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _battleRow(log),
                      ),
                  ],
                ],
              ),
      ),
    );
  }

  /// Una batalla. Va sobre `plaque` —hundida— por lo mismo que en el Cuaderno
  /// del DM: la escribió la app y no se corrige.
  Widget _battleRow(EncounterLog log) {
    final pal = context.palette;
    // Quiénes más pelearon. Sale del nombre del personaje: si el jugador lo
    // renombró después, la línea lista a todos en vez de romperse.
    final others = [
      for (final name in log.players)
        if (name != _c.name) name,
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      decoration: BoxDecoration(
        color: pal.plaque,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_battleTitle(log), style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 3),
                Text(
                  [
                    others.isEmpty ? 'Solo' : 'Con ${_joinNames(others)}',
                    _defeatedLabel(log),
                  ].join(' · '),
                  style: TextStyle(fontSize: 12, color: pal.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Text(
            '${log.rounds} ${log.rounds == 1 ? 'ronda' : 'rondas'}',
            style: TextStyle(
              fontSize: 12,
              color: pal.textMuted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  String _battleTitle(EncounterLog log) => log.monsters.isEmpty
      ? 'Una pelea'
      : 'Contra ${_joinNames([for (final m in log.monsters) m.count == 1 ? m.name : '${m.count} ${m.name}'])}';

  String _defeatedLabel(EncounterLog log) {
    final total = log.totalMonsters;
    final down = log.totalDefeated;
    if (total == 0) return 'sin enemigos';
    if (down == 0) return 'no cayó ninguno';
    if (down == total) return total == 1 ? 'cayó' : 'cayeron todos';
    return 'cayeron $down de $total';
  }

  /// Los capítulos ya cerrados y lo que repartió cada uno.
  ///
  /// Arranca **plegada**: lo que se repartió ya se anotó en su momento, así que
  /// es material de consulta y no lo primero que hay que ver.
  Widget _closedChaptersCard(PlayerCampaign pc) {
    final pal = context.palette;

    return sheetCard(
      icon: Icons.auto_stories_outlined,
      title: 'Capítulos cerrados',
      collapseKey: 'chapters-${pc.memberId}',
      trailing: Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Text(
          '${pc.chapters.length}',
          style: TextStyle(
            fontSize: 12,
            color: pal.textMuted,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: pc.chapters.isEmpty
            ? Text(
                'Todavía no cerraron ninguno. Cuando pase, acá va a quedar '
                'anotado lo que se repartió.',
                style: TextStyle(fontSize: 13, color: pal.textMuted),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < pc.chapters.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _chapterRow(pc.chapters[i]),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _chapterRow(Chapter chapter) {
    final pal = context.palette;
    // La regla vertical va como borde y no como hermano de la fila: un
    // `Container` estirado pediría altura al padre, y adentro de un scroll esa
    // altura es infinita.
    return Container(
      padding: const EdgeInsets.only(left: 14),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: pal.hairline, width: 2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chapter.name,
                  style: const TextStyle(fontFamily: 'Georgia', fontSize: 15),
                ),
                const SizedBox(height: 5),
                if (chapter.grantsLabel.isEmpty)
                  Text(
                    'Sin recompensas',
                    style: TextStyle(fontSize: 13, color: pal.textMuted),
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1, right: 6),
                        child: Icon(
                          Icons.savings_outlined,
                          size: 15,
                          color: pal.gold,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Te llevaste ${chapter.grantsLabel}',
                          style: TextStyle(fontSize: 13, color: pal.textMuted),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// «Mirna», «Mirna y Bardo», «Mirna, Bardo y Yina». Misma unión que usa el
  /// botín de un capítulo, para que la pestaña entera suene igual.
  String _joinNames(List<String> names) {
    if (names.length <= 1) return names.join();
    return '${names.take(names.length - 1).join(', ')} y ${names.last}';
  }
}
