import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../ai/gemini_image_service.dart' show savePortrait;
import '../ai/portrait_prompt.dart';
import '../ai/portrait_provider.dart';
import '../data/app_paths.dart';
import '../data/settings_service.dart';
import 'settings_dialog.dart';

/// Generador de retratos por IA (brief §3.B) con proveedor enchufable. Auto-
/// completa datos de la ficha, permite estilo + texto libre + referencia
/// (si el proveedor la admite), y guarda la elegida localmente.
class PortraitScreen extends StatefulWidget {
  final Character character;
  final ContentRepository repo;
  final void Function(Character updated) onUpdated;
  const PortraitScreen({
    super.key,
    required this.character,
    required this.repo,
    required this.onUpdated,
  });

  @override
  State<PortraitScreen> createState() => _PortraitScreenState();
}

class _PortraitScreenState extends State<PortraitScreen> {
  final _settings = SettingsService();
  final _extraCtrl = TextEditingController();
  final _customStyleCtrl = TextEditingController();
  final _refCtrl = TextEditingController();

  String _providerId = 'pollinations';
  String _apiKey = '';
  bool _loading = true;

  String _style = portraitStyles.first;
  bool _customStyle = false;

  bool _generating = false;
  String? _error;
  List<Uint8List> _results = [];

  PortraitProvider _provider = PollinationsProvider();
  bool get _needsKey => _provider.keyHint != null && _apiKey.isEmpty;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final s = await _settings.load();
    if (!mounted) return;
    setState(() {
      _providerId = s.imageProvider;
      _apiKey = s.keyFor(s.imageProvider);
      _provider = switch (s.imageProvider) {
        'huggingface' => HuggingFaceProvider(model: s.huggingFaceModel),
        'gemini' => GeminiProvider(),
        _ => PollinationsProvider(),
      };
      _loading = false;
    });
  }

  @override
  void dispose() {
    _extraCtrl.dispose();
    _customStyleCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  String get _effectiveStyle => _customStyle ? _customStyleCtrl.text : _style;

  String get _prompt => buildPortraitPrompt(
        character: widget.character,
        repo: widget.repo,
        style: _effectiveStyle,
        extraText: _extraCtrl.text,
      );

  Future<void> _openSettings() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => const SettingsDialog(),
    );
    if (saved == true) await _loadSettings();
  }

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _error = null;
      _results = [];
    });
    final provider = _provider;
    try {
      Uint8List? reference;
      final refPath = _refCtrl.text.trim();
      if (provider.supportsReference && refPath.isNotEmpty) {
        final f = File(refPath);
        if (await f.exists()) reference = await f.readAsBytes();
      }
      final images = await provider.generate(
        prompt: _prompt,
        apiKey: _apiKey,
        reference: reference,
      );
      if (!mounted) return;
      setState(() => _results = images);
    } on SocketException {
      _fail('Sin conexión a internet. La generación de imágenes requiere red.');
    } on TimeoutException {
      _fail('La generación tardó demasiado. Probá de nuevo en unos segundos.');
    } catch (e) {
      _fail('No se pudo generar: $e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _fail(String msg) {
    if (mounted) setState(() => _error = msg);
  }

  Future<void> _use(Uint8List bytes) async {
    final path = await savePortrait(
      portraitsRoot: fichasDir('portraits'),
      characterId: widget.character.id,
      bytes: bytes,
    );
    final updated = widget.character.copyWith(
      portraitPaths: [path, ...widget.character.portraitPaths],
    );
    widget.onUpdated(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Retrato guardado.')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generar retrato'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Ajustes de IA',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _needsKey
              ? _noKey()
              : _form(),
    );
  }

  Widget _noKey() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.key_off, size: 48),
              const SizedBox(height: 12),
              Text(
                'El proveedor "${_provider.name}" requiere una key. '
                'Configurala en Ajustes, o elegí Pollinations (gratis, sin key).',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _openSettings,
                icon: const Icon(Icons.settings),
                label: const Text('Abrir Ajustes'),
              ),
            ],
          ),
        ),
      );

  Widget _form() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Proveedor: ${_provider.name}',
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
            TextButton(onPressed: _openSettings, child: const Text('Cambiar')),
          ],
        ),
        const Divider(),
        Text('Estilo', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...portraitStyles.map((s) => ChoiceChip(
                  label: Text(s),
                  selected: !_customStyle && _style == s,
                  onSelected: (_) => setState(() {
                    _customStyle = false;
                    _style = s;
                  }),
                )),
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
        if (_provider.supportsReference) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _refCtrl,
            decoration: const InputDecoration(
              labelText: 'Ruta de imagen de referencia (opcional)',
              hintText: r'C:\...\referencia.png',
              border: OutlineInputBorder(),
            ),
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
                  child: CircularProgressIndicator(strokeWidth: 2))
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
          Text('Resultados (tocá para usar)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _results
                .map((bytes) => InkWell(
                      onTap: () => _use(bytes),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(bytes,
                            width: 200, height: 200, fit: BoxFit.cover),
                      ),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}
