import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<Directory> getAudioCacheDir() async {
  final dir = await getApplicationDocumentsDirectory();
  final audioDir = Directory('${dir.path}/audio_cache');

  if (!await audioDir.exists()) {
    await audioDir.create(recursive: true);
  }

  return audioDir;
}
