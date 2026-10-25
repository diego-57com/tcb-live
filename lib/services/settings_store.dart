import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persistência de preferências: favoritos e configuração do tempo real.
class SettingsStore {
  SettingsStore._(this._prefs);

  final SharedPreferences _prefs;

  static const _kFavorites = 'favorite_stop_ids';
  static const _kRealtimeUrl = 'realtime_url';
  static const _kRealtimeEnabled = 'realtime_enabled';
  static const _kArrayPath = 'realtime_array_path';
  static const _kLatField = 'realtime_lat_field';
  static const _kLonField = 'realtime_lon_field';
  static const _kBearingField = 'realtime_bearing_field';
  static const _kHeadsignField = 'realtime_headsign_field';
  static const _kColorField = 'realtime_color_field';
  static const _kRefreshSeconds = 'refresh_seconds';

  static Future<SettingsStore> load() async {
    return SettingsStore._(await SharedPreferences.getInstance());
  }

  Set<String> get favoriteStopIds =>
      (_prefs.getStringList(_kFavorites) ?? const []).toSet();

  Future<void> setFavorite(String stopId, bool fav) async {
    final s = favoriteStopIds;
    fav ? s.add(stopId) : s.remove(stopId);
    await _prefs.setStringList(_kFavorites, s.toList());
  }

  String? get realtimeUrl => _prefs.getString(_kRealtimeUrl);
  Future<void> setRealtimeUrl(String? v) async {
    if (v == null || v.trim().isEmpty) {
      await _prefs.remove(_kRealtimeUrl);
    } else {
      await _prefs.setString(_kRealtimeUrl, v.trim());
    }
  }

  bool get realtimeEnabled => _prefs.getBool(_kRealtimeEnabled) ?? false;
  Future<void> setRealtimeEnabled(bool v) =>
      _prefs.setBool(_kRealtimeEnabled, v);

  List<String> get arrayPath =>
      (jsonDecode(_prefs.getString(_kArrayPath) ?? '[]') as List)
          .map((e) => e.toString())
          .toList();
  Future<void> setArrayPath(List<String> v) =>
      _prefs.setString(_kArrayPath, jsonEncode(v));

  String get latField => _prefs.getString(_kLatField) ?? 'lat';
  Future<void> setLatField(String v) => _prefs.setString(_kLatField, v);

  String get lonField => _prefs.getString(_kLonField) ?? 'lon';
  Future<void> setLonField(String v) => _prefs.setString(_kLonField, v);

  String get bearingField => _prefs.getString(_kBearingField) ?? 'bearing';
  Future<void> setBearingField(String v) =>
      _prefs.setString(_kBearingField, v);

  String get headsignField => _prefs.getString(_kHeadsignField) ?? 'headsign';
  Future<void> setHeadsignField(String v) =>
      _prefs.setString(_kHeadsignField, v);

  String get colorField => _prefs.getString(_kColorField) ?? '';
  Future<void> setColorField(String v) => _prefs.setString(_kColorField, v);

  int get refreshSeconds => _prefs.getInt(_kRefreshSeconds) ?? 10;
  Future<void> setRefreshSeconds(int v) =>
      _prefs.setInt(_kRefreshSeconds, v);
}
