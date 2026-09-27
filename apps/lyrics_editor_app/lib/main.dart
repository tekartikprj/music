import 'package:flutter/material.dart';
import 'package:lyrics_editor_app/src/app.dart';
import 'package:lyrics_editor_app/src/app_context.dart';
import 'package:lyrics_editor_app/src/platform/platform_fs.dart';
import 'package:tekaly_file_picker_flutter/file_picker_flutter.dart';
import 'package:tekartik_app_flutter_idb/sdb.dart';

/// The lyrics editor: open a lyrics file and its media, time the lyrics by
/// tapping along, save.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initTekalyFilePickerFlutter();
  var appContext = await LyricsAppContext.init(
    sdbFactory: getSdbFactory(packageName: 'com.tekartik.lyrics_editor'),
    fs: lyricsPlatformFileSystem,
  );
  runApp(LyricsEditorApp(appContext: appContext));
}
