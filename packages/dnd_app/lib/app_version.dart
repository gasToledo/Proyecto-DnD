import 'package:package_info_plus/package_info_plus.dart';

/// Versión instalada, para el rótulo del panel lateral. Sin relación con
/// `UpdateService` (retirado del build web, ver capacidad `web-client`): esto
/// no compara contra nada, solo informa qué versión está corriendo.
Future<String> currentAppVersion() async =>
    (await PackageInfo.fromPlatform()).version;
