import 'dart:io';

void main() async {
  final buffer = StringBuffer();
  buffer.writeln("=== METRO A – TAM/ZPĚT (TEST) ===");

  final trips = _loadCsv("PID_GTFS/trips.txt");
  final stopTimes = _loadCsv("PID_GTFS/stop_times.txt");
  final stops = _loadCsv("PID_GTFS/stops.txt");
  final calendar = _loadCsv("PID_GTFS/calendar.txt");
  final calendarDates = _loadCsv("PID_GTFS/calendar_dates.txt");

  const routeIdA = "L991";

  final tripsA = trips.where((t) => t["route_id"] == routeIdA).toList();

  // Výstupní struktura
  final result = {
    "weekday": {
      "TAM": <String, List<String>>{},
      "ZPET": <String, List<String>>{},
    },
    "saturday": {
      "TAM": <String, List<String>>{},
      "ZPET": <String, List<String>>{},
    },
    "sunday": {
      "TAM": <String, List<String>>{},
      "ZPET": <String, List<String>>{},
    },
  };

  for (var trip in tripsA) {
    final tripId = trip["trip_id"]!;
    final serviceId = trip["service_id"]!;
    final direction = trip["direction_id"]!;

    final dayType = _resolveDayType(serviceId, calendar, calendarDates);
    if (dayType == null) continue;

    final times = stopTimes.where((st) => st["trip_id"] == tripId).toList();
    if (times.isEmpty) continue;

    // První zastávka tripu
    final firstStop = times.first["stop_id"]!;
    final firstStopName = stops
        .firstWhere((s) => s["stop_id"] == firstStop)["stop_name"]!;

    // Filtrace podle směru
    if (direction == "0" && firstStopName != "Depo Hostivař") continue;
    if (direction == "1" && firstStopName != "Nemocnice Motol") continue;

    final dirKey = direction == "0" ? "TAM" : "ZPET";

    // Přiřazení časů ke stanicím
    for (var st in times) {
      final stopId = st["stop_id"]!;
      final departure = st["departure_time"]!;

      final stopName = stops
          .firstWhere((s) => s["stop_id"] == stopId)["stop_name"]!;

      result[dayType]![dirKey]!.putIfAbsent(stopName, () => []);
      result[dayType]![dirKey]![stopName]!.add(departure);
    }
  }

  // Seřadit časy
  for (var day in result.keys) {
    for (var dir in ["TAM", "ZPET"]) {
      for (var stop in result[day]![dir]!.keys) {
        result[day]![dir]![stop]!.sort(
              (a, b) => _timeToSeconds(a).compareTo(_timeToSeconds(b)),
        );
      }
    }
  }

  // Výstup
  for (var day in ["weekday", "saturday", "sunday"]) {
    buffer.writeln("\n=== $day ===");

    for (var dir in ["TAM", "ZPET"]) {
      buffer.writeln("\n--- $dir ---");

      final stations = result[day]![dir]!;
      for (var entry in stations.entries) {
        final stopName = entry.key;
        final times = entry.value;

        buffer.writeln("\n$stopName:");

        if (stopName == "Depo Hostivař" || stopName == "Nemocnice Motol") {
          buffer.writeln(times.join(", "));
        } else {
          buffer.writeln(times.take(20).join(", "));
        }
      }
    }
  }

  await File("debug_output.txt").writeAsString(buffer.toString());
  print("Done.");
}

int _timeToSeconds(String t) {
  final p = t.split(":").map(int.parse).toList();
  return p[0] * 3600 + p[1] * 60 + p[2];
}

String? _resolveDayType(
    String serviceId,
    List<Map<String, String>> calendar,
    List<Map<String, String>> calendarDates,
    ) {
  final row = calendar.firstWhere(
        (c) => c["service_id"] == serviceId,
    orElse: () => {},
  );

  if (row.isEmpty) return null;

  if (row["monday"] == "1") return "weekday";
  if (row["saturday"] == "1") return "saturday";
  if (row["sunday"] == "1") return "sunday";

  return null;
}

List<Map<String, String>> _loadCsv(String path) {
  final file = File(path);
  final lines = file.readAsLinesSync();
  final header = _safeSplit(lines.first);

  return lines.skip(1).map((line) {
    final values = _safeSplit(line);
    return Map.fromIterables(header, values);
  }).toList();
}

List<String> _safeSplit(String line) {
  final result = <String>[];
  var current = StringBuffer();
  var inQuotes = false;

  for (var rune in line.runes) {
    var c = String.fromCharCode(rune);

    if (c == '"') {
      inQuotes = !inQuotes;
    } else if (c == ',' && !inQuotes) {
      result.add(current.toString());
      current = StringBuffer();
    } else {
      current.write(c);
    }
  }

  result.add(current.toString());
  return result;
}
