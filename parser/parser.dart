import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  final input = File('ocr/output.txt');
  if (!input.existsSync()) return;

  final lines = input.readAsLinesSync();
  final timeRegex = RegExp(r'\b\d{1,2}:\d{2}\b');

  // Linka A
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

  // Výstupní struktura
  final result = {
    "line": "A",
    "stations": <String, dynamic>{}
  };

  final stationsMap = result["stations"] as Map<String, dynamic>;

  // Stav pro každou stanici
  final state = <String, Map<String, dynamic>>{};

  for (final s in stations) {
    stationsMap[s] = {
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

    state[s] = {
      "dayStartCount": 0,
      "direction": "forward",
      "dayIndex": 0
    };
  }

  bool isDayStart(String t) =>
      t.startsWith("3:") || t.startsWith("4:") || t.startsWith("5:");

  for (final line in lines) {
    // Najdeme stanici
    final station = stations.firstWhere(
          (s) => line.contains(s),
      orElse: () => "",
    );
    if (station.isEmpty) continue;

    final times = timeRegex.allMatches(line).map((m) => m.group(0)!).toList();
    if (times.isEmpty) continue;

    final first = times.first;

    // Stav stanice
    final st = state[station]!;
    int dayStartCount = st["dayStartCount"];
    String direction = st["direction"];
    int dayIndex = st["dayIndex"];

    // Nový den pro tuto stanici
    if (isDayStart(first)) {
      dayStartCount++;

      if (dayStartCount <= 3) {
        direction = "forward";
        dayIndex = dayStartCount - 1;
      } else if (dayStartCount <= 6) {
        direction = "backward";
        dayIndex = dayStartCount - 4;
      }

      st["dayStartCount"] = dayStartCount;
      st["direction"] = direction;
      st["dayIndex"] = dayIndex;
    }

    // Uložení časů
    final stationBlock = stationsMap[station] as Map<String, dynamic>;
    final dirBlock = stationBlock[direction] as Map<String, List<String>>;
    final dayName = ["weekday", "saturday", "sunday"][dayIndex];

    dirBlock[dayName]!.addAll(times);
  }

  File('json/A.json').writeAsStringSync(
    JsonEncoder.withIndent('  ').convert(result),
  );
}
