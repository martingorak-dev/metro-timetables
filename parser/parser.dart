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

  String direction = "forward";        // začínáme TAM
  int forwardFourCount = 0;           // kolikrát jsme viděli DH s 4:xx v TAM
  int backwardFourCount = 0;          // kolikrát jsme viděli DH s 4:xx v ZPĚT
  int dayIndexForward = 0;            // 0=weekday,1=saturday,2=sunday
  int dayIndexBackward = 0;

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (!line.contains(station)) continue;

    final times = timeRegex.allMatches(line).map((m) => m.group(0)!).toList();
    if (times.isEmpty) continue;

    final first = times.first;

    // přepnutí směru: po dokončení TAM (3× 4:xx) a dalším DH bez 4:xx začíná ZPĚT
    if (direction == "forward" &&
        forwardFourCount == 3 &&
        !first.startsWith("4:")) {
      direction = "backward";
      dayIndexBackward = 0;
    }

    if (direction == "forward") {
      // počítáme DH řádky s 4:xx v TAM
      if (first.startsWith("4:")) {
        forwardFourCount++;
        if (forwardFourCount == 1) dayIndexForward = 0; // weekday
        if (forwardFourCount == 2) dayIndexForward = 1; // saturday
        if (forwardFourCount == 3) dayIndexForward = 2; // sunday
      }

      if (dayIndexForward == 0) {
        forward["weekday"]!.addAll(times);
      } else if (dayIndexForward == 1) {
        forward["saturday"]!.addAll(times);
      } else {
        forward["sunday"]!.addAll(times);
      }
    } else {
      // ZPĚT
      if (first.startsWith("4:")) {
        backwardFourCount++;
        if (backwardFourCount == 1) dayIndexBackward = 0; // weekday
        if (backwardFourCount == 2) dayIndexBackward = 1; // saturday
        if (backwardFourCount == 3) dayIndexBackward = 2; // sunday
      }

      if (dayIndexBackward == 0) {
        backward["weekday"]!.addAll(times);
      } else if (dayIndexBackward == 1) {
        backward["saturday"]!.addAll(times);
      } else {
        backward["sunday"]!.addAll(times);
      }
    }
  }

  final outFile = File('json/A.json');
  outFile.writeAsStringSync(JsonEncoder.withIndent('  ').convert(result));

  print("JSON saved to json/A.json");
}
