import 'dart:io';

// Normalizace textu
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

class TimePos {
  final int pos;
  final String value;
  TimePos(this.pos, this.value);
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

    // Začátek TAM
    if (n.contains(norm(stations.first))) {
      if (current.isNotEmpty) {
        if (inTam) tamBlocks.add(current);
        if (inZpet) zpetBlocks.add(current);
      }
      current = [];
      inTam = true;
      inZpet = false;
    }

    // Začátek ZPĚT
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

    // Konec TAM
    if (inTam && n.contains(norm(stations.last))) {
      tamBlocks.add(current);
      current = [];
      inTam = false;
    }

    // Konec ZPĚT
    if (inZpet && n.contains(norm(stations.first))) {
      zpetBlocks.add(current);
      current = [];
      inZpet = false;
    }
  }

  // -------------------------------
  // 2) Zpracování bloků → mřížka sloupců
  // -------------------------------
  Map<String, List<String>> processDirectionBlocks(
      List<List<String>> blocks,
      List<String> stationOrder,
      ) {
    // Výsledek pro všechny bloky slepené za sebe
    final result = {for (var s in stationOrder) s: <String>[]};

    const posThreshold = 3; // tolerance v pozici znaků
    const emptyToken = "-----";

    for (final block in blocks) {
      // 1) Nasbíráme časy s pozicemi pro všechny stanice v bloku
      final Map<String, List<TimePos>> stationTimes = {
        for (var s in stationOrder) s: []
      };

      String? currentStation;

      for (final line in block) {
        final ln = norm(line);

        // Detekce stanice na řádku
        for (int i = 0; i < stationOrder.length; i++) {
          if (ln.contains(stationsNorm[i])) {
            currentStation = stationOrder[i];
            break;
          }
        }

        if (currentStation == null) continue;

        // Časy na řádku
        for (final m in timeRegex.allMatches(line)) {
          stationTimes[currentStation]!.add(TimePos(m.start, m.group(0)!));
        }
      }

      // 2) Vytvoříme seznam všech pozic (mřížka sloupců)
      final List<int> allPositions = [];
      stationTimes.values.forEach((list) {
        for (final tp in list) {
          allPositions.add(tp.pos);
        }
      });

      if (allPositions.isEmpty) {
        // blok bez časů – přeskočíme
        continue;
      }

      allPositions.sort();

      // Sloučíme blízké pozice do jednoho sloupce
      final List<int> columnPositions = [];
      int groupStart = allPositions.first;
      int groupSum = allPositions.first;
      int groupCount = 1;

      for (int i = 1; i < allPositions.length; i++) {
        final p = allPositions[i];
        if (p - groupStart <= posThreshold) {
          groupSum += p;
          groupCount++;
        } else {
          columnPositions.add(groupSum ~/ groupCount);
          groupStart = p;
          groupSum = p;
          groupCount = 1;
        }
      }
      columnPositions.add(groupSum ~/ groupCount);

      // 3) Interval pro blok (pokud existuje)
      String? blockInterval;
      for (final line in block) {
        if (isIntervalLine(line)) {
          final x = extractInterval(line);
          if (x != null) {
            blockInterval = "INT $x";
            break;
          }
        }
      }

      // 4) Pro každou stanici naplníme sloupce
      for (final st in stationOrder) {
        final cols = <String>[];
        final times = stationTimes[st]!;

        for (final colPos in columnPositions) {
          // najdeme čas nejblíž tomuto sloupci
          TimePos? best;
          int bestDist = 1 << 30;

          for (final tp in times) {
            final d = (tp.pos - colPos).abs();
            if (d < bestDist && d <= posThreshold) {
              bestDist = d;
              best = tp;
            }
          }

          if (best != null) {
            cols.add(best.value);
          } else {
            cols.add(emptyToken);
          }
        }

        // Interval jako extra sloupec na konci bloku
        if (blockInterval != null) {
          cols.add(blockInterval);
        }

        result[st]!.addAll(cols);
      }
    }

    return result;
  }

  final tam = processDirectionBlocks(tamBlocks, stations);
  final zpet = processDirectionBlocks(zpetBlocks, stations.reversed.toList());

  // -------------------------------
  // 3) Zarovnání sloupců
  // -------------------------------
  const timeWidth = 5; // "hh:mm" nebo "-----"
  const intWidth = 6;  // "INT 10"

  String pad(String t) {
    if (t.startsWith("INT")) return t.padRight(intWidth);
    return t.padRight(timeWidth);
  }

  // -------------------------------
  // 4) Výstup
  // -------------------------------
  final out = StringBuffer();

  out.writeln("[TAM]");
  for (final st in stations) {
    final padded = tam[st]!.map(pad).join("    ");
    out.writeln("${st.padRight(20)} | $padded");
  }

  out.writeln("");
  out.writeln("[ZPET]");
  for (final st in stations.reversed) {
    final padded = zpet[st]!.map(pad).join("    ");
    out.writeln("${st.padRight(20)} | $padded");
  }

  Directory("ocr_priprava").createSync(recursive: true);
  File(outputPath).writeAsStringSync(out.toString());

  print("Vytvořeno: $outputPath");
}
