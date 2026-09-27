/// The file system of the user's files: `dart:io` on desktop and mobile,
/// none on the web (files are picked or dropped, never reached by path).
library;

export 'platform_fs_stub.dart'
    if (dart.library.io) 'platform_fs_io.dart'
    if (dart.library.js_interop) 'platform_fs_web.dart';
