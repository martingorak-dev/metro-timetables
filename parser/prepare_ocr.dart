import 'dart:io';

// Normalizace pro porovnávání
String norm(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

// Zjistí, zda řádek obsahuje název stanice
bool containsStation(String line, List<String> stationsNorm) {
  final n = norm(line);
  return stationsNorm.any((s) => n.contains(s));
}

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print("Použití: dart run parser/prepare_ocr.dart A");
    return;
  }

  final line = args[0].toUpperCase();
  final inputPath = "ocr/$line.txt";
  final outputPath = "ocr_priprava/$line.txt";

  // Seznam stanic pro linku A
  const stationsA = [
    "DEPO HOSTIVAŘ",
    "Skalka",
    "Strašnická",
    "Želivského",
    "Jiřího z Poděbrad",
    "Náměstí Míru",
    "Muzeum - A",
    "Můstek - A",
    "Staroměstská",
    "Malostranská",
    "Hradčanská",
    "Dejvická",
    "Bořislavka",
    "Nádraží Veleslavín",
    "Petřiny",
    "NEMOCNICE MOTOL"
  ];

  // TODO: doplnit B a C
  final stations = stationsA;
  final stationsNorm = stations.map(norm).toList();

  final input = File(inputPath);
  if (!input.existsSync()) {
    print("Soubor $inputPath neexistuje.");
    return;
  }

  final lines = input.readAsLinesSync();

  // -------------------------------
  // 1) Najdeme bloky podle první a poslední stanice
  // -------------------------------
  final firstStationNorm = norm(stations.first);
  final lastStationNorm = norm(stations.last);

  List<List<String>> blocks = [];
  List<String> current = [];

  for (final line in lines) {
    final n = norm(line);

    // Začátek bloku
    if (n.contains(firstStationNorm)) {
      if (current.isNotEmpty) {
        blocks.add(current);
        current = [];
      }
    }

    current.add(line);

    // Konec bloku
    if (n.contains(lastStationNorm)) {
      blocks.add(current);
      current = [];
    }
  }

  // -------------------------------
  // 2) Poskládáme bloky vedle sebe
  // -------------------------------
  // Výstupní struktura:
  // stanice → seznam všech časů z bloků
  final Map<String, List<String>> tam = {};
  final Map<String, List<String>> zpet = {};

  for (final st in stations) {
    tam[st] = [];
    zpet[st] = [];
  }

  for (final block in blocks) {
    for (final line in block) {
      final n = norm(line);

      // najdeme stanici
      for (int i = 0; i < stations.length; i++) {
        final st = stations[i];
        if (n.contains(norm(st))) {
          // extrahujeme časy
          final times = RegExp(r'\b\d{1,2}:\d{2}\b')
              .allMatches(line)
              .map((m) => m.group(0)!)
              .toList();

          // směr TAM = stanice v normálním pořadí
          // směr ZPĚT = stanice v opačném pořadí
          tam[st]!.addAll(times);
          zpet[stations[stations.length - 1 - i]]!.addAll(times);
        }
      }
    }
  }

  // -------------------------------
  // 3) Uložíme výsledek
  // -------------------------------
  final out = StringBuffer();

  out.writeln("[TAM]");
  for (final st in stations) {
    out.writeln("$st | ${tam[st]!.join(' ')}");
  }

  out.writeln("");
  out.writeln("[ZPET]");
  for (final st in stations.reversed) {
    out.writeln("$st | ${zpet[st]!.join(' ')}");
  }

  Directory("ocr_priprava").createSync(recursive: true);
  File(outputPath).writeAsStringSync(out.toString());

  print("Vytvořeno: $outputPath");
}
