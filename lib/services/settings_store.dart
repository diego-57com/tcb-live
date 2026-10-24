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
}
