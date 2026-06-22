import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  final input = File('ocr/output.txt');
  if (!input.existsSync()) return;

  final lines = input.readAsLinesSync();
  final timeRegex = RegExp(r'\b\d{1,2}:\d{2}\b');

  // OCR‑odolné hledání názvu stanice
  final stationPattern = RegExp(r'\bSkalka\b', caseSensitive: false);

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

  final forward =
  (result["directions"] as Map<String, dynamic>)["forward"] as Map<String, List<String>>;
  final backward =
  (result["directions"] as Map<String, dynamic>)["backward"] as Map<String, List<String>>;

  int dayStartCount = 0;     // kolikátý „den-start“ blok jsme viděli
  String direction = "forward";
  int dayIndex = 0;          // 0=weekday,1=saturday,2=sunday

  bool isDayStart(String t) =>
      t.startsWith("3:") || t.startsWith("4:") || t.startsWith("5:");

  for (final line in lines) {
    // OCR‑odolné hledání stanice
    if (!stationPattern.hasMatch(line)) continue;

    final times = timeRegex.allMatches(line).map((m) => m.group(0)!).toList();
    if (times.isEmpty) continue;

    final first = times.first;

    // pokud řádek začíná 3/4/5 → nový den
    if (isDayStart(first)) {
      dayStartCount++;

      if (dayStartCount <= 3) {
        direction = "forward";
        dayIndex = dayStartCount - 1; // 1→0, 2→1, 3→2
      } else if (dayStartCount <= 6) {
        direction = "backward";
        dayIndex = dayStartCount - 4; // 4→0, 5→1, 6→2
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
  }

  File('json/A.json').writeAsStringSync(
    JsonEncoder.withIndent('  ').convert(result),
  );
}
