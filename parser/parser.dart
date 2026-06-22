import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  final input = File('ocr/output.txt');
  if (!input.existsSync()) return;

  final lines = input.readAsLinesSync();
  final timeRegex = RegExp(r'\b\d{1,2}:\d{2}\b');
  const station = "DEPO HOSTIVAŘ";

  final result = {
    "line": "A",
    "directions": {
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
    }
  };

  // bezpečné přetypování
  final forward = (result["directions"] as Map<String, dynamic>)["forward"]
  as Map<String, List<String>>;
  final backward = (result["directions"] as Map<String, dynamic>)["backward"]
  as Map<String, List<String>>;

  String direction = "forward"; // začínáme TAM
  int dayIndex = 0;             // 0=PD,1=SO,2=NE

  String? lastFirstTime;        // první čas předchozího bloku

  for (final line in lines) {
    if (!line.contains(station)) continue;

    final times = timeRegex.allMatches(line).map((m) => m.group(0)!).toList();
    if (times.isEmpty) continue;

    final first = times.first;

    // přepnutí dne: 4:xx po bloku, který nezačínal 4:xx
    if (first.startsWith("4:") &&
        lastFirstTime != null &&
        !lastFirstTime.startsWith("4:")) {
      dayIndex++;

      if (dayIndex == 3) {
        direction = "backward";
        dayIndex = 0;
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

    lastFirstTime = first;
  }

  File('json/A.json').writeAsStringSync(
    JsonEncoder.withIndent('  ').convert(result),
  );
}
