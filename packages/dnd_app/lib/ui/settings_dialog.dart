import 'package:flutter/material.dart';

import '../ai/portrait_provider.dart';
import '../data/settings_service.dart';
import '../theme/app_widgets.dart';

/// Ajustes: elegir proveedor de imágenes y, si corresponde, su API key/token.
/// Todo se guarda solo en el equipo del usuario.
class SettingsDialog extends StatefulWidget {
  final SettingsService? service;

  const SettingsDialog({super.key, this.service});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late final SettingsService _service = widget.service ?? SettingsService();
  final _geminiCtrl = TextEditingController();
  final _hfCtrl = TextEditingController();
  final _hfModelCtrl = TextEditingController();

  final _providers = buildProviders();
  String _providerId = 'pollinations';
  bool _obscure = true;
  bool _loaded = false;
  bool _saving = false;
  String? _recoveredSettingsPath;

  @override
  void initState() {
    super.initState();
    _service.load().then((s) {
      if (!mounted) return;
      setState(() {
        _providerId = s.imageProvider;
        _geminiCtrl.text = s.geminiApiKey;
        _hfCtrl.text = s.huggingFaceToken;
        _hfModelCtrl.text = s.huggingFaceModel;
        _loaded = true;
        _recoveredSettingsPath =
            _service.recoveryIssues.firstOrNull?.recoveryPath;
      });
    });
  }

  @override
  void dispose() {
    _geminiCtrl.dispose();
    _hfCtrl.dispose();
    _hfModelCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final model = _hfModelCtrl.text.trim();
    try {
      await _service.save(
        AppSettings(
          imageProvider: _providerId,
          geminiApiKey: _geminiCtrl.text.trim(),
          huggingFaceToken: _hfCtrl.text.trim(),
          huggingFaceModel: model.isEmpty ? defaultHuggingFaceModel : model,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      showAppMessage(
        context,
        'No se pudieron guardar los ajustes: $error',
        tone: AppMessageTone.error,
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = providerById(_providerId);
    return AlertDialog(
      title: const Text('Ajustes · Generación de imágenes'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: (MediaQuery.sizeOf(context).width - 80).clamp(240, 480),
          maxHeight: MediaQuery.sizeOf(context).height * .65,
        ),
        child: !_loaded
            ? const SizedBox(
                height: 80,
                child: Center(child: AppBusyLabel('Cargando ajustes…')),
              )
            : SingleChildScrollView(
                child: FocusTraversalGroup(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_recoveredSettingsPath != null) ...[
                        Text(
                          'El archivo de ajustes era ilegible y fue apartado en:\n'
                          '$_recoveredSettingsPath',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      const Text('Proveedor de retratos:'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _providerId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: _providers
                            .map(
                              (p) => DropdownMenuItem(
                                value: p.id,
                                child: Text(
                                  p.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _providerId = v ?? _providerId),
                      ),
                      const SizedBox(height: 16),
                      if (provider.keyHint == null)
                        const Text(
                          'Este proveedor no requiere API key. '
                          '¡Podés generar retratos directamente!',
                        )
                      else
                        _keyField(provider),
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _loaded && !_saving ? _save : null,
          child: _saving
              ? const AppBusyLabel('Guardando…', indicatorSize: 15)
              : const Text('Guardar'),
        ),
      ],
    );
  }

  Widget _keyField(PortraitProvider provider) {
    final ctrl = provider.id == 'gemini' ? _geminiCtrl : _hfCtrl;
    final url = provider.id == 'gemini'
        ? 'aistudio.google.com/apikey'
        : 'huggingface.co/settings/tokens';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Conseguila gratis en: $url'),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          obscureText: _obscure,
          decoration: InputDecoration(
            labelText: provider.keyHint,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: _obscure ? 'Mostrar credencial' : 'Ocultar credencial',
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          textInputAction: provider.id == 'huggingface'
              ? TextInputAction.next
              : TextInputAction.done,
          onSubmitted: provider.id == 'huggingface' ? null : (_) => _save(),
        ),
        if (provider.id == 'huggingface') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _hfModelCtrl,
            decoration: const InputDecoration(
              labelText: 'Modelo de Hugging Face',
              helperText: 'El catálogo gratuito cambia; podés probar otro id.',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
        ],
      ],
    );
  }
}
