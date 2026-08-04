part of '../sheet_screen.dart';

// ---------------------------------------------------------------- Widgets

/// Visor de retrato a pantalla completa, con zoom/pan y cierre con Escape,
/// clic afuera o el botón de cerrar.
class _PortraitViewer extends StatelessWidget {
  final String portraitKey;
  const _PortraitViewer({required this.portraitKey});

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.escape): const _DismissViewerIntent(),
      },
      child: Actions(
        actions: {
          _DismissViewerIntent: CallbackAction<_DismissViewerIntent>(
            onInvoke: (_) => Navigator.of(context).pop(),
          ),
        },
        child: Focus(
          autofocus: true,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Stack(
                children: [
                  Center(
                    child: GestureDetector(
                      onTap:
                          () {}, // absorbe el tap para no cerrar sobre la imagen
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: PortraitImage(
                            portraitKey: portraitKey,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
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

class _DismissViewerIntent extends Intent {
  const _DismissViewerIntent();
}

String _signed(int v) => v >= 0 ? '+$v' : '$v';
