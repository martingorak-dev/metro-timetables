import 'dart:io';

final timeRegex = RegExp(r'\b\d{1,2}:\d{2}\b');
final intervalRegex = RegExp(r'int\.\s*(\d+)\s*min', caseSensitive: false);

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

  final cleaned = <String>[];

  // 1) Nejprve filtrujeme balast
  for (final lineText in lines) {
    final lower = lineText.toLowerCase();

    bool skip = false;

    // Smazat řádek, který obsahuje JEN "A"
    if (lineText.trim() == "A") {
      skip = true;
    }

    // Zakázané fráze
    for (final phrase in bannedPhrases) {
      if (lower.contains(phrase.toLowerCase())) {
        skip = true;
        break;
      }
    }

    if (!skip) cleaned.add(lineText);
  }

  // 2) Teď zpracujeme intervaly po blocích
  final output = <String>[];
  List<String> currentBlock = [];

  void flushBlock() {
    if (currentBlock.isEmpty) return;

    // Najdeme interval
    int? interval;
    for (final l in currentBlock) {
      final m = intervalRegex.firstMatch(l);
      if (m != null) {
        interval = int.parse(m.group(1)!);
        break;
      }
    }

    // Pokud není interval → jen přidáme blok
    if (interval == null) {
      output.addAll(currentBlock);
      currentBlock.clear();
      return;
    }

    // Jinak doplníme INT X mezi časové sloupce
    final newBlock = <String>[];

    for (final l in currentBlock) {
      // Přeskočíme samotný řádek s "int. X min."
      if (intervalRegex.hasMatch(l)) continue;

      final times = timeRegex.allMatches(l).toList();

      if (times.length < 2) {
        newBlock.add(l);
        continue;
      }

      // Najdeme pozici mezery mezi dvěma časy
      final firstEnd = times[0].end;
      final secondStart = times[1].start;

      final before = l.substring(0, firstEnd);
      final after = l.substring(secondStart);

      final newLine = "$before   INT $interval   $after";
      newBlock.add(newLine);
    }

    output.addAll(newBlock);
    currentBlock.clear();
  }

  // Rozdělení na bloky podle prázdných řádků
  for (final l in cleaned) {
    if (l.trim().isEmpty) {
      flushBlock();
      output.add("");
    } else {
      currentBlock.add(l);
    }
  }
  flushBlock();

  Directory("ocr_priprava").createSync(recursive: true);
  File(outputPath).writeAsStringSync(output.join("\n"));

  print("Hotovo → $outputPath");
}
