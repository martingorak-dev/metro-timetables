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

  // 1) zahodíme prvních 6 řádků
  const skipLines = 6;
  final cleaned = <String>[];

  for (int i = 0; i < lines.length; i++) {
    if (i < skipLines) continue;

    var lineText = lines[i];

    // 2) odstraníme prvních 4 znaků (sloupce), pokud existují
    if (lineText.length > 4) {
      lineText = lineText.substring(4);
    } else {
      lineText = "";
    }

    cleaned.add(lineText);
  }

  Directory("ocr_priprava").createSync(recursive: true);
  File(outputPath).writeAsStringSync(cleaned.join("\n"));

  print("KROK 1 hotový → $outputPath");
}
