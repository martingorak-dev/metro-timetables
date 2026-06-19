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

  final List<Map<String, dynamic>> stations = [];

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    // Najdeme název stanice (je vždy na začátku řádku)
    final match = stationRegex.matchAsPrefix(line);
    if (match == null) continue;

    final stationName = match.group(0)!.trim();

    // Extrahujeme časy
    final times = timeRegex.allMatches(line).map((m) => m.group(0)!).toList();

    if (times.isEmpty) continue;

    stations.add({
      "station": stationName,
      "times": times,
    });
  }

  final output = {
    "line": "A",
    "stations": stations,
  };

  final outFile = File('json/A.json');
  outFile.writeAsStringSync(JsonEncoder.withIndent('  ').convert(output));

  print("JSON saved to json/A.json");
}