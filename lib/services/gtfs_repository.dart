import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/gtfs_models.dart';
import 'gtfs_parser.dart';

/// URL oficial do GTFS estático da TCB (licença CC BY 4.0).
const String kGtfsUrl = 'https://backend.tcbarreiro.pt/download-gtfs';

/// Descarrega e faz cache do GTFS da TCB.
class GtfsRepository {
  GtfsRepository({this.url = kGtfsUrl, this.maxAge = const Duration(days: 1)});

  final String url;
  final Duration maxAge;

  Future<GtfsFeed> load() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}tcb_gtfs.zip');

    var bytes = await _readCacheIfFresh(file);
    if (bytes == null) {
      bytes = await _download();
      try {
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes, flush: true);
      } catch (_) {
        // Cache é opcional; continuamos em memória.
      }
    }
    return GtfsParser.parse(bytes);
  }

  Future<List<int>?> _readCacheIfFresh(File file) async {
    try {
      if (await file.exists()) {
        final stat = await file.stat();
        final age = DateTime.now().difference(stat.modified);
        if (age < maxAge) return await file.readAsBytes();
      }
    } catch (_) {}
    return null;
  }

  Future<List<int>> _download() async {
    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode != 200) {
      throw Exception('Falha ao descarregar GTFS (HTTP ${resp.statusCode})');
    }
    return resp.bodyBytes;
  }
}
