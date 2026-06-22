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

  // Pro pohodlný přístup si to vytáhneme do proměnných s přesným typem
  final forward =
  (result["directions"] as Map<String, dynamic>)["forward"] as Map<String, List<String>>;
  final backward =
  (result["directions"] as Map<String, dynamic>)["backward"] as Map<String, List<String>>;

  int blockIndex = 0; // 0–2 = TAM, 3–5 = ZPĚT
  bool hasAnyTimesInCurrentBlock = false;

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (!line.contains(station)) continue;

    final times = timeRegex.allMatches(line).map((m) => m.group(0)!).toList();
    if (times.isEmpty) continue;

    // první čas 4:xx → může znamenat nový blok
    if (times.first.startsWith("4:")) {
      if (hasAnyTimesInCurrentBlock && blockIndex < 5) {
        blockIndex++;
        hasAnyTimesInCurrentBlock = false;
      }
    }

    if (blockIndex <= 2) {
      // TAM
      if (blockIndex == 0) {
        forward["weekday"]!.addAll(times);
      } else if (blockIndex == 1) {
        forward["saturday"]!.addAll(times);
      } else if (blockIndex == 2) {
        forward["sunday"]!.addAll(times);
      }
    } else {
      // ZPĚT
      if (blockIndex == 3) {
        backward["weekday"]!.addAll(times);
      } else if (blockIndex == 4) {
        backward["saturday"]!.addAll(times);
      } else if (blockIndex == 5) {
        backward["sunday"]!.addAll(times);
      }
    }

    hasAnyTimesInCurrentBlock = true;
  }

  final outFile = File('json/A.json');
  outFile.writeAsStringSync(JsonEncoder.withIndent('  ').convert(result));

  print("JSON saved to json/A.json");
}
