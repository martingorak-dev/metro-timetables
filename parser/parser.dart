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

  final forward =
  (result["directions"] as Map<String, dynamic>)["forward"] as Map<String, List<String>>;
  final backward =
  (result["directions"] as Map<String, dynamic>)["backward"] as Map<String, List<String>>;

  int fourRowCount = 0;      // kolikátý řádek Depa začínající 4:xx
  String direction = "forward";
  int dayIndex = 0;          // 0=weekday,1=saturday,2=sunday

  for (final line in lines) {
    if (!line.contains(station)) continue;

    final times = timeRegex.allMatches(line).map((m) => m.group(0)!).toList();
    if (times.isEmpty) continue;

    final first = times.first;

    // pokud řádek Depa začíná 4:xx → posuneme se v „mapě“ (TAM/ZPĚT × den)
    if (first.startsWith("4:")) {
      fourRowCount++;

      if (fourRowCount >= 1 && fourRowCount <= 3) {
        direction = "forward";
        dayIndex = fourRowCount - 1; // 1→0, 2→1, 3→2
      } else if (fourRowCount >= 4 && fourRowCount <= 6) {
        direction = "backward";
        dayIndex = fourRowCount - 4; // 4→0, 5→1, 6→2
      }
      // (kdyby tam bylo víc než 6, můžeš případně ošetřit, ale pro linku A to stačí)
    }

    // uložení časů podle aktuálního směru a dne
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
