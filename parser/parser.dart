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

  // Linka A – směr ZPĚT (jak jsi poslal)
  const backwardStations = [
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

  // Směr TAM = obráceně
  final forwardStations = backwardStations.reversed.toList();

  const firstForwardStation = "DEPO HOSTIVAŘ";
  const firstBackwardStation = "NEMOCNICE MOTOL";

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

  bool hasForwardTimes = false;
  bool hasBackwardTimes = false;
  bool startedForward = false;
  bool startedBackward = false;

  String dayName(int index) =>
      index == 0 ? "weekday" : index == 1 ? "saturday" : "sunday";

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    final match = stationRegex.matchAsPrefix(line);
    if (match == null) continue;

    final stationName = match.group(0)!.trim();
    final times = timeRegex.allMatches(line).map((m) => m.group(0)!).toList();
    if (times.isEmpty) continue;

    // 1) začátek směru TAM – první DEPO HOSTIVAŘ
    if (stationName == firstForwardStation && !startedForward) {
      currentDirection = "forward";
      dayIndexForward = 0;
      startedForward = true;
    }

    // 2) začátek směru ZPĚT – první NEMOCNICE MOTOL po dokončení TAM
    if (stationName == firstBackwardStation && startedForward && !startedBackward) {
      currentDirection = "backward";
      dayIndexBackward = 0;
      startedBackward = true;
    }

    if (currentDirection == null) continue;

    // 3) přepínání dne – jen na první stanici směru a jen pokud už máme nějaké časy
    if (currentDirection == "forward" &&
        stationName == firstForwardStation &&
        times.first.startsWith("4:") &&
        hasForwardTimes &&
        dayIndexForward < 2) {
      dayIndexForward++;
    }

    if (currentDirection == "backward" &&
        stationName == firstBackwardStation &&
        times.first.startsWith("4:") &&
        hasBackwardTimes &&
        dayIndexBackward < 2) {
      dayIndexBackward++;
    }

    final directions = output["directions"] as Map<String, dynamic>;
    final directionMap =
    directions[currentDirection] as Map<String, Map<String, List<String>>>;

    final day = currentDirection == "forward"
        ? dayName(dayIndexForward)
        : dayName(dayIndexBackward);

    // jen stanice z našeho seznamu – aby se nic nenačetlo dvakrát / navíc
    if (currentDirection == "forward" &&
        !forwardStations.contains(stationName)) {
      continue;
    }
    if (currentDirection == "backward" &&
        !backwardStations.contains(stationName)) {
      continue;
    }

    directionMap.putIfAbsent(stationName, () => {
      "weekday": <String>[],
      "saturday": <String>[],
      "sunday": <String>[],
    });

    directionMap[stationName]![day]!.addAll(times);

    if (currentDirection == "forward") {
      hasForwardTimes = true;
    } else {
      hasBackwardTimes = true;
    }
  }

  final outFile = File('json/A.json');
  outFile.writeAsStringSync(JsonEncoder.withIndent('  ').convert(output));

  print("JSON saved to json/A.json");
}
