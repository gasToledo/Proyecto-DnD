import 'dart:io';

import 'package:flutter/material.dart';

import '../data/transfer_service.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dir = await widget.transfer.exportsDir();
    final files = await widget.transfer.listExportFiles();
    if (!mounted) return;
    setState(() {
      _dirPath = dir.path;
      _files = files;
    });
  }

  @override
  void dispose() {
    _pathCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Importar'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_dirPath != null)
              Text(
                'Archivos en $_dirPath',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: _files.isEmpty
                  ? const Center(child: Text('No hay archivos exportados aún.'))
                  : ListView(
                      children: _files
                          .map(
                            (f) => ListTile(
                              dense: true,
                              leading: Icon(
                                f.path.toLowerCase().endsWith('.zip')
                                    ? Icons.folder_zip
                                    : Icons.description,
                              ),
                              title: Text(f.uri.pathSegments.last),
                              onTap: () => Navigator.of(context).pop(f.path),
                            ),
                          )
                          .toList(),
                    ),
            ),
            const Divider(),
            TextField(
              controller: _pathCtrl,
              decoration: const InputDecoration(
                labelText: 'O pegá la ruta completa de un archivo',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final p = _pathCtrl.text.trim();
            if (p.isNotEmpty) Navigator.of(context).pop(p);
          },
          child: const Text('Importar ruta'),
        ),
      ],
    );
  }
}
