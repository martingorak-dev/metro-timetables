import 'dart:io';
import 'dart:convert';

// Normalizace textu pro OCR (bez diakritiky, sjednocení mezer, lowercase)
String normalize(String s) {
  return s
      .toLowerCase()
      .replaceAll(RegExp(r'[áä]'), 'a')
      .replaceAll(RegExp(r'[č]'), 'c')
      .replaceAll(RegExp(r'[ď]'), 'd')
      .replaceAll(RegExp(r'[éě]'), 'e')
      .replaceAll(RegExp(r'[í]'), 'i')
      .replaceAll(RegExp(r'[ň]'), 'n')
      .replaceAll(RegExp(r'[óö]'), 'o')
      .replaceAll(RegExp(r'[ř]'), 'r')
      .replaceAll(RegExp(r'[š]'), 's')
      .replaceAll(RegExp(r'[ť]'), 't')
      .replaceAll(RegExp(r'[úů]'), 'u')
      .replaceAll(RegExp(r'[ý]'), 'y')
      .replaceAll(RegExp(r'[ž]'), 'z')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

Future<void> main() async {
  final input = File('ocr/output.txt');
  if (!input.existsSync()) return;

  final lines = input.readAsLinesSync();
  final normalizedLines = lines.map(normalize).toList();

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

  final normalizedStations = stations.map(normalize).toList();

  final result = {
    "line": "A",
    "stations": <String, dynamic>{}
  };

  final stationsMap = result["stations"] as Map<String, dynamic>;

  bool isDayStart(String t) =>
      t.startsWith("3:") || t.startsWith("4:") || t.startsWith("5:");

  // PRO KAŽDOU STANICI ZVLÁŠŤ
  for (int s = 0; s < stations.length; s++) {
    final station = stations[s];
    final normalizedStation = normalizedStations[s];

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

    int i = 0;
    while (i < normalizedLines.length) {
      final normLine = normalizedLines[i];

      // řádek nepatří této stanici → dál
      if (!normLine.contains(normalizedStation)) {
        i++;
        continue;
      }

      // 1) sebereme časy z řádku se stanicí
      List<String> times = timeRegex
          .allMatches(lines[i])
          .map((m) => m.group(0)!)
          .toList();

      // 2) podíváme se na následující řádky, jestli patří ke stejné „řádce tabulky“
      int j = i + 1;
      while (j < normalizedLines.length) {
        final nextNorm = normalizedLines[j];

        // pokud další řádek obsahuje nějakou jinou stanici → konec bloku
        bool containsOtherStation = false;
        for (final ns in normalizedStations) {
          if (nextNorm.contains(ns)) {
            containsOtherStation = true;
            break;
          }
        }
        if (containsOtherStation) break;

        // jinak zkusíme z něj vytáhnout časy (např. řádek s "int. 10  23:38 23:48...")
        final extraTimes = timeRegex
            .allMatches(lines[j])
            .map((m) => m.group(0)!)
            .toList();

        if (extraTimes.isNotEmpty) {
          times.addAll(extraTimes);
        }

        j++;
      }

      if (times.isEmpty) {
        i = j;
        continue;
      }

      final first = times.first;

      // DH logika – nový den podle 3/4/5:xx
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

      // uložení časů
      if (direction == "forward") {
        if (dayIndex == 0) forward["weekday"]!.addAll(times);
        if (dayIndex == 1) forward["saturday"]!.addAll(times);
        if (dayIndex == 2) forward["sunday"]!.addAll(times);
      } else {
        if (dayIndex == 0) backward["weekday"]!.addAll(times);
        if (dayIndex == 1) backward["saturday"]!.addAll(times);
        if (dayIndex == 2) backward["sunday"]!.addAll(times);
      }

      // přeskočíme všechny řádky, které jsme k této stanici už přibrali
      i = j;
    }

    stationsMap[station] = stationBlock;
  }

  File('json/A.json').writeAsStringSync(
    JsonEncoder.withIndent('  ').convert(result),
  );
}
