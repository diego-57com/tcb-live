import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/gtfs_models.dart';
import '../models/vehicle.dart';
import '../services/gtfs_repository.dart';
import '../services/location_service.dart';
import '../services/realtime_source.dart';
import '../services/settings_store.dart';

/// Centro por omissão: Barreiro.
const LatLng kDefaultCenter = LatLng(38.6526, -9.0748);

/// Estado global da app (provider).
class AppState extends ChangeNotifier {
  AppState();

  final GtfsRepository _repository = GtfsRepository();
  final LocationService _location = const LocationService();

  GtfsFeed? feed;
  bool loading = true;
  String? error;

  List<LiveVehicle> vehicles = const [];
  bool vehiclesLoading = false;
  String? realtimeError;

  SettingsStore? _settings;
  Set<String> _favorites = const {};

  // Configuração do tempo real (o utilizador preenche na app).
  String realtimeUrl = '';
  bool realtimeEnabled = false;
  List<String> realtimeArrayPath = const [];
  String latField = 'lat';
  String lonField = 'lon';
  String bearingField = 'bearing';
  String headsignField = 'headsign';
  String colorField = '';

  /// Intervalo de atualização do tempo real (segundos).
  int refreshSeconds = 10;

  LatLng? currentLocation;

  Timer? _pollTimer;

  Set<String> get favorites => _favorites;

  List<Stop> get favoriteStops {
    final f = feed;
    if (f == null) return const [];
    return _favorites.map((id) => f.stops[id]).whereType<Stop>().toList();
  }

  Future<void> init() async {
    _settings = await SettingsStore.load();
    _favorites = _settings!.favoriteStopIds;
    realtimeUrl = _settings!.realtimeUrl ?? '';
    realtimeEnabled = _settings!.realtimeEnabled;
    realtimeArrayPath = _settings!.arrayPath;
    latField = _settings!.latField;
    lonField = _settings!.lonField;
    bearingField = _settings!.bearingField;
    headsignField = _settings!.headsignField;
    colorField = _settings!.colorField;
    refreshSeconds = _settings!.refreshSeconds;

    await loadGtfs();
    if (realtimeEnabled && realtimeUrl.isNotEmpty) {
      startRealtimePolling();
    }
  }

  Future<void> loadGtfs() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      feed = await _repository.load();
    } catch (e) {
      error = 'Não foi possível carregar os dados da TCB.\n$e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  bool isFavorite(String stopId) => _favorites.contains(stopId);

  Future<void> toggleFavorite(String stopId) async {
    final fav = !_favorites.contains(stopId);
    fav ? _favorites.add(stopId) : _favorites.remove(stopId);
    notifyListeners();
    await _settings?.setFavorite(stopId, fav);
  }

  Future<void> setRealtimeConfig({
    required String url,
    required bool enabled,
    List<String>? arrayPath,
    String? latField,
    String? lonField,
    String? bearingField,
    String? headsignField,
    String? colorField,
  }) async {
    realtimeUrl = url;
    realtimeEnabled = enabled;
    if (arrayPath != null) realtimeArrayPath = arrayPath;
    if (latField != null) this.latField = latField;
    if (lonField != null) this.lonField = lonField;
    if (bearingField != null) this.bearingField = bearingField;
    if (headsignField != null) this.headsignField = headsignField;
    if (colorField != null) this.colorField = colorField;

    await _settings?.setRealtimeUrl(url);
    await _settings?.setRealtimeEnabled(enabled);
    await _settings?.setArrayPath(realtimeArrayPath);
    await _settings?.setLatField(this.latField);
    await _settings?.setLonField(this.lonField);
    await _settings?.setBearingField(this.bearingField);
    await _settings?.setHeadsignField(this.headsignField);
    await _settings?.setColorField(this.colorField);

    if (enabled && url.isNotEmpty) {
      startRealtimePolling();
      await refreshVehicles();
    } else {
      stopRealtimePolling();
      vehicles = const [];
      realtimeError = null;
      notifyListeners();
    }
  }

  Future<void> setRefreshSeconds(int seconds) async {
    refreshSeconds = seconds.clamp(3, 120);
    await _settings?.setRefreshSeconds(refreshSeconds);
    if (realtimeEnabled) startRealtimePolling();
    notifyListeners();
  }

  void startRealtimePolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(Duration(seconds: refreshSeconds), (_) {
      refreshVehicles();
    });
  }

  void stopRealtimePolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> refreshVehicles() async {
    if (realtimeUrl.isEmpty) return;
    if (vehiclesLoading) return;
    vehiclesLoading = true;
    notifyListeners();
    try {
      final source = JsonVehiclesSource(JsonVehiclesConfig(
        url: realtimeUrl,
        arrayPath: realtimeArrayPath,
        latField: latField,
        lonField: lonField,
        bearingField: bearingField,
        headsignField: headsignField,
        routeColorField: colorField.isEmpty ? null : colorField,
      ));
      vehicles = await source.fetch();
      realtimeError = null;
    } catch (e) {
      realtimeError = 'Tempo real indisponível: $e';
    } finally {
      vehiclesLoading = false;
      notifyListeners();
    }
  }

  /// Veículos cujo `routeName` (nº da carreira) corresponde ao número dado.
  List<LiveVehicle> vehiclesForRouteNumber(String number) {
    return vehicles
        .where((v) => (v.routeName ?? '').trim() == number.trim())
        .toList();
  }

  Future<bool> locateMe() async {
    final p = await _location.currentPosition();
    if (p != null) {
      currentLocation = p;
      notifyListeners();
      return true;
    }
    return false;
  }

  List<Stop> nearestStops(LatLng origin, {int limit = 15}) {
    final f = feed;
    if (f == null) return const [];
    return _location.nearestStops(f, origin, limit: limit);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
