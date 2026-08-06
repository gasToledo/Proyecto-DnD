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
          _accountFooter(context),
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

  /// Con qué cuenta se entró, y cómo salir de ella. Va en el pie del panel
  /// porque es el único lugar que existe en los dos layouts: en ventana
  /// angosta este mismo widget es el contenido del Drawer.
  ///
  /// Los datos son los que afirmó el proveedor OIDC (ver `AccountInfo`), así
  /// que pueden faltar: sin nombre ni correo queda solo el botón de salir, que
  /// es lo que de verdad no puede faltar.
  Widget _accountFooter(BuildContext context) {
    final account = widget.account;
    if (account == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final pal = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (account.name case final name?)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                name,
                key: const ValueKey('account-name'),
                // El panel mide 236: un nombre largo tiene que recortarse, no
                // empujar el resto del pie fuera de la pantalla.
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: scheme.onSurface),
              ),
            ),
          if (account.email case final email?)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 1, 8, 0),
              child: Text(
                email,
                key: const ValueKey('account-email'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 8),
          // Mismo molde que «Cambiar tema», en carmesí: es el color que la
          // paleta ya usa para lo que resta (daño, PG), así que marca la
          // acción destructiva sin meter un rojo ajeno al resto. El borde va
          // atenuado para que no compita con el botón de al lado.
          OutlinedButton.icon(
            key: const ValueKey('logout-button'),
            onPressed: _logout,
            icon: const Icon(Icons.logout, size: 16),
            label: const Text('Cerrar sesión'),
            style: OutlinedButton.styleFrom(
              foregroundColor: pal.crimson,
              side: BorderSide(color: pal.crimson.withAlpha(110)),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// Cierra la sesión del servidor y navega a donde este indique. Ese destino
  /// es el cierre de sesión del proveedor: sin pasar por ahí, su cookie de SSO
  /// sigue viva y el próximo login entra sin pedir credenciales. Si el
  /// servidor no lo pudo calcular, se vuelve a la raíz, que redirige al login.
  Future<void> _logout() async {
    try {
      final logoutUrl = await controller.api.logout();
      browser.redirectTo(logoutUrl ?? '/');
    } catch (e) {
      // Sin esto, un fallo acá no se ve: la página no cambia y no aparece
      // nada, así que quien quiso salir se queda creyendo que salió.
      if (mounted) {
        showAppMessage(
          context,
          'No se pudo cerrar la sesión: $e',
          tone: AppMessageTone.error,
        );
      }
    }
  }
}
