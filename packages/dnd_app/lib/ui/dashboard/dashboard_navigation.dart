part of '../dashboard_screen.dart';

extension _DashboardNavigation on _DashboardScreenState {
  Widget _sidebar(BuildContext context, {bool inDrawer = false}) {
    final pal = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    // Desde el panel colapsado, navegar debe cerrar el Drawer primero.
    void run(VoidCallback action) {
      if (inDrawer) Navigator.of(context).pop();
      action();
    }

    return Container(
      width: 236,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(right: BorderSide(color: pal.hairline)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 20),
            child: Row(
              children: [
                Transform.rotate(
                  angle: 0.785398,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: pal.gold,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Fichas\n'),
                        TextSpan(
                          text: 'D&D 5e',
                          style: TextStyle(color: pal.gold),
                        ),
                      ],
                    ),
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 17,
                      height: 1.1,
                      color: onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _navItem(
            context,
            icon: Icons.groups,
            label: 'Personajes',
            active: true,
          ),
          _navItem(
            context,
            icon: Icons.auto_fix_high,
            label: 'Homebrew',
            onTap: () => run(_openHomebrew),
          ),
          _navItem(
            context,
            icon: Icons.import_export,
            label: 'Importar / Exportar',
            onTap: () => run(_transferDialog),
          ),
          _navItem(
            context,
            icon: Icons.settings,
            label: 'Ajustes',
            onTap: () => run(
              () => showDialog<bool>(
                context: this.context,
                builder: (_) => const SettingsDialog(),
              ),
            ),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: widget.onToggleTheme,
            icon: const Icon(Icons.dark_mode, size: 16),
            label: const Text('Cambiar tema'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              side: BorderSide(color: pal.hairline),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
          // La versión sale del mismo servicio que compara contra el último
          // Release, así que el rótulo no puede contradecir al aviso de
          // actualización. Es null solo en tests, donde no hay servicio.
          if (widget.updateService?.currentVersion case final version?) ...[
            const SizedBox(height: 10),
            Text(
              'v$version',
              key: const ValueKey('app-version'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.3,
                color: pal.gold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _navItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    bool active = false,
    VoidCallback? onTap,
  }) {
    final pal = context.palette;
    final fg = active
        ? pal.gold
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: active ? pal.goldSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          hoverColor: pal.plaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
