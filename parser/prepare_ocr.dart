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

// 1) Nahrazení mezer pomlčkami (jen tam, kde chceme)
String replaceSpacesWithDashes(String line) {
  final matches = timeRegex.allMatches(line).toList();

  if (matches.isEmpty) {
    return line.replaceAll(' ', '-');
  }

  final chars = line.split('');

  // Od začátku řádku po první čas
  for (int i = 0; i < matches.first.start; i++) {
    if (chars[i] == ' ') chars[i] = '-';
  }

  // Mezi jednotlivými časy
  for (int i = 0; i < matches.length - 1; i++) {
    final endOfThis = matches[i].end;
    final startOfNext = matches[i + 1].start;

    for (int j = endOfThis; j < startOfNext; j++) {
      if (chars[j] == ' ') chars[j] = '-';
    }
  }

  return chars.join('');
}

// 2) Pomlčky před názvem stanice → zpět na mezery
String restoreLeadingSpaces(String line) {
  final chars = line.split('');
  int i = 0;

  while (i < chars.length && chars[i] == '-') {
    i++;
  }

  for (int j = 0; j < i; j++) {
    chars[j] = ' ';
  }

  return chars.join('');
}

// 3) Odstranění slov „int.“ a „min.“ (ne celého řádku!)
String removeIntervalWords(String line) {
  return line
      .replaceAll("int.", "")
      .replaceAll("min.", "")
      .replaceAll("INT.", "")
      .replaceAll("MIN.", "");
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

  // 3) Nahrazení mezer pomlčkami + vrácení pomlček před názvem na mezery + odstranění "int." a "min."
  final output = <String>[];

  for (final block in blocks) {
    for (final l in block) {
      final dashed = replaceSpacesWithDashes(l);
      final restored = restoreLeadingSpaces(dashed);
      final cleaned = removeIntervalWords(restored);
      output.add(cleaned);
    }
  }

  Directory("ocr_priprava").createSync(recursive: true);
  File(outputPath).writeAsStringSync(output.join("\n"));

  print("Hotovo → $outputPath");
}
