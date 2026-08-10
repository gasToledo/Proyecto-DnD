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
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import '../theme/class_visuals.dart';
import 'portrait_image.dart';
import 'settings_dialog.dart';

/// Cómo se consigue el retrato. Antes los dos caminos convivían apilados en el
/// mismo formulario, con el de archivo arriba de todo y separado por una regla
/// del de generación; en pestañas cada uno se ve entero y ninguno estorba al
/// otro.
enum _PortraitMode { ia, upload }

/// Colores del muestrario de estilos. Son decorativos —el estilo viaja al
/// prompt como texto y nada más— pero distinguen una opción de otra de un
/// vistazo, que era imposible cuando eran ocho fichas de texto idénticas.
///
/// Se busca por nombre y no por posición para que reordenar [portraitStyles] no
/// mezcle los colores; un estilo sin entrada cae en [_fallbackSwatch].
const _styleSwatches = <String, (Color, Color)>{
  'Arte digital de fantasía': (Color(0xFF7A5CFF), Color(0xFF241A4A)),
  'Óleo clásico': (Color(0xFF8A5A2B), Color(0xFF2A1A0E)),
  'Ilustración de cómic': (Color(0xFFC2452F), Color(0xFF2A1010)),
  'Realista cinematográfico': (Color(0xFF4F6B78), Color(0xFF151D22)),
  'Acuarela': (Color(0xFF5F8FB0), Color(0xFF1C2C38)),
  'Pixel art': (Color(0xFF3F9D6A), Color(0xFF12291D)),
  'Boceto a lápiz': (Color(0xFF6E6A63), Color(0xFF1A1917)),
};
const _fallbackSwatch = (Color(0xFFA08A5E), Color(0xFF2D2618));

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

  _PortraitMode _mode = _PortraitMode.ia;

  String _style = portraitStyles.first;
  bool _customStyle = false;

  Uint8List? _referenceBytes;
  String? _referenceName;

  bool _generating = false;
  bool _importing = false;
  bool _saving = false;
  String? _error;
  List<Uint8List> _results = [];

  /// Cuál de los resultados se está viendo grande. Antes se guardaba tocando
  /// una miniatura de 200px, o sea comprometiendo el retrato del personaje sin
  /// haberlo visto en serio.
  int? _preview;

  static const _importExtensions = ['png', 'jpg', 'jpeg', 'webp'];

  PortraitProviderInfo? get _provider =>
      _providers.where((p) => p.id == _providerId).firstOrNull;

  bool get _busy => _generating || _importing || _saving;

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
        // Sin proveedores no hay nada que generar: la única vía es el archivo,
        // así que se abre ahí en vez de mostrar una pestaña vacía.
        if (providers.isEmpty) _mode = _PortraitMode.upload;
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

  /// El prompt sin lo que escribió el jugador, para poder pintar su aporte
  /// aparte y que se vea qué suma él y qué sale solo de la ficha.
  String get _basePrompt => buildPortraitPrompt(
    character: widget.character,
    repo: widget.repo,
    style: _effectiveStyle,
    extraText: '',
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
      _preview = null;
    });
    try {
      final images = await widget.api.generatePortraits(
        providerId: provider.id,
        prompt: _prompt,
        reference: provider.supportsReference ? _referenceBytes : null,
      );
      if (!mounted) return;
      setState(() {
        _results = images;
        // La primera queda vista de entrada: si solo vino una, usarla sigue
        // siendo un toque, como cuando las miniaturas se guardaban al tocarlas.
        _preview = images.isEmpty ? null : 0;
      });
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
    setState(() => _saving = true);
    final String key;
    try {
      key = await widget.api.savePortrait(
        characterId: widget.character.id,
        bytes: bytes,
      );
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      _fail('No se pudo guardar el retrato: $e');
      return;
    }
    final updated = widget.character.copyWith(
      portraitPaths: [key, ...widget.character.portraitPaths],
    );
    widget.onUpdated(updated);
    if (!mounted) return;
    setState(() => _saving = false);
    showAppMessage(context, 'Retrato guardado.', tone: AppMessageTone.success);
    Navigator.of(context).pop();
  }

  // ------------------------------------------------------------------ build

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
          : _workshop(),
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

  /// Lienzo a la izquierda, controles a la derecha; apilado cuando no entra.
  ///
  /// El corte en 760 es donde el lienzo de 320 y los controles dejan de
  /// convivir sin que las tarjetas de proveedor queden de una columna.
  Widget _workshop() => LayoutBuilder(
    builder: (context, box) {
      final wide = box.maxWidth >= 760;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 320, child: _canvasColumn()),
                  const SizedBox(width: 24),
                  Expanded(child: _controlsColumn()),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _canvasColumn(),
                  const SizedBox(height: 22),
                  _controlsColumn(),
                ],
              ),
      );
    },
  );

  // ----------------------------------------------------------- el lienzo

  Widget _canvasColumn() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _hero(),
          if (_results.length > 1) ...[
            const SizedBox(height: 12),
            _resultsStrip(),
          ],
          if (_preview != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : () => _use(_results[_preview!]),
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_saving ? 'Guardando…' : 'Usar este retrato'),
            ),
          ],
          if (_mode == _PortraitMode.ia) ...[
            const SizedBox(height: 14),
            _promptPanel(),
          ],
        ],
      ),
    ),
  );

  /// Retrato grande 3:4 con marco heráldico. Muestra, por orden: el resultado
  /// que se está mirando, el retrato que ya tiene el personaje, o el emblema de
  /// su clase.
  Widget _hero() {
    final pal = context.palette;
    final c = widget.character;
    final klass = widget.repo.characterClass(c.classId);
    final accent = classAccent(klass, pal.gold);
    final race = widget.repo.race(c.raceId)?.name ?? c.raceId;
    final background = widget.repo.background(c.backgroundId)?.name;
    final existing = c.portraitPaths.firstOrNull;
    final previewed = _preview;

    final Widget layer;
    if (previewed != null && previewed < _results.length) {
      layer = Image.memory(_results[previewed], fit: BoxFit.cover);
    } else if (existing != null) {
      layer = PortraitImage(portraitKey: existing);
    } else {
      layer = DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent, Color.lerp(accent, Colors.black, .78)!],
          ),
        ),
        child: Center(
          child: Icon(
            classIcon(klass),
            size: 96,
            color: Colors.white.withValues(alpha: .92),
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: pal.hairline),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              layer,
              // Oscurecido de abajo para que el nombre se lea sobre cualquier
              // imagen, que es lo que no se puede garantizar de antemano.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0x9E000000), Color(0x00000000)],
                    stops: [0, .52],
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              ..._corners(pal.gold),
              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      c.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 21,
                        color: Colors.white,
                        shadows: [
                          Shadow(blurRadius: 10, color: Color(0x99000000)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        race,
                        klass?.name ?? c.classId,
                        ?background,
                      ].join(' · ').toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        letterSpacing: 1.3,
                        color: Colors.white70,
                        shadows: [
                          Shadow(blurRadius: 8, color: Color(0x99000000)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_generating)
                ColoredBox(
                  color: const Color(0xA60A0806),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox.square(
                          dimension: 34,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: pal.gold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'INVOCANDO',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.6,
                            color: pal.gold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Las cuatro escuadras doradas del marco. Van sin esquina redondeada porque
  /// `BoxDecoration` no admite radio con un borde de lados desiguales.
  List<Widget> _corners(Color gold) {
    const size = 20.0;
    Widget corner({required bool top, required bool left}) => Positioned(
      top: top ? 9 : null,
      bottom: top ? null : 9,
      left: left ? 9 : null,
      right: left ? null : 9,
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: top ? BorderSide(color: gold, width: 2) : BorderSide.none,
              bottom: top ? BorderSide.none : BorderSide(color: gold, width: 2),
              left: left ? BorderSide(color: gold, width: 2) : BorderSide.none,
              right: left ? BorderSide.none : BorderSide(color: gold, width: 2),
            ),
          ),
        ),
      ),
    );

    return [
      corner(top: true, left: true),
      corner(top: true, left: false),
      corner(top: false, left: true),
      corner(top: false, left: false),
    ];
  }

  Widget _resultsStrip() {
    final pal = context.palette;
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _results.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final on = _preview == i;
          return InkWell(
            onTap: () => setState(() => _preview = i),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 57,
              decoration: BoxDecoration(
                border: Border.all(
                  color: on ? pal.gold : pal.hairline,
                  width: on ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.memory(_results[i], fit: BoxFit.cover),
            ),
          );
        },
      ),
    );
  }

  /// La descripción que sale sola de la ficha, con lo que escribió el jugador
  /// en dorado. Antes era un `Card` con el prompt entero en un solo color: no
  /// se distinguía qué había puesto uno y qué venía del personaje.
  Widget _promptPanel() {
    final pal = context.palette;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final base = _basePrompt;
    final full = _prompt;
    final extra = full.startsWith(base) ? full.substring(base.length) : '';

    return Container(
      decoration: BoxDecoration(
        color: pal.plaque,
        border: Border.all(color: pal.hairline),
        borderRadius: BorderRadius.circular(11),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: pal.gold),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 12, 14, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 15,
                          color: pal.gold,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'DESCRIPCIÓN BASE · AUTOMÁTICA',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.1,
                              color: pal.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: base),
                          if (extra.isNotEmpty)
                            TextSpan(
                              text: extra,
                              style: TextStyle(color: pal.gold),
                            ),
                        ],
                      ),
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.5,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------- los controles

  Widget _controlsColumn() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Align(alignment: Alignment.centerLeft, child: _modeTabs()),
      if (_mode == _PortraitMode.ia) ..._iaControls() else ..._uploadControls(),
      if (_error != null) ...[
        const SizedBox(height: 14),
        Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: ListTile(
            leading: const Icon(Icons.error_outline),
            title: Text(_error!),
          ),
        ),
      ],
    ],
  );

  Widget _modeTabs() {
    final pal = context.palette;
    Widget tab(_PortraitMode mode, IconData icon, String label) {
      final on = _mode == mode;
      return InkWell(
        onTap: () => setState(() => _mode = mode),
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: on ? pal.gold : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: on
                    ? Theme.of(context).colorScheme.onPrimary
                    : pal.textMuted,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: on
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: pal.plaque,
        border: Border.all(color: pal.hairline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_providers.isNotEmpty)
            tab(_PortraitMode.ia, Icons.auto_awesome, 'Generar con IA'),
          tab(_PortraitMode.upload, Icons.upload, 'Subir imagen'),
        ],
      ),
    );
  }

  List<Widget> _iaControls() {
    final provider = _provider;
    if (provider == null) {
      return [
        const SizedBox(height: 20),
        Text(
          'Este servidor no tiene ningún proveedor de generación configurado. '
          'Todavía podés subir tu propio retrato.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ];
    }
    return [
      const SizedBox(height: 20),
      _sectionHeader(
        'Motor de generación',
        trailing: TextButton.icon(
          onPressed: _openSettings,
          icon: const Icon(Icons.tune, size: 15),
          label: const Text('Ajustes'),
        ),
      ),
      const SizedBox(height: 10),
      _providerGrid(),
      const SizedBox(height: 20),
      _sectionHeader('Estilo'),
      const SizedBox(height: 10),
      _styleSelector(),
      if (_customStyle) ...[
        const SizedBox(height: 10),
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
        minLines: 3,
        maxLines: 6,
        decoration: InputDecoration(
          hintText: 'Sumá detalles: color de pelo, cicatrices, actitud…',
          filled: true,
          fillColor: context.palette.plaque,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.palette.hairline),
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
      if (provider.supportsReference) ...[
        const SizedBox(height: 16),
        _sectionHeader('Imagen de referencia · opcional'),
        const SizedBox(height: 10),
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
      const SizedBox(height: 18),
      SizedBox(
        height: 48,
        child: FilledButton.icon(
          onPressed: _busy ? null : _generate,
          icon: _generating
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(
            _generating
                ? 'Generando…'
                : _results.isEmpty
                ? 'Generar'
                : 'Generar otra vez',
          ),
        ),
      ),
      if (_providerId == 'pollinations')
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            'El servicio gratuito puede tardar hasta ~1 min y genera 2 '
            'variantes de a una. Si aparece un error de límite (429), '
            'esperá unos segundos y reintentá.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
    ];
  }

  List<Widget> _uploadControls() {
    final pal = context.palette;
    return [
      const SizedBox(height: 20),
      InkWell(
        onTap: _importing ? null : _importFromFile,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 210),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: pal.plaque,
            border: Border.all(color: pal.hairline),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_importing)
                const AppBusyLabel('Importando…')
              else ...[
                Icon(Icons.upload_file, size: 38, color: pal.gold),
                const SizedBox(height: 10),
                Text(
                  'Importar imagen desde archivo',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Tocá para elegirla. PNG, JPG o WEBP.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'La imagen pasa a ser el retrato del personaje. Podés volver a '
        'generar con IA cuando quieras.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ];
  }

  Widget _sectionHeader(String label, {Widget? trailing}) => Row(
    children: [
      Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          letterSpacing: 1.1,
          color: context.palette.textMuted,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(child: Divider(color: context.palette.hairline)),
      ?trailing,
    ],
  );

  Widget _providerGrid() => LayoutBuilder(
    builder: (context, box) {
      final columns = box.maxWidth >= 480
          ? 3
          : box.maxWidth >= 300
          ? 2
          : 1;
      final n = columns.clamp(1, _providers.length);
      final width = (box.maxWidth - 8 * (n - 1)) / n;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final p in _providers)
            SizedBox(width: width, child: _providerCard(p)),
        ],
      );
    },
  );

  Widget _providerCard(PortraitProviderInfo p) {
    final pal = context.palette;
    final on = p.id == _providerId;
    return InkWell(
      onTap: () => setState(() => _providerId = p.id),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          color: on ? pal.goldSoft : pal.plaque,
          border: Border.all(
            color: on ? pal.gold : pal.hairline,
            width: on ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  on
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 16,
                  color: on ? pal.gold : pal.textMuted,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    p.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              // Lo único que el servidor dice de cada proveedor además del
              // nombre. Inventar una etiqueta de precio sería adivinar.
              p.supportsReference ? 'Acepta referencia' : 'Solo texto',
              style: TextStyle(fontSize: 10.5, color: pal.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _styleSelector() {
    final pal = context.palette;
    final custom = portraitStyles.length;

    Widget swatch(String label, double size) {
      final (a, b) = _styleSwatches[label] ?? _fallbackSwatch;
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [a, b],
          ),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white24),
        ),
      );
    }

    return PopupMenuButton<int>(
      tooltip: 'Elegir estilo',
      position: PopupMenuPosition.under,
      onSelected: (i) => setState(() {
        if (i == custom) {
          _customStyle = true;
        } else {
          _customStyle = false;
          _style = portraitStyles[i];
        }
      }),
      itemBuilder: (_) => [
        for (var i = 0; i < portraitStyles.length; i++)
          _styleItem(
            i,
            portraitStyles[i],
            !_customStyle && _style == portraitStyles[i],
            swatch,
          ),
        _styleItem(custom, 'Personalizado', _customStyle, swatch),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: pal.plaque,
          border: Border.all(color: pal.hairline),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          children: [
            swatch(_customStyle ? 'Personalizado' : _style, 15),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _customStyle ? 'Personalizado' : _style,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.expand_more, size: 19, color: pal.textMuted),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<int> _styleItem(
    int value,
    String label,
    bool selected,
    Widget Function(String, double) swatch,
  ) => PopupMenuItem<int>(
    value: value,
    child: Row(
      children: [
        swatch(label, 13),
        const SizedBox(width: 9),
        Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
        if (selected) Icon(Icons.check, size: 15, color: context.palette.gold),
      ],
    ),
  );
}
