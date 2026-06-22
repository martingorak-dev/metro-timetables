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

  String? currentDirection; // forward / backward
  int currentDay = 0;       // 0=weekday, 1=saturday, 2=sunday

  String dayName(int i) =>
      i == 0 ? "weekday" : i == 1 ? "saturday" : "sunday";

  bool startedForward = false;
  bool startedBackward = false;

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    final match = stationRegex.matchAsPrefix(line);
    if (match == null) continue;

    final stationName = match.group(0)!.trim();
    final times = timeRegex.allMatches(line).map((m) => m.group(0)!).toList();
    if (times.isEmpty) continue;

    // 1) ZAČÁTEK SMĚRU TAM
    if (stationName == firstForwardStation && !startedForward) {
      currentDirection = "forward";
      currentDay = 0;
      startedForward = true;
    }

    // 2) ZAČÁTEK SMĚRU ZPĚT
    if (stationName == firstBackwardStation && startedForward && !startedBackward) {
      currentDirection = "backward";
      currentDay = 0;
      startedBackward = true;
    }

    if (currentDirection == null) continue;

    // 3) PŘEPNUTÍ DNE — pouze když jsme na první stanici směru
    if ((stationName == firstForwardStation && currentDirection == "forward") ||
        (stationName == firstBackwardStation && currentDirection == "backward")) {
      if (times.first.startsWith("4:") && currentDay < 2) {
        currentDay++;
      }
    }

    final directionMap =
    output["directions"][currentDirection] as Map<String, Map<String, List<String>>>;

    directionMap.putIfAbsent(stationName, () => {
      "weekday": <String>[],
      "saturday": <String>[],
      "sunday": <String>[],
    });

    directionMap[stationName]![dayName(currentDay)]!.addAll(times);
  }

  final outFile = File('json/A.json');
  outFile.writeAsStringSync(JsonEncoder.withIndent('  ').convert(output));

  print("JSON saved to json/A.json");
}
