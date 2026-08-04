import 'dart:async';
import 'dart:typed_data';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../ai/portrait_prompt.dart';
import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../api/api_models.dart';
import '../data/settings_service.dart';
import '../theme/app_widgets.dart';
import 'settings_dialog.dart';

/// Generador de retratos por IA con proveedor enchufable. Auto-completa datos
/// de la ficha, permite estilo + texto libre + referencia (si el proveedor la
/// admite), y guarda la elegida. La generación y las claves de proveedor
/// viven en el servidor (ver `design.md`, decisión D9): este cliente nunca ve
/// una key, solo la lista de proveedores ya configurados.
class PortraitScreen extends StatefulWidget {
  final Character character;
  final ContentRepository repo;
  final ApiClient api;
  final void Function(Character updated) onUpdated;
  const PortraitScreen({
    super.key,
    required this.character,
    required this.repo,
    required this.api,
    required this.onUpdated,
  });

  @override
  State<PortraitScreen> createState() => _PortraitScreenState();
}

class _PortraitScreenState extends State<PortraitScreen> {
  final _extraCtrl = TextEditingController();
  final _customStyleCtrl = TextEditingController();

  List<PortraitProviderInfo> _providers = [];
  String? _providerId;
  bool _loading = true;
  String? _loadError;

  String _style = portraitStyles.first;
  bool _customStyle = false;

  Uint8List? _referenceBytes;
  String? _referenceName;

  bool _generating = false;
  bool _importing = false;
  String? _error;
  List<Uint8List> _results = [];

  static const _importExtensions = ['png', 'jpg', 'jpeg', 'webp'];

  PortraitProviderInfo? get _provider =>
      _providers.where((p) => p.id == _providerId).firstOrNull;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final settings = await SettingsService(widget.api).load();
      final providers = await widget.api.listPortraitProviders();
      if (!mounted) return;
      setState(() {
        _providers = providers;
        _providerId = providers.any((p) => p.id == settings.imageProvider)
            ? settings.imageProvider
            : providers.firstOrNull?.id;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = '$e';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _extraCtrl.dispose();
    _customStyleCtrl.dispose();
    super.dispose();
  }

  String get _effectiveStyle => _customStyle ? _customStyleCtrl.text : _style;

  String get _prompt => buildPortraitPrompt(
    character: widget.character,
    repo: widget.repo,
    style: _effectiveStyle,
    extraText: _extraCtrl.text,
    // El filtro de contenido de Azure rechaza retratos con arma explícita.
    includeWeapon: _providerId != 'azure',
  );

  Future<void> _openSettings() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => SettingsDialog(api: widget.api),
    );
    if (saved == true) await _load();
  }

  Future<void> _generate() async {
    final provider = _provider;
    if (provider == null) return;
    setState(() {
      _generating = true;
      _error = null;
      _results = [];
    });
    try {
      final images = await widget.api.generatePortraits(
        providerId: provider.id,
        prompt: _prompt,
        reference: provider.supportsReference ? _referenceBytes : null,
      );
      if (!mounted) return;
      setState(() => _results = images);
    } on ApiException catch (e) {
      _fail(
        e.isOffline
            ? 'Sin conexión con el servidor. La generación requiere red.'
            : 'No se pudo generar: ${e.message}',
      );
    } catch (e) {
      _fail('No se pudo generar: $e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _fail(String msg) {
    if (mounted) setState(() => _error = msg);
  }

  Future<void> _pickReference() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _importExtensions,
        withData: true,
        dialogTitle: 'Elegir imagen de referencia',
      );
      final file = result?.files.singleOrNull;
      if (file?.bytes == null) return; // el usuario canceló el diálogo
      setState(() {
        _referenceBytes = file!.bytes;
        _referenceName = file.name;
      });
    } catch (e) {
      _fail('No se pudo elegir la imagen de referencia: $e');
    }
  }

  /// Importa un retrato ya existente desde un archivo, en vez de generarlo.
  /// Reusa [_use], el mismo camino de guardado que un resultado de IA.
  /// Disponible aunque no haya proveedores de IA configurados.
  Future<void> _importFromFile() async {
    setState(() {
      _importing = true;
      _error = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _importExtensions,
        withData: true,
        dialogTitle: 'Elegir imagen de retrato',
      );
      final bytes = result?.files.singleOrNull?.bytes;
      if (bytes == null) return; // el usuario canceló el diálogo
      await _use(bytes);
    } catch (e) {
      _fail('No se pudo importar la imagen: $e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _use(Uint8List bytes) async {
    final String key;
    try {
      key = await widget.api.savePortrait(
        characterId: widget.character.id,
        bytes: bytes,
      );
    } catch (e) {
      _fail('No se pudo guardar el retrato: $e');
      return;
    }
    final updated = widget.character.copyWith(
      portraitPaths: [key, ...widget.character.portraitPaths],
    );
    widget.onUpdated(updated);
    if (!mounted) return;
    showAppMessage(context, 'Retrato guardado.', tone: AppMessageTone.success);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Retrato'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Ajustes de IA',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: AppBusyLabel('Cargando configuración…'))
          : _loadError != null
          ? _loadFailed()
          : _form(),
    );
  }

  Widget _loadFailed() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 48),
          const SizedBox(height: 12),
          Text(_loadError!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  );

  Widget _noProviders() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_outlined, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Este servidor no tiene ningún proveedor de generación '
            'configurado. Todavía podés subir tu propio retrato.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _importing ? null : _importFromFile,
            icon: _importing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file),
            label: Text(
              _importing ? 'Importando…' : 'Importar imagen desde archivo',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _form() {
    final provider = _provider;
    if (provider == null) return _noProviders();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Proveedor: ${provider.name}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (_providers.length > 1)
              DropdownButton<String>(
                value: _providerId,
                items: [
                  for (final p in _providers)
                    DropdownMenuItem(value: p.id, child: Text(p.name)),
                ],
                onChanged: (id) => setState(() => _providerId = id),
              ),
            TextButton(onPressed: _openSettings, child: const Text('Ajustes')),
          ],
        ),
        OutlinedButton.icon(
          onPressed: _importing ? null : _importFromFile,
          icon: _importing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_file),
          label: Text(
            _importing ? 'Importando…' : 'Importar imagen desde archivo',
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('o generá uno nuevo'),
              ),
              Expanded(child: Divider()),
            ],
          ),
        ),
        Text('Estilo', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...portraitStyles.map(
              (s) => ChoiceChip(
                label: Text(s),
                selected: !_customStyle && _style == s,
                onSelected: (_) => setState(() {
                  _customStyle = false;
                  _style = s;
                }),
              ),
            ),
            ChoiceChip(
              label: const Text('Personalizado'),
              selected: _customStyle,
              onSelected: (_) => setState(() => _customStyle = true),
            ),
          ],
        ),
        if (_customStyle) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _customStyleCtrl,
            decoration: const InputDecoration(
              labelText: 'Estilo personalizado',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _extraCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Detalles adicionales (opcional)',
            hintText: 'p.ej. pelo rojo largo, cicatriz en la ceja',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (provider.supportsReference) ...[
          const SizedBox(height: 12),
          Text(
            'Imagen de referencia (opcional)',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickReference,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(
                    _referenceName ?? 'Elegir imagen…',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (_referenceBytes != null)
                IconButton(
                  tooltip: 'Quitar referencia',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    _referenceBytes = null;
                    _referenceName = null;
                  }),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Prompt', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(_prompt),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _generating ? null : _generate,
          icon: _generating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(_generating ? 'Generando…' : 'Generar'),
        ),
        if (_providerId == 'pollinations')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'El servicio gratuito puede tardar hasta ~1 min y genera 2 '
              'variantes de a una. Si aparece un error de límite (429), '
              'esperá unos segundos y reintentá.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              leading: const Icon(Icons.error_outline),
              title: Text(_error!),
            ),
          ),
        ],
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Resultados (tocá para usar)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _results
                .map(
                  (bytes) => InkWell(
                    onTap: () => _use(bytes),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        bytes,
                        width: 200,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}
