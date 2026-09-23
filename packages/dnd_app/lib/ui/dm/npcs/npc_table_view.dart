import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/app_widgets.dart';
import '../../portrait_image.dart';

/// El retrato de un PNJ a pantalla completa, para girar la tablet y decir
/// «este es el tipo que les habla».
///
/// Muestra el retrato y el nombre, **y nada más**: ni estadísticas, ni tags, ni
/// estado, ni trasfondo. Es el DM quien decide mostrarlo en la mesa; la app no
/// le manda nada al jugador. El nombre se puede ocultar para cuando el grupo
/// todavía no lo conoce.
class NpcTableViewScreen extends StatefulWidget {
  final String name;
  final String? portraitKey;

  const NpcTableViewScreen({super.key, required this.name, this.portraitKey});

  @override
  State<NpcTableViewScreen> createState() => _NpcTableViewScreenState();
}

class _NpcTableViewScreenState extends State<NpcTableViewScreen> {
  bool _nameHidden = false;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final key = widget.portraitKey;
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: _nameHidden ? 'Mostrar el nombre' : 'Ocultar el nombre',
            icon: Icon(
              _nameHidden
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
            onPressed: () => setState(() => _nameHidden = !_nameHidden),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, box) {
          // 3:4 como el taller de retratos, y lo más grande que entre dejando
          // lugar para el nombre.
          final height = (box.maxHeight - 120).clamp(160.0, 720.0);
          final width = (height * 3 / 4).clamp(120.0, box.maxWidth - 32);
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: width,
                  height: width * 4 / 3,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: pal.plaque,
                    border: Border.all(color: pal.gold, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: key == null
                      ? Center(
                          child: Medallion(
                            fallback: widget.name.characters.first,
                            size: width / 2,
                          ),
                        )
                      : PortraitImage(portraitKey: key),
                ),
                if (!_nameHidden) ...[
                  const SizedBox(height: 20),
                  Text(
                    widget.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Georgia', fontSize: 38),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
