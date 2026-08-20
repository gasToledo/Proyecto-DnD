import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';

/// Estado de las campañas que dirige esta cuenta.
///
/// A diferencia de `CharactersController` no tiene rebote ni cola de guardado:
/// una campaña se edita con acciones explícitas y contadas (crear, renombrar,
/// borrar), no tecleando sobre una ficha viva. Meterle esa maquinaria sería
/// copiar complejidad que acá no compra nada.
class CampaignsController extends ChangeNotifier {
  final ApiClient api;

  CampaignsController(this.api);

  final List<Campaign> campaigns = [];

  /// La carga falló por falta de conexión, que no es lo mismo que una cuenta
  /// sin campañas: una ofrece reintentar y la otra ofrece crear la primera.
  bool loadFailedOffline = false;

  bool _loading = false;
  bool get isLoading => _loading;

  Future<void> load() async {
    _loading = true;
    loadFailedOffline = false;
    notifyListeners();
    try {
      final all = await api.listCampaigns();
      campaigns
        ..clear()
        ..addAll(all);
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;
      loadFailedOffline = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Crea una campaña y devuelve la que **quedó guardada**: si el id derivado
  /// del nombre ya estaba en uso, el servidor asigna otro.
  Future<Campaign> create(
    String name, {
    String premise = '',
    CampaignState state = CampaignState.active,
  }) async {
    final stored = await api.createCampaign(
      Campaign(id: _idFrom(name), name: name, premise: premise, state: state),
    );
    campaigns.add(stored);
    _sort();
    notifyListeners();
    return stored;
  }

  Future<void> update(Campaign campaign) async {
    await api.upsertCampaign(campaign);
    final index = campaigns.indexWhere((c) => c.id == campaign.id);
    if (index >= 0) campaigns[index] = campaign;
    _sort();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await api.deleteCampaign(id);
    campaigns.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  void _sort() => campaigns.sort(
    (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
  );

  /// Id legible derivado del nombre, con la hora como respaldo si el nombre no
  /// deja ningún carácter usable (por ejemplo si es todo emoji). El servidor
  /// resuelve las colisiones, así que acá alcanza con que sea razonable.
  static String _idFrom(String name) {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.isEmpty) return DateTime.now().microsecondsSinceEpoch.toString();
    return slug.length <= 40 ? slug : slug.substring(0, 40);
  }
}
