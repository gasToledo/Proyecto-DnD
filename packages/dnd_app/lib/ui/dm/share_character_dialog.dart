import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/api_client.dart';
import '../../api/api_exception.dart';
import '../../api/api_models.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';

/// Le da al jugador el código con el que su DM suma este personaje a una mesa,
/// y le muestra dónde está compartido para que pueda dejar de estarlo.
///
/// El código nace acá y no del lado del DM a propósito: el acceso a una ficha
/// solo puede empezar por una decisión de su dueño.
Future<void> showShareCharacterDialog(
  BuildContext context, {
  required ApiClient api,
  required String characterId,
  required String characterName,
}) => showDialog<void>(
  context: context,
  builder: (_) => _ShareCharacterDialog(
    api: api,
    characterId: characterId,
    characterName: characterName,
  ),
);

class _ShareCharacterDialog extends StatefulWidget {
  final ApiClient api;
  final String characterId;
  final String characterName;

  const _ShareCharacterDialog({
    required this.api,
    required this.characterId,
    required this.characterName,
  });

  @override
  State<_ShareCharacterDialog> createState() => _ShareCharacterDialogState();
}

class _ShareCharacterDialogState extends State<_ShareCharacterDialog> {
  ShareCode? _code;
  List<CharacterShare>? _shares;
  bool _generating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadShares();
  }

  Future<void> _loadShares() async {
    try {
      final shares = await widget.api.listCharacterShares(widget.characterId);
      if (mounted) setState(() => _shares = shares);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final code = await widget.api.shareCharacter(widget.characterId);
      if (mounted) setState(() => _code = code);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _stopSharing(CharacterShare share) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dejar de compartir'),
        content: Text(
          'El DM de «${share.campaignName}» deja de ver a '
          '${widget.characterName}. Tu ficha no se toca.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.link_off),
            label: const Text('Dejar de compartir'),
            style: FilledButton.styleFrom(
              backgroundColor: context.palette.crimson,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await widget.api.deleteCampaignLink(share.memberId);
      await _loadShares();
      if (mounted) {
        showAppMessage(context, 'Ya no se comparte con ${share.campaignName}.');
      }
    } on ApiException catch (e) {
      if (mounted) {
        showAppMessage(context, e.message, tone: AppMessageTone.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return AlertDialog(
      title: Text('Compartir a ${widget.characterName}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Generá un código y pasáselo a tu DM. Él lo pega en su campaña y '
              've tu ficha; nunca puede editarla.',
              style: TextStyle(fontSize: 13, color: pal.textMuted),
            ),
            const SizedBox(height: 16),
            if (_code case final code?)
              _codeBox(context, code)
            else
              FilledButton.icon(
                onPressed: _generating ? null : _generate,
                icon: const Icon(Icons.key),
                label: Text(_generating ? 'Generando…' : 'Generar código'),
              ),
            if (_error case final error?) ...[
              const SizedBox(height: 12),
              Text(error, style: TextStyle(fontSize: 12, color: pal.crimson)),
            ],
            const SizedBox(height: 24),
            const Eyebrow('Compartido con'),
            const SizedBox(height: 8),
            _sharesList(context),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Widget _codeBox(BuildContext context, ShareCode code) {
    final pal = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: pal.plaque,
            border: Border.all(color: pal.gold),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: SelectableText(
              code.code,
              key: const ValueKey('share-code'),
              style: TextStyle(
                // Grande y espaciado: está pensado para leerse en voz alta o
                // copiarse a mano de una pantalla a un teléfono.
                fontSize: 30,
                letterSpacing: 4,
                fontWeight: FontWeight.w600,
                color: pal.gold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'Sirve una sola vez y vence en 24 horas.',
                style: TextStyle(fontSize: 12, color: pal.textMuted),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code.code));
                if (context.mounted) {
                  showAppMessage(context, 'Código copiado.');
                }
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copiar'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sharesList(BuildContext context) {
    final pal = context.palette;
    final shares = _shares;
    if (shares == null) return const AppBusyLabel('Buscando…');
    if (shares.isEmpty) {
      return Text(
        'Todavía no lo compartiste con ninguna campaña.',
        style: TextStyle(fontSize: 13, color: pal.textMuted),
      );
    }
    return Column(
      children: [
        for (final share in shares)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(Icons.menu_book_outlined, color: pal.gold, size: 20),
            title: Text(share.campaignName),
            trailing: IconButton(
              tooltip: 'Dejar de compartir con ${share.campaignName}',
              onPressed: () => _stopSharing(share),
              icon: Icon(Icons.link_off, color: pal.crimson, size: 20),
            ),
          ),
      ],
    );
  }
}
