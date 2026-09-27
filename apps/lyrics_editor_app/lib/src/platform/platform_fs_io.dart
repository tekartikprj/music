import 'package:fs_shim/fs_io.dart';

/// The file system of the user's files, null when files have no path.
FileSystem? get lyricsPlatformFileSystem => fileSystemIo;
