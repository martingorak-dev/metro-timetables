import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  final input = File('ocr/output.txt');
  if (!input.existsSync()) return;

  final lines = input.readAsLinesSync();
  final timeRegex = RegExp(r'\b\d{1,2}:\d{2}\b');

  const depot = "DEPO HOSTIVAŘ";

  // všechny stanice linky A
  const stations = [
    "DEPO HOSTIVAŘ",
    "Skalka",
    "Strašnická",
    "Želivského",
    "Jiřího z Poděbrad",
    "Náměstí Míru",
    "Muzeum - A",
    "Můstek - A",
    "Staroměstská",
    "Malostranská",
    "Hradčanská",
    "Dejvická",
    "Bořislavka",
    "Nádraží Veleslavín",
    "Petřiny",
    "NEMOCNICE MOTOL"
  ];

  bool isDayStart(String t) =>
      t.startsWith("3:") || t.startsWith("4:") || t.startsWith("5:");

  // 1) PRŮCHOD – jen DH, zjistíme pro každý řádek direction + dayIndex
  final directionsForLine = List<String>.filled(lines.length, "forward");
  final dayIndexForLine = List<int>.filled(lines.length, 0);

  int dayStartCount = 0;
  String direction = "forward";
  int dayIndex = 0;

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];

    if (line.contains(depot)) {
      final times = timeRegex.allMatches(line).map((m) => m.group(0)!).toList();
      if (times.isNotEmpty) {
        final first = times.first;

        if (isDayStart(first)) {
          dayStartCount++;

          if (dayStartCount <= 3) {
            direction = "forward";
            dayIndex = dayStartCount - 1;
          } else if (dayStartCount <= 6) {
            direction = "backward";
            dayIndex = dayStartCount - 4;
          }
        }
      }
    }

    directionsForLine[i] = direction;
    dayIndexForLine[i] = dayIndex;
  }

  // 2) PRŮCHOD – všechny stanice, používáme rozdělení podle DH
  final result = {
    "line": "A",
    "stations": <String, dynamic>{},
  };

  final stationsMap = result["stations"] as Map<String, dynamic>;

  for (final station in stations) {
    final stationBlock = {
      "forward": {
        "weekday": <String>[],
        "saturday": <String>[],
        "sunday": <String>[],
      },
      "backward": {
        "weekday": <String>[],
        "saturday": <String>[],
        "sunday": <String>[],
      }
    };

    final forward = stationBlock["forward"] as Map<String, List<String>>;
    final backward = stationBlock["backward"] as Map<String, List<String>>;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (!line.contains(station)) continue;

      final times = timeRegex.allMatches(line).map((m) => m.group(0)!).toList();
      if (times.isEmpty) continue;

      final dir = directionsForLine[i];
      final idx = dayIndexForLine[i];
      final dayName = ["weekday", "saturday", "sunday"][idx];

      if (dir == "forward") {
        forward[dayName]!.addAll(times);
      } else {
        backward[dayName]!.addAll(times);
      }
    }

    stationsMap[station] = stationBlock;
  }

  File('json/A.json').writeAsStringSync(
    JsonEncoder.withIndent('  ').convert(result),
  );
}
