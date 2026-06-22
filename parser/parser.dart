import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  final input = File('ocr/output.txt');
  if (!input.existsSync()) return;

  final lines = input.readAsLinesSync();
  final timeRegex = RegExp(r'\b\d{1,2}:\d{2}\b');

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

  final result = {
    "line": "A",
    "stations": <String, dynamic>{}
  };

  // přetypování – TOTO JE KLÍČ
  final stationsMap = result["stations"] as Map<String, dynamic>;

  bool isDayStart(String t) =>
      t.startsWith("3:") || t.startsWith("4:") || t.startsWith("5:");

  // PRO KAŽDOU STANICI ZVLÁŠŤ
  for (final station in stations) {
    // přesně tvůj původní DH blok
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

    int dayStartCount = 0;
    String direction = "forward";
    int dayIndex = 0;

    // projdeme celý soubor – ale jen řádky této stanice
    for (final line in lines) {
      if (!line.contains(station)) continue;

      final times = timeRegex.allMatches(line).map((m) => m.group(0)!).toList();
      if (times.isEmpty) continue;

      final first = times.first;

      // přesně tvoje DH logika
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

      // uložení časů – přesně jako DH
      if (direction == "forward") {
        if (dayIndex == 0) forward["weekday"]!.addAll(times);
        if (dayIndex == 1) forward["saturday"]!.addAll(times);
        if (dayIndex == 2) forward["sunday"]!.addAll(times);
      } else {
        if (dayIndex == 0) backward["weekday"]!.addAll(times);
        if (dayIndex == 1) backward["saturday"]!.addAll(times);
        if (dayIndex == 2) backward["sunday"]!.addAll(times);
      }
    }

    // uložíme výsledek pro tuto stanici
    stationsMap[station] = stationBlock;
  }

  File('json/A.json').writeAsStringSync(
    JsonEncoder.withIndent('  ').convert(result),
  );
}
