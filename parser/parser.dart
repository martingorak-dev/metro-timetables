import 'dart:io';
import 'dart:convert';

// Normalizace textu pro OCR
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

// -------------------------------
// PARSER PRO JEDNU LINKU
// -------------------------------
Map<String, dynamic> parseLine(
    String lineName,
    List<String> stations,
    String inputPath,
    ) {
  final input = File(inputPath);
  if (!input.existsSync()) {
    print("Skipping $lineName – no TXT file found.");
    return {}; // nic nevytváříme
  }

  print("Parsing line $lineName from $inputPath");

  final lines = input.readAsLinesSync();
  final normalizedLines = lines.map(normalize).toList();
  final normalizedStations = stations.map(normalize).toList();

  final timeRegex = RegExp(r'\b\d{1,2}:\d{2}\b');

  final result = {
    "line": lineName,
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

      if (!normLine.contains(normalizedStation)) {
        i++;
        continue;
      }

      // 1) časy z řádku se stanicí
      List<String> times = timeRegex
          .allMatches(lines[i])
          .map((m) => m.group(0)!)
          .toList();

      // 2) připojit rozsekané řádky (int. 10, pokračování řádku)
      int j = i + 1;
      while (j < normalizedLines.length) {
        final nextNorm = normalizedLines[j];

        bool containsOtherStation = false;
        for (final ns in normalizedStations) {
          if (nextNorm.contains(ns)) {
            containsOtherStation = true;
            break;
          }
        }
        if (containsOtherStation) break;

        // ignorujeme příjezdy
        if (nextNorm.contains("prij")) {
          j++;
          continue;
        }

// bereme jen odjezdy nebo řádky bez textu prij/odj
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

      if (direction == "forward") {
        if (dayIndex == 0) forward["weekday"]!.addAll(times);
        if (dayIndex == 1) forward["saturday"]!.addAll(times);
        if (dayIndex == 2) forward["sunday"]!.addAll(times);
      } else {
        if (dayIndex == 0) backward["weekday"]!.addAll(times);
        if (dayIndex == 1) backward["saturday"]!.addAll(times);
        if (dayIndex == 2) backward["sunday"]!.addAll(times);
      }

      i = j;
    }

    stationsMap[station] = stationBlock;
  }

  return result;
}

// -------------------------------
// HLAVNÍ PROGRAM – A/B/C
// -------------------------------
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print("Missing line argument (A/B/C)");
    return;
  }

  final line = args[0].toUpperCase();
  final inputPath = "ocr/$line.txt";
  final outputPath = "json/$line.json";

  // Seznamy stanic
  const stationsA = [
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

  const stationsB = [
    "ZLIČÍN",
    "Stodůlky",
    "Luka",
    "Lužiny",
    "Hůrka",
    "Nové Butovice",
    "Jinonice",
    "Radlická",
    "Smíchovské nádraží",
    "Anděl",
    "Karlovo náměstí",
    "Národní třída",
    "Můstek - B",
    "Náměstí Republiky",
    "Florenc - B",
    "Křižíkova",
    "Invalidovna",
    "Palmovka",
    "Českomoravská",
    "Vysočanská",
    "Kolbenova",
    "Hloubětín",
    "Rajská zahrada",
    "ČERNÝ MOST"
  ];

  const stationsC = [
    "LETŇANY",
    "Prosek",
    "Střížkov",
    "Ládví",
    "Kobylisy",
    "Nádraží Holešovice",
    "Vltavská",
    "Florenc - C",
    "Hlavní nádraží",
    "Muzeum - C",
    "I. P. Pavlova",
    "Vyšehrad",
    "Pražského povstání",
    "Pankrác",
    "Budějovická",
    "Kačerov",
    "Roztyly",
    "Chodov",
    "Opatov",
    "HÁJE"
  ];

  late List<String> stations;

  if (line == "A") stations = stationsA;
  else if (line == "B") stations = stationsB;
  else if (line == "C") stations = stationsC;
  else {
    print("Unknown line: $line");
    return;
  }

  final result = parseLine(line, stations, inputPath);

  if (result.isNotEmpty) {
    File(outputPath).writeAsStringSync(
      JsonEncoder.withIndent('  ').convert(result),
    );
    print("Saved $outputPath");
  }
}
