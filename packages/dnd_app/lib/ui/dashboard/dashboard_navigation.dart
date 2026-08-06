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
                        const TextSpan(text: 'Milantus\n'),
                        // El subtítulo va más chico a propósito: a 17 no
                        // entra en los 236 de ancho del panel y parte la
                        // palabra, mientras que el nombre sí tiene que
                        // leerse como el título.
                        TextSpan(
                          text: 'Asistente de Aventuras',
                          style: TextStyle(
                            color: pal.gold,
                            fontSize: 11,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 18,
                      height: 1.25,
                      color: onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          appNavItem(
            context,
            icon: Icons.groups,
            label: 'Personajes',
            active: true,
          ),
          appNavItem(
            context,
            icon: Icons.auto_fix_high,
            label: 'Homebrew',
            onTap: () => run(_openHomebrew),
          ),
          appNavItem(
            context,
            icon: Icons.import_export,
            label: 'Importar / Exportar',
            onTap: () => run(_transferDialog),
          ),
          appNavItem(
            context,
            icon: Icons.settings,
            label: 'Ajustes',
            onTap: () => run(
              () => showDialog<bool>(
                context: this.context,
                builder: (_) => SettingsDialog(api: controller.api),
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
          // Null solo en tests, donde no se resuelve `PackageInfo`.
          if (widget.appVersion case final version?) ...[
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
}
