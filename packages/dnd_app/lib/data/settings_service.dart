import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'app_paths.dart';
import 'atomic_json_file.dart';
import 'data_recovery.dart';

/// Ajustes de la app persistidos localmente. Por ahora, solo la API key de
/// generación de imágenes. Se guarda en texto plano en el equipo del usuario
/// (app personal); Claude nunca la ve ni la solicita.
/// Modelo por defecto de Hugging Face servido hoy por el proveedor gratuito
/// `hf-inference` (el catálogo gratuito cambia seguido; por eso es editable).
const defaultHuggingFaceModel =
    'stabilityai/stable-diffusion-3-medium-diffusers';

class AppSettings {
  /// Proveedor de imágenes elegido: 'pollinations' | 'huggingface' | 'gemini'.
  String imageProvider;
  String geminiApiKey;
  String huggingFaceToken;
  String huggingFaceModel;

  AppSettings({
    this.imageProvider = 'pollinations',
    this.geminiApiKey = '',
    this.huggingFaceToken = '',
    this.huggingFaceModel = defaultHuggingFaceModel,
  });

  /// La key correspondiente al proveedor indicado (o '' si no aplica).
  String keyFor(String providerId) => switch (providerId) {
    'gemini' => geminiApiKey,
    'huggingface' => huggingFaceToken,
    _ => '',
  };

  Map<String, dynamic> toJson() => {
    'imageProvider': imageProvider,
    'geminiApiKey': geminiApiKey,
    'huggingFaceToken': huggingFaceToken,
    'huggingFaceModel': huggingFaceModel,
  };

  /// Preferencias aptas para un respaldo compartible. Las credenciales quedan
  /// siempre en el equipo de origen.
  Map<String, dynamic> toPortableJson() => {
    'imageProvider': imageProvider,
    'huggingFaceModel': huggingFaceModel,
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    imageProvider: j['imageProvider'] as String? ?? 'pollinations',
    geminiApiKey: j['geminiApiKey'] as String? ?? '',
    huggingFaceToken: j['huggingFaceToken'] as String? ?? '',
    huggingFaceModel:
        (j['huggingFaceModel'] as String?)?.trim().isNotEmpty == true
        ? j['huggingFaceModel'] as String
        : defaultHuggingFaceModel,
  );
}

class SettingsService {
  final String? dataRoot;
  final List<DataRecoveryIssue> recoveryIssues = [];

  SettingsService({this.dataRoot});

  File get _file => File(p.join(fichasDir(null, dataRoot), 'settings.json'));

  Future<AppSettings> load() async {
    recoveryIssues.clear();
    final f = _file;
    try {
      if (!await f.exists()) return AppSettings();
      return AppSettings.fromJson(
        jsonDecode(await f.readAsString()) as Map<String, dynamic>,
      );
    } catch (error) {
      if (await f.exists()) {
        recoveryIssues.add(
          await recoverCorruptFile(f, error, dataRoot: dataRoot),
        );
      }
      return AppSettings();
    }
  }

  Future<void> save(AppSettings settings) async {
    await writeJsonAtomic(_file, settings.toJson(), pretty: false);
  }

  /// Aplica únicamente preferencias portables y conserva las credenciales
  /// locales existentes.
  Future<void> restorePortable(Map<String, dynamic> preferences) async {
    final current = await load();
    final provider = preferences['imageProvider'];
    final model = preferences['huggingFaceModel'];
    if (provider is String &&
        const {'pollinations', 'huggingface', 'gemini'}.contains(provider)) {
      current.imageProvider = provider;
    }
    if (model is String && model.trim().isNotEmpty) {
      current.huggingFaceModel = model.trim();
    }
    await save(current);
  }
}
