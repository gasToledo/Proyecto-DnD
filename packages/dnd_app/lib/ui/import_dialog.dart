import 'dart:io';

import 'package:flutter/material.dart';

import '../data/transfer_service.dart';
import '../theme/app_widgets.dart';

/// Diálogo de importación sin selector nativo: lista respaldos ZIP y JSON
/// antiguos, y permite pegar una ruta arbitraria. Devuelve la ruta elegida.
class ImportDialog extends StatefulWidget {
  final TransferService transfer;
  const ImportDialog({super.key, required this.transfer});

  @override
  State<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<ImportDialog> {
  final _pathCtrl = TextEditingController();
  List<File> _files = [];
  String? _dirPath;
  bool _loading = true;
  Object? _loadError;

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
      final dir = await widget.transfer.exportsDir();
      final files = await widget.transfer.listExportFiles();
      if (!mounted) return;
      setState(() {
        _dirPath = dir.path;
        _files = files;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _pathCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableHeight = (MediaQuery.sizeOf(context).height - 190).clamp(
      250.0,
      420.0,
    );
    return AlertDialog(
      title: const Text('Importar'),
      content: SizedBox(
        width: 480,
        height: availableHeight,
        child: FocusTraversalGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_dirPath != null)
                Text(
                  'Archivos en $_dirPath',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 8),
              Expanded(child: _fileList()),
              const Divider(),
              TextField(
                controller: _pathCtrl,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submitPath(),
                decoration: const InputDecoration(
                  labelText: 'O pegá la ruta completa de un archivo',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submitPath,
          child: const Text('Importar ruta'),
        ),
      ],
    );
  }

  Widget _fileList() {
    if (_loading) {
      return const Center(child: AppBusyLabel('Buscando respaldos…'));
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline),
            const SizedBox(height: 8),
            Text(
              'No se pudo leer la carpeta de exportación:\n$_loadError',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    if (_files.isEmpty) {
      return const Center(child: Text('No hay archivos exportados aún.'));
    }
    return ListView(
      children: _files
          .map(
            (file) => Semantics(
              button: true,
              label: 'Importar ${file.uri.pathSegments.last}',
              child: ListTile(
                dense: true,
                leading: Icon(
                  file.path.toLowerCase().endsWith('.zip')
                      ? Icons.folder_zip
                      : Icons.description,
                ),
                title: Text(
                  file.uri.pathSegments.last,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.of(context).pop(file.path),
              ),
            ),
          )
          .toList(),
    );
  }

  void _submitPath() {
    final path = _pathCtrl.text.trim();
    if (path.isEmpty) {
      showAppMessage(context, 'Ingresá una ruta para importar.');
      return;
    }
    Navigator.of(context).pop(path);
  }
}
