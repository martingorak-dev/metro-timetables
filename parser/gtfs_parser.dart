import 'dart:io';

void main() async {
  final buffer = StringBuffer();
  buffer.writeln("=== METRO A (TEST) ===");

  // Load GTFS files
  final trips = _loadCsv("PID_GTFS/trips.txt");
  final stopTimes = _loadCsv("PID_GTFS/stop_times.txt");
  final stops = _loadCsv("PID_GTFS/stops.txt");
  final calendar = _loadCsv("PID_GTFS/calendar.txt");
  final calendarDates = _loadCsv("PID_GTFS/calendar_dates.txt");

  // Metro A route_id
  const routeIdA = "L991";

  buffer.writeln("Route A = $routeIdA");

  // Find trips for A
  final tripsA = trips.where((t) => t["route_id"] == routeIdA).toList();
  buffer.writeln("Trips found: ${tripsA.length}");

  // Prepare output structure
  final result = {
    "weekday": <String, List<String>>{},
    "saturday": <String, List<String>>{},
    "sunday": <String, List<String>>{},
  };

  // Process each trip
  for (var trip in tripsA) {
    final tripId = trip["trip_id"]!;
    final serviceId = trip["service_id"]!;

    final dayType = _resolveDayType(serviceId, calendar, calendarDates);
    if (dayType == null) continue;

    // Load stop_times for this trip
    final times = stopTimes.where((st) => st["trip_id"] == tripId);

    for (var st in times) {
      final stopId = st["stop_id"]!;
      final departure = st["departure_time"]!;

      final stopName = stops.firstWhere(
            (s) => s["stop_id"] == stopId,
        orElse: () => {"stop_name": "UNKNOWN"},
      )["stop_name"]!;

      result[dayType]!.putIfAbsent(stopName, () => []);
      result[dayType]![stopName]!.add(departure);
    }
  }

  // Write output
  for (var day in ["weekday", "saturday", "sunday"]) {
    buffer.writeln("\n=== $day ===");
    final stations = result[day]!;
    for (var entry in stations.entries) {
      buffer.writeln("${entry.key}: ${entry.value.length} odjezdů");
    }
  }

  await File("debug_output.txt").writeAsString(buffer.toString());
  print("Done.");
}

// Determine weekday/saturday/sunday
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

// CSV loader
List<Map<String, String>> _loadCsv(String path) {
  final file = File(path);
  final lines = file.readAsLinesSync();
  final header = _safeSplit(lines.first);

  return lines.skip(1).map((line) {
    final values = _safeSplit(line);
    return Map.fromIterables(header, values);
  }).toList();
}

// Handles quoted CSV fields
List<String> _safeSplit(String line) {
  final result = <String>[];
  var current = StringBuffer();
  var inQuotes = false;

  for (var rune in line.runes) {
    var char = String.fromCharCode(rune);

    if (char == '"') {
      inQuotes = !inQuotes;
    } else if (char == ',' && !inQuotes) {
      result.add(current.toString());
      current = StringBuffer();
    } else {
      current.write(char);
    }
  }

  result.add(current.toString());
  return result;
}
