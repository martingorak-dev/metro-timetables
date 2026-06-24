import 'dart:io';

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
    "A",
    "sobota",
    "neděle",
    "jede v",
    "jízdní řád",
  ];

  final cleaned = <String>[];

  for (final lineText in lines) {
    final lower = lineText.toLowerCase();

    bool skip = false;
    for (final phrase in bannedPhrases) {
      if (lower.contains(phrase.toLowerCase())) {
        skip = true;
        break;
      }
    }

    if (!skip) cleaned.add(lineText);
  }

  Directory("ocr_priprava").createSync(recursive: true);
  File(outputPath).writeAsStringSync(cleaned.join("\n"));

  print("Hotovo → $outputPath");
}
