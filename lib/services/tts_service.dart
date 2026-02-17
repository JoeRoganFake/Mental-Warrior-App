import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'audio_cache.dart';
import 'hash_utils.dart';

class TTSService {
  final String apiKey = 'a014e7451ad71c9b635fae2d748a5c629ecec2b664241b2999feef2f0b425664';
  final String voiceId = 'JBFqnCBsd6RMkjVDRZzb';

  /// Returns the File of the audio, generating if necessary
  Future<File> getOrCreateAudio(String sentence) async {
    final hash = HashUtils.sentenceHash(
      text: sentence,
      voiceId: voiceId,
      speed: 0.9,
      pitch: -1,
    );

    final cacheDir = await AudioCacheService.getAudioCacheDir();
final file = File('${cacheDir.path}/$hash.mp3');


    if (await file.exists()) {
      return file;
    }

    final audioBytes = await _generateAudio(sentence);
    await file.writeAsBytes(audioBytes);
    return file;
  }

Future<List<int>> _generateAudio(String text) async {
  final trimmedText = text.trim();
  if (trimmedText.isEmpty) {
    throw Exception('Cannot generate empty sentence');
  }

  final url = 'https://api.elevenlabs.io/v1/text-to-speech/$voiceId';
  final response = await http.post(
    Uri.parse(url),
    headers: {
      'xi-api-key': apiKey,
      'Content-Type': 'application/json'
    },
    body: jsonEncode({
      'text': trimmedText,
        'model_id': 'eleven_turbo_v2',
      'voice_settings': {'stability': 0.8, 'similarity_boost': 0.4}
    }),
  );

  if (response.statusCode != 200) {
    print('Response body: ${response.body}');
    throw Exception('TTS generation failed: ${response.statusCode}');
  }

  return response.bodyBytes;
}

}
