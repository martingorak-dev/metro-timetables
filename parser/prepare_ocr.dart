import 'dart:io';

final timeRegex = RegExp(r'\b\d{1,2}:\d{2}\b');

// Stanice linky A
final stations = [
  "DEPO HOSTIVAŘ",
  "Skalka",
  "Strašnická",
  "Želivského",
  "Jiřího z Poděbrad",
  "Náměstí Míru",
  "Muzeum",
  "Můstek",
  "Staroměstská",
  "Malostranská",
  "Hradčanská",
  "Dejvická",
  "Bořislavka",
  "Nádraží Veleslavín",
  "Petřiny",
  "NEMOCNICE MOTOL"
];

bool isStationLine(String line) {
  final lower = line.toLowerCase();
  return stations.any((s) => lower.contains(s.toLowerCase()));
}

// Detekce intervalu i když je rozsekaný na 3 řádky
int? detectInterval(List<String> block) {
  for (int i = 0; i < block.length; i++) {
    final l = block[i].toLowerCase();

    if (l.contains("int.")) {
      // další řádek musí být číslo
      if (i + 1 < block.length) {
        final next = block[i + 1].trim();
        final num = int.tryParse(next);
        if (num != null) {
          // další řádek musí obsahovat "min"
          if (i + 2 < block.length &&
              block[i + 2].toLowerCase().contains("min")) {
            return num;
          }
        }
      }
    }
  }
  return null;
}

// Rozpoznání řádků, které patří k intervalu
bool isIntervalLine(String l) {
  final low = l.toLowerCase().trim();
  if (low == "int." || low == "min.") return true;
  if (int.tryParse(low) != null) return true;
  return false;
}

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print("Použití: dart run parser/prepare_ocr.dart A");
    return;
  }

  final line = args[0].toUpperCase();
  final inputPath = "ocr/$line.txt";
  final outputPath = "ocr_priprava/$line.txt";

  final input = File(inputPath);
  if (!input.existsSync()) {
    print("Soubor $inputPath neexistuje.");
    return;
  }

  final lines = input.readAsLinesSync();

  // Přesné fráze, které mají být odstraněny
  final bannedPhrases = [
    "Depo Hostivař – Nemocnice Motol",
    "Nemocnice Motol – Depo Hostivař",
    "Depo Hostivař - Nemocnice Motol",
    "Nemocnice Motol - Depo Hostivař",
    "Dopravní podnik",
    "Pokračování",
    "Vysvětlivky",
    "Legenda",
    "Metro A",
    "Strana",
    "Pracovní den",
    "jede v pracovních dnech",
    "Sokolovská 42/217",
    "sobota",
    "neděle",
    "jede v",
    "jízdní řád",
    "nemocnice motol -",
  ];

  final filtered = <String>[];

  // 1) Filtr balastu
  for (final lineText in lines) {
    final lower = lineText.toLowerCase();

    bool skip = false;

    // Smazat řádek, který obsahuje JEN "A"
    if (lineText.trim() == "A") skip = true;

    for (final phrase in bannedPhrases) {
      if (lower.contains(phrase.toLowerCase())) {
        skip = true;
        break;
      }
    }

    if (!skip) filtered.add(lineText);
  }

  // 2) Rozdělení na bloky podle výskytu stanic
  final blocks = <List<String>>[];
  List<String> current = [];

  for (final l in filtered) {
    if (isStationLine(l) && current.isNotEmpty) {
      blocks.add(current);
      current = [];
    }
    current.add(l);
  }
  if (current.isNotEmpty) blocks.add(current);

  // 3) Zpracování intervalů v blocích
  final output = <String>[];

  for (final block in blocks) {
    final interval = detectInterval(block);

    for (final l in block) {
      // Smazat řádky patřící k intervalu
      if (isIntervalLine(l)) continue;

      if (interval != null) {
        final times = timeRegex.allMatches(l).toList();

        if (times.length >= 2) {
          final firstEnd = times[0].end;
          final secondStart = times[1].start;

          final before = l.substring(0, firstEnd);
          final after = l.substring(secondStart);

          output.add("$before   INT $interval   $after");
          continue;
        }
      }

      output.add(l);
    }
  }

  Directory("ocr_priprava").createSync(recursive: true);
  File(outputPath).writeAsStringSync(output.join("\n"));

  print("Hotovo → $outputPath");
}
