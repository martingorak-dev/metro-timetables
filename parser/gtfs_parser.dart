import 'dart:io';
import 'dart:convert';

void main() async {
  final buffer = StringBuffer();

  buffer.writeln("=== GTFS PARSER DEBUG OUTPUT ===");

  // Check folder
  final dir = Directory('PID_GTFS');
  if (!dir.existsSync()) {
    buffer.writeln("ERROR: PID_GTFS folder not found.");
    await File('debug_output.txt').writeAsString(buffer.toString());
    return;
  }

  buffer.writeln("PID_GTFS folder found.");
  buffer.writeln("");

  // List all GTFS files
  buffer.writeln("Files in PID_GTFS:");
  for (var file in dir.listSync()) {
    if (file is File) {
      buffer.writeln(" - ${file.path} (${file.lengthSync()} bytes)");
    }
  }

  buffer.writeln("");

  // Example: read routes.txt
  final routesFile = File('PID_GTFS/routes.txt');
  if (routesFile.existsSync()) {
    buffer.writeln("routes.txt exists, reading first 5 lines:");
    final lines = routesFile.readAsLinesSync();
    for (int i = 0; i < 5 && i < lines.length; i++) {
      buffer.writeln(lines[i]);
    }
  } else {
    buffer.writeln("routes.txt NOT FOUND");
  }

  buffer.writeln("");
  buffer.writeln("=== END ===");

  await File('debug_output.txt').writeAsString(buffer.toString());
}
