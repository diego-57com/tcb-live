/// Parser CSV mínimo mas robusto (RFC 4180), suficiente para GTFS:
/// campos entre aspas, vírgulas dentro de aspas e aspas escapadas ("") .
library;

List<List<String>> parseCsv(String input) {
  final rows = <List<String>>[];
  final field = StringBuffer();
  final row = <String>[];
  var inQuotes = false;

  for (var i = 0; i < input.length; i++) {
    final c = input[i];
    if (inQuotes) {
      if (c == '"') {
        // Aspas duplas dentro de aspas => aspa literal.
        if (i + 1 < input.length && input[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(c);
      }
    } else {
      if (c == '"') {
        inQuotes = true;
      } else if (c == ',') {
        row.add(field.toString());
        field.clear();
      } else if (c == '\n') {
        row.add(field.toString());
        field.clear();
        rows.add(row.toList());
        row.clear();
      } else if (c == '\r') {
        // ignorar (o \n seguinte fecha a linha)
      } else {
        field.write(c);
      }
    }
  }
  // Última linha sem \n final.
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}

/// Converte as linhas CSV numa lista de mapas {cabeçalho -> valor}.
List<Map<String, String>> parseCsvToMaps(String input) {
  final rows = parseCsv(input);
  if (rows.isEmpty) return const [];
  final header = rows.first;
  final result = <Map<String, String>>[];
  for (var i = 1; i < rows.length; i++) {
    final line = rows[i];
    final map = <String, String>{};
    for (var c = 0; c < header.length; c++) {
      map[header[c]] = c < line.length ? line[c] : '';
    }
    result.add(map);
  }
  return result;
}
