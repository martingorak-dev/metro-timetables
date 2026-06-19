import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  print("MetroBuddy PDF parser starting...");

  final input = File('ocr/output.txt');
  if (!input.existsSync()) {
    print("Text output not found: ${input.path}");
    return;
  }

  final text = await input.readAsString();
  final lines = text.split('\n');

  final stationRegex = RegExp(r'^[A-Za-zÁČĎÉĚÍŇÓŘŠŤÚŮÝŽáčďéěíňóřšťúůýž ]{3,}');
  final timeRegex = RegExp(r'\b\d{1,2}:\d{2}\b');

  // Seznam stanic – směr ZPĚT (A → B → C)
  final backwardStations = [
    "NEMOCNICE MOTOL",
    "Petřiny",
    "Nádraží Veleslavín",
    "Bořislavka",
    "Dejvická",
    "Hradčanská",
    "Malostranská",
    "Staroměstská",
    "Můstek - A",
    "Muzeum - A",
    "Náměstí Míru",
    "Jiřího z Poděbrad",
    "Želivského",
    "Strašnická",
    "Skalka",
    "DEPO HOSTIVAŘ"
  ];

  // Směr TAM = obrácený seznam
  final forwardStations = backwardStations.reversed.toList();

  final Map<String, dynamic> output = {
    "line": "A",
    "directions": {
      "forward": <String, Map<String, List<String>>>{},
      "backward": <String, Map<String, List<String>>>{},
    }
  };

  String? currentDirection; // "forward" / "backward"
  int dayIndexForward = 0;  // 0=weekday, 1=saturday, 2=sunday
  int dayIndexBackward = 0;

  String dayName(int index) =>
      index == 0 ? "weekday" : index == 1 ? "saturday" : "sunday";

  bool hasForwardData = false;
  bool hasBackwardData = false;

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    final match = stationRegex.matchAsPrefix(line);
    if (match == null) continue;

    final stationName = match.group(0)!.trim();
    final times = timeRegex.allMatches(line).map((m) => m.group(0)!).toList();
    if (times.isEmpty) continue;

    // 🔥 Robustní detekce směru podle seznamu stanic
    if (forwardStations.contains(stationName)) {
      // Pokud jsme byli v backward a vidíme forward → přepnout
      if (currentDirection == "backward") {
        // nový den začíná jen pokud první čas je 4:xx
        if (times.first.startsWith("4:") && dayIndexForward < 2) {
          dayIndexForward++;
        }
      }
      currentDirection = "forward";
      hasForwardData = true;
    } else if (backwardStations.contains(stationName)) {
      // Pokud jsme byli v forward a vidíme backward → přepnout
      if (currentDirection == "forward") {
        if (times.first.startsWith("4:") && dayIndexBackward < 2) {
          dayIndexBackward++;
        }
      }
      currentDirection = "backward";
      hasBackwardData = true;
    } else {
      // Stanice není v seznamu → ignorovat
      continue;
    }

    final directions = output["directions"] as Map<String, dynamic>;
    final directionMap =
    directions[currentDirection] as Map<String, Map<String, List<String>>>;

    final day = currentDirection == "forward"
        ? dayName(dayIndexForward)
        : dayName(dayIndexBackward);

    directionMap.putIfAbsent(stationName, () => {
      "weekday": <String>[],
      "saturday": <String>[],
      "sunday": <String>[],
    });

    directionMap[stationName]![day]!.addAll(times);
  }

  final directions = output["directions"] as Map<String, dynamic>;
  final forwardMap =
  directions["forward"] as Map<String, Map<String, List<String>>>;
  final backwardMap =
  directions["backward"] as Map<String, Map<String, List<String>>>;

  final forwardList = forwardMap.entries
      .map((e) => {
    "station": e.key,
    "weekday": e.value["weekday"],
    "saturday": e.value["saturday"],
    "sunday": e.value["sunday"],
  })
      .toList();

  final backwardList = backwardMap.entries
      .map((e) => {
    "station": e.key,
    "weekday": e.value["weekday"],
    "saturday": e.value["saturday"],
    "sunday": e.value["sunday"],
  })
      .toList();

  final finalOutput = {
    "line": "A",
    "directions": {
      "forward": forwardList,
      "backward": backwardList,
    }
  };

  final outFile = File('json/A.json');
  outFile.writeAsStringSync(JsonEncoder.withIndent('  ').convert(finalOutput));

  print("JSON saved to json/A.json");
}
