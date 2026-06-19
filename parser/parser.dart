import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  print("MetroBuddy OCR parser starting...");

  final input = File('../ocr/output.txt');
  if (!input.existsSync()) {
    print("OCR output not found: ${input.path}");
    return;
  }

  final text = await input.readAsString();
  final lines = text.split('\n').map((l) => l.trim()).toList();

  final stationNames = <String>[];
  final directions = <String>[];
  final times = <String>[];

  final timeRegex = RegExp(r'\b\d{1,2}[:.]\d{2}\b');

  for (final line in lines) {
    if (line.isEmpty) continue;

    // Stanice – většinou velká písmena
    if (RegExp(r'^[A-ZÁČĎÉĚÍŇÓŘŠŤÚŮÝŽ ]+$').hasMatch(line) &&
        line.length > 3 &&
        !line.contains("SMĚR")) {
      stationNames.add(line);
      continue;
    }

    // Směr
    if (line.toUpperCase().contains("SMĚR")) {
      directions.add(line);
      continue;
    }

    // Časy
    final matches = timeRegex.allMatches(line);
    for (final m in matches) {
      var t = m.group(0)!;
      t = t.replaceAll('.', ':'); // OCR někdy dává tečku
      if (t.length == 4) {
        t = "0$t"; // 432 → 04:32
      }
      times.add(t);
    }
  }

  final output = {
    "stations": stationNames,
    "directions": directions,
    "times": times,
  };

  final outFile = File('../json/output.json');
  outFile.writeAsStringSync(JsonEncoder.withIndent('  ').convert(output));

  print("JSON saved to json/output.json");
}
