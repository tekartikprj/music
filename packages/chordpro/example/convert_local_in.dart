import 'dart:io';

import 'package:path/path.dart';
import 'package:tekaly_chordpro/chordpro.dart';

Future<void> main() async {
  var srcIn = join('.local', 'in');
  var dstOut = join('.local', 'out');
  await Directory(dstOut).create(recursive: true);
  var files = await Directory(srcIn)
      .list()
      .map((event) => basename(event.path))
      .where((event) => extension(event) == '.txt')
      .toList();
  print(files);
  for (var file in files) {
    var lines = await File(join(srcIn, file)).readAsLines();
    var outLines = textLinesToChordProLines(lines);
    await File(join(dstOut, file)).writeAsString(outLines.join('\n'));
  }
}
