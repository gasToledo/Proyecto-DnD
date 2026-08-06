import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/api_models.dart';
import '../data/settings_service.dart';
import '../theme/app_widgets.dart';

/// Ajustes de la cuenta: qué proveedor de retratos usar por defecto. Las
/// claves de proveedor viven en la configuración del servidor (ver
/// `design.md`, decisión D9), así que esta pantalla ya no pide ni guarda
/// ninguna credencial — solo lista lo que `GET /api/portraits/providers`
/// ofrece.
class SettingsDialog extends StatefulWidget {
  final ApiClient api;

  const SettingsDialog({super.key, required this.api});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late final _settings = SettingsService(widget.api);

  List<PortraitProviderInfo> _providers = [];
  String? _providerId;

  /// Los ajustes tal como estaban al abrir el diálogo. Esta pantalla edita un
  /// solo campo, pero el documento tiene más (favorito y orden del roster):
  /// se guarda este objeto con el campo cambiado, nunca uno nuevo, o guardar
  /// los ajustes borraría lo que esta pantalla ni muestra.
  AppSettings? _loadedSettings;
  bool _loaded = false;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loaded = false;
      _loadError = null;
    });
    try {
      final settings = await _settings.load();
      final providers = await widget.api.listPortraitProviders();
      if (!mounted) return;
      setState(() {
        _providers = providers;
        _loadedSettings = settings;
        _providerId = providers.any((p) => p.id == settings.imageProvider)
            ? settings.imageProvider
            : providers.firstOrNull?.id;
        _loaded = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = '$error');
    }
  }

  Future<void> _save() async {
    if (_saving || _providerId == null) return;
    setState(() => _saving = true);
    try {
      final settings = _loadedSettings ?? AppSettings();
      settings.imageProvider = _providerId!;
      await _settings.save(settings);
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
    return AlertDialog(
      title: const Text('Ajustes · Generación de imágenes'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: (MediaQuery.sizeOf(context).width - 80).clamp(240, 480),
          maxHeight: MediaQuery.sizeOf(context).height * .65,
        ),
        child: !_loaded && _loadError == null
            ? const SizedBox(
                height: 80,
                child: Center(child: AppBusyLabel('Cargando ajustes…')),
              )
            : _loadError != null
            ? _errorContent()
            : _formContent(),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _loaded && !_saving && _providerId != null ? _save : null,
          child: _saving
              ? const AppBusyLabel('Guardando…', indicatorSize: 15)
              : const Text('Guardar'),
        ),
      ],
    );
  }

  Widget _errorContent() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'No se pudo cargar la configuración: $_loadError',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _load,
        icon: const Icon(Icons.refresh),
        label: const Text('Reintentar'),
      ),
    ],
  );

  Widget _formContent() {
    if (_providers.isEmpty) {
      return const Text(
        'Este servidor no tiene ningún proveedor de generación configurado. '
        'Igual podés subir tu propio retrato desde la ficha.',
      );
    }
    return SingleChildScrollView(
      child: FocusTraversalGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              onChanged: (v) => setState(() => _providerId = v ?? _providerId),
            ),
          ],
        ),
      ),
    );
  }
}
