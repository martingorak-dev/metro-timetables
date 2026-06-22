import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  final input = File('ocr/output.txt');
  if (!input.existsSync()) return;

  final lines = input.readAsLinesSync();
  final timeRegex = RegExp(r'\b\d{1,2}:\d{2}\b');

  // -------------------------------
  // LINKA A (aktivní)
  // -------------------------------
  const stationsForward = [
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

  // -------------------------------
  // LINKA B (zatím zakomentovaná)
  // -------------------------------
  /*
  const stationsForward = [
    "Zličín",
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
    "Černý Most"
  ];
  */

  // -------------------------------
  // LINKA C (zatím zakomentovaná)
  // -------------------------------
  /*
  const stationsForward = [
    "Letňany",
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
    "Háje"
  ];
  */

  // -------------------------------
  // Výstupní struktura
  // -------------------------------
  final result = {
    "line": "A",
    "directions": {
      "forward": <String, Map<String, List<String>>>{},
      "backward": <String, Map<String, List<String>>>{},
    }
  };

  final directions = result["directions"] as Map<String, dynamic>;
  final forward = directions["forward"] as Map<String, Map<String, List<String>>>;
  final backward = directions["backward"] as Map<String, Map<String, List<String>>>;

  // Inicializace všech stanic
  for (final s in stationsForward) {
    forward[s] = {
      "weekday": <String>[],
      "saturday": <String>[],
      "sunday": <String>[],
    };
    backward[s] = {
      "weekday": <String>[],
      "saturday": <String>[],
      "sunday": <String>[],
    };
  }

  // První stanice = marker dne
  final dayMarker = stationsForward.first;

  int dayStartCount = 0;
  String direction = "forward";
  int dayIndex = 0;

  bool isDayStart(String t) =>
      t.startsWith("3:") || t.startsWith("4:") || t.startsWith("5:");

  for (final line in lines) {
    // Najdeme stanici
    final station = stationsForward.firstWhere(
          (s) => line.contains(s),
      orElse: () => "",
    );
    if (station.isEmpty) continue;

    final times = timeRegex.allMatches(line).map((m) => m.group(0)!).toList();
    if (times.isEmpty) continue;

    final first = times.first;

    // První stanice řídí den a směr
    if (station == dayMarker && isDayStart(first)) {
      dayStartCount++;

      if (dayStartCount <= 3) {
        direction = "forward";
        dayIndex = dayStartCount - 1;
      } else if (dayStartCount <= 6) {
        direction = "backward";
        dayIndex = dayStartCount - 4;
      }
    }

    // Uložení časů
    final target = direction == "forward" ? forward : backward;
    final dayName = ["weekday", "saturday", "sunday"][dayIndex];

    final stationMap = target[station];
    if (stationMap == null) continue;

    final list = stationMap[dayName];
    if (list == null) continue;

    list.addAll(times);
  }

  File('json/A.json').writeAsStringSync(
    JsonEncoder.withIndent('  ').convert(result),
  );
}
