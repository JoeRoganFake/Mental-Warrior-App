import 'dart:convert';
import 'package:crypto/crypto.dart';

class HashUtils {
  static String sentenceHash({
    required String text,
    required String voiceId,
    double speed = 0.9,
    double pitch = -1,
  }) {
    final input = '$text|$voiceId|$speed|$pitch';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString(); // 64-character hex
  }
}
