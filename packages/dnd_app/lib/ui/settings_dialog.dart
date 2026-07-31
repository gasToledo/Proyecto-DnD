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
  final _azureCtrl = TextEditingController();
  final _azureOpenAiCtrl = TextEditingController();

  final _providers = buildProviders();
  String _providerId = 'pollinations';
  bool _obscure = true;
  bool _loaded = false;
  bool _saving = false;
  String? _settingsLoadWarning;

  @override
  void initState() {
    super.initState();
    _service.load().then((s) {
      if (!mounted) return;
      setState(() {
        _providerId = s.imageProvider;
        _azureCtrl.text = s.azureApiKey;
        _azureOpenAiCtrl.text = s.azureOpenAiApiKey;
        _loaded = true;
        final issue = _service.recoveryIssues.firstOrNull;
        _settingsLoadWarning = issue == null
            ? null
            : issue.wasMoved
            ? 'El archivo de ajustes era ilegible y fue apartado en:\n'
                  '${issue.recoveryPath}'
            : '${issue.error}\nEl archivo se conservó sin modificaciones en:\n'
                  '${issue.originalPath}';
      });
    });
  }

  @override
  void dispose() {
    _azureCtrl.dispose();
    _azureOpenAiCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _service.save(
        AppSettings(
          imageProvider: _providerId,
          azureApiKey: _azureCtrl.text.trim(),
          azureOpenAiApiKey: _azureOpenAiCtrl.text.trim(),
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
                      if (_settingsLoadWarning != null) ...[
                        Text(
                          _settingsLoadWarning!,
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
    // Los dos proveedores de Azure son recursos distintos, cada uno con su
    // propia key: comparten pantalla pero no credencial.
    final ctrl = switch (provider.id) {
      'azure-gpt-image' => _azureOpenAiCtrl,
      _ => _azureCtrl,
    };
    final hint = switch (provider.id) {
      'azure-gpt-image' =>
        'La generás en el recurso de Azure que sirve gpt-image-2 '
            '(Keys and Endpoint).',
      _ =>
        'La generás en tu recurso de Azure AI Foundry (Keys and '
            'Endpoint).',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(hint),
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
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
        ),
        if (provider.supportsReference) ...[
          const SizedBox(height: 8),
          Text(
            'Este proveedor acepta una imagen de referencia al generar.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
