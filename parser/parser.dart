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

  final timeRegex = RegExp(r'\b\d{1,2}:\d{2}\b');

  const station = "DEPO HOSTIVAŘ";

  final Map<String, dynamic> result = {
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

  final forward =
  (result["directions"] as Map<String, dynamic>)["forward"] as Map<String, List<String>>;
  final backward =
  (result["directions"] as Map<String, dynamic>)["backward"] as Map<String, List<String>>;

  int depoCount = 0; // kolikrát jsme narazili na DEPO
  int dayIndexForward = 0;
  int dayIndexBackward = 0;

  bool hasForwardTimes = false;
  bool hasBackwardTimes = false;

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (!line.contains(station)) continue;

    final times = timeRegex.allMatches(line).map((m) => m.group(0)!).toList();
    if (times.isEmpty) continue;

    depoCount++;

    // určení směru podle pořadí výskytů
    bool isForward = depoCount <= 3;
    bool isBackward = depoCount > 3;

    // přepnutí dne – jen v rámci stejného směru
    if (times.first.startsWith("4:")) {
      if (isForward && hasForwardTimes && dayIndexForward < 2) {
        dayIndexForward++;
      }
      if (isBackward && hasBackwardTimes && dayIndexBackward < 2) {
        dayIndexBackward++;
      }
    }

    if (isForward) {
      if (dayIndexForward == 0) forward["weekday"]!.addAll(times);
      if (dayIndexForward == 1) forward["saturday"]!.addAll(times);
      if (dayIndexForward == 2) forward["sunday"]!.addAll(times);
      hasForwardTimes = true;
    } else {
      if (dayIndexBackward == 0) backward["weekday"]!.addAll(times);
      if (dayIndexBackward == 1) backward["saturday"]!.addAll(times);
      if (dayIndexBackward == 2) backward["sunday"]!.addAll(times);
      hasBackwardTimes = true;
    }
  }

  final outFile = File('json/A.json');
  outFile.writeAsStringSync(JsonEncoder.withIndent('  ').convert(result));

  print("JSON saved to json/A.json");
}
