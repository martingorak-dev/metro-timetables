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

  // 1) Zahodíme prvních 6 řádků
  const skipLines = 6;

  // 2) Odstraníme prvních 18 znaků z každého dalšího řádku
  const cutChars = 18;

  final cleaned = <String>[];

  for (int i = 0; i < lines.length; i++) {
    if (i < skipLines) continue;

    var lineText = lines[i];

    if (lineText.length > cutChars) {
      lineText = lineText.substring(cutChars);
    } else {
      lineText = "";
    }

    cleaned.add(lineText);
  }

  Directory("ocr_priprava").createSync(recursive: true);
  File(outputPath).writeAsStringSync(cleaned.join("\n"));

  print("KROK 1B hotový → $outputPath");
}
