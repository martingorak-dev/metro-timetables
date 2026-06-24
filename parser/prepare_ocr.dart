import 'dart:io';

// Normalizace textu pro porovnávání
String norm(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

// Regex pro čas
final timeRegex = RegExp(r'\b\d{1,2}:\d{2}\b');

// Detekce intervalu
bool isIntervalLine(String line) {
  final n = norm(line);
  return n.contains("int") || n.contains("min") || RegExp(r'^\d+$').hasMatch(n);
}

// Extrakce čísla intervalu
String? extractInterval(String line) {
  final m = RegExp(r'\b(\d{1,2})\b').firstMatch(line);
  return m?.group(1);
}

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print("Použití: dart run parser/prepare_ocr.dart A");
    return;
  }

  final line = args[0].toUpperCase();
  final inputPath = "ocr/$line.txt";
  final outputPath = "ocr_priprava/$line.txt";

  // Stanice linky A
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

  final stations = stationsA;
  final stationsNorm = stations.map(norm).toList();

  final input = File(inputPath);
  if (!input.existsSync()) {
    print("Soubor $inputPath neexistuje.");
    return;
  }

  final lines = input.readAsLinesSync();

  // -------------------------------
  // 1) Najdeme bloky TAM a ZPĚT
  // -------------------------------
  List<List<String>> tamBlocks = [];
  List<List<String>> zpetBlocks = [];

  List<String> current = [];
  bool inTam = false;
  bool inZpet = false;

  for (final line in lines) {
    final n = norm(line);

    // Začátek TAM bloku
    if (n.contains(norm(stations.first))) {
      if (current.isNotEmpty) {
        if (inTam) tamBlocks.add(current);
        if (inZpet) zpetBlocks.add(current);
      }
      current = [];
      inTam = true;
      inZpet = false;
    }

    // Začátek ZPĚT bloku
    if (n.contains(norm(stations.last))) {
      if (current.isNotEmpty) {
        if (inTam) tamBlocks.add(current);
        if (inZpet) zpetBlocks.add(current);
      }
      current = [];
      inTam = false;
      inZpet = true;
    }

    current.add(line);

    // Konec TAM bloku
    if (inTam && n.contains(norm(stations.last))) {
      tamBlocks.add(current);
      current = [];
      inTam = false;
    }

    // Konec ZPĚT bloku
    if (inZpet && n.contains(norm(stations.first))) {
      zpetBlocks.add(current);
      current = [];
      inZpet = false;
    }
  }

  // -------------------------------
  // 2) Zpracujeme bloky → stanice → časy
  // -------------------------------
  Map<String, List<String>> tam = {for (var s in stations) s: []};
  Map<String, List<String>> zpet = {for (var s in stations.reversed) s: []};

  void processBlocks(List<List<String>> blocks, Map<String, List<String>> target) {
    for (final block in blocks) {
      for (final st in target.keys) {
        final stNorm = norm(st);

        // Najdeme řádky patřící ke stanici
        final stationLines = block.where((l) => norm(l).contains(stNorm)).toList();

        // Extrahujeme časy
        for (final l in stationLines) {
          final times = timeRegex.allMatches(l).map((m) => m.group(0)!).toList();
          target[st]!.addAll(times);

          // Intervaly
          if (isIntervalLine(l)) {
            final x = extractInterval(l);
            if (x != null) target[st]!.add("INT $x");
          }
        }
      }
    }
  }

  processBlocks(tamBlocks, tam);
  processBlocks(zpetBlocks, zpet);

  // -------------------------------
  // 3) Zarovnání sloupců
  // -------------------------------
  const timeWidth = 5; // např. "4:43 "
  const intWidth = 6;  // "INT 10"

  String padTime(String t) {
    if (t.startsWith("INT")) {
      return t.padRight(intWidth);
    }
    return t.padRight(timeWidth);
  }

  // -------------------------------
  // 4) Uložíme výsledek
  // -------------------------------
  final out = StringBuffer();

  out.writeln("[TAM]");
  for (final st in stations) {
    final padded = tam[st]!.map(padTime).join("    "); // 4 mezery
    out.writeln("${st.padRight(20)} | $padded");
  }

  out.writeln("");
  out.writeln("[ZPET]");
  for (final st in stations.reversed) {
    final padded = zpet[st]!.map(padTime).join("    ");
    out.writeln("${st.padRight(20)} | $padded");
  }

  Directory("ocr_priprava").createSync(recursive: true);
  File(outputPath).writeAsStringSync(out.toString());

  print("Vytvořeno: $outputPath");
}
