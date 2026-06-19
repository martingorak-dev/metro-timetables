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

    // Určení směru + přepínání dne
    if (stationName == firstForwardStation) {
      if (hasForwardData && times.first.startsWith("4:") && dayIndexForward < 2) {
        dayIndexForward++;
      }
      currentDirection = "forward";
      hasForwardData = true;
    } else if (stationName == firstBackwardStation) {
      if (hasBackwardData && times.first.startsWith("4:") && dayIndexBackward < 2) {
        dayIndexBackward++;
      }
      currentDirection = "backward";
      hasBackwardData = true;
    }

    if (currentDirection == null) continue;

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
