import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

import 'app_paths.dart';

class AppUpdate {
  final String version;
  final String title;
  final String notes;
  final String assetName;
  final Uri downloadUrl;

  const AppUpdate({
    required this.version,
    required this.title,
    required this.notes,
    required this.assetName,
    required this.downloadUrl,
  });
}

/// Consulta el último Release estable y descarga su ZIP para Windows.
class UpdateService {
  static final latestReleaseUri = Uri.parse(
    'https://api.github.com/repos/gasToledo/Proyecto-DnD/releases/latest',
  );

  final String currentVersion;
  final http.Client _client;

  UpdateService({required this.currentVersion, http.Client? client})
    : _client = client ?? http.Client();

  static Future<UpdateService> forCurrentPlatform() async {
    final package = await PackageInfo.fromPlatform();
    return UpdateService(currentVersion: package.version);
  }

  Future<AppUpdate?> checkForUpdate() async {
    final response = await _client
        .get(
          latestReleaseUri,
          headers: const {
            'Accept': 'application/vnd.github+json',
            'User-Agent': 'FichasDnD-update-check',
          },
        )
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'GitHub respondió ${response.statusCode}.',
        uri: latestReleaseUri,
      );
    }

    final json = (jsonDecode(response.body) as Map).cast<String, dynamic>();
    final tag = json['tag_name'] as String?;
    if (tag == null || !_isNewer(tag, currentVersion)) return null;

    Map<String, dynamic>? windowsAsset;
    for (final value in json['assets'] as List? ?? const []) {
      final asset = (value as Map).cast<String, dynamic>();
      final name = asset['name'] as String? ?? '';
      if (name.toLowerCase().endsWith('-windows.zip')) {
        windowsAsset = asset;
        break;
      }
    }
    if (windowsAsset == null) {
      throw const FormatException(
        'El Release no contiene un ZIP para Windows.',
      );
    }

    final assetName = windowsAsset['name'] as String;
    requireSafePathSegment(assetName, label: 'nombre del archivo');
    final downloadUrl = Uri.parse(
      windowsAsset['browser_download_url'] as String,
    );
    if (downloadUrl.scheme != 'https' || downloadUrl.host != 'github.com') {
      throw const FormatException('La descarga del Release no es válida.');
    }

    return AppUpdate(
      version: tag.replaceFirst(RegExp(r'^[vV]'), ''),
      title: json['name'] as String? ?? tag,
      notes: json['body'] as String? ?? '',
      assetName: assetName,
      downloadUrl: downloadUrl,
    );
  }

  Future<File> download(AppUpdate update, {String? dataRoot}) async {
    final response = await _client
        .get(update.downloadUrl)
        .timeout(const Duration(minutes: 2));
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'La descarga respondió ${response.statusCode}.',
        uri: update.downloadUrl,
      );
    }
    final directory = Directory(fichasDir('exports', dataRoot));
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, update.assetName));
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file;
  }
}

bool _isNewer(String candidate, String current) {
  final candidateParts = _versionParts(candidate);
  final currentParts = _versionParts(current);
  final length = candidateParts.length > currentParts.length
      ? candidateParts.length
      : currentParts.length;
  for (var index = 0; index < length; index++) {
    final next = index < candidateParts.length ? candidateParts[index] : 0;
    final installed = index < currentParts.length ? currentParts[index] : 0;
    if (next != installed) return next > installed;
  }
  return false;
}

List<int> _versionParts(String value) {
  final normalized = value
      .trim()
      .replaceFirst(RegExp(r'^[vV]'), '')
      .split('+')
      .first
      .split('-')
      .first;
  final parts = normalized.split('.').map(int.tryParse).toList();
  if (parts.isEmpty || parts.any((part) => part == null)) {
    throw FormatException('Versión no válida: $value');
  }
  return parts.cast<int>();
}
