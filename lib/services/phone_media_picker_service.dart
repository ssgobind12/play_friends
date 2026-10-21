import 'package:flutter/services.dart';

class PhoneMediaPickerService {
  static const MethodChannel _channel = MethodChannel('com.playfriends.game_sound');

  /// Launches the native Android phone gallery to pick an actual profile photo.
  /// Returns the image as a Base64 data URI (data:image/jpeg;base64,...), or null if cancelled.
  static Future<String?> pickPhotoFromPhoneGallery() async {
    try {
      final dynamic result = await _channel.invokeMethod('pickPhotoFromGallery');
      if (result is String && result.isNotEmpty) {
        return result;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Launches the native Android phone storage / Audio picker to select an actual audio/music file (.mp3, .wav, .m4a).
  /// Returns a map with {'title': ..., 'path': ..., 'fileName': ...}, or null if cancelled.
  static Future<Map<String, String>?> pickMusicFromPhoneStorage() async {
    try {
      final dynamic result = await _channel.invokeMethod('pickMusicFromStorage');
      if (result is Map) {
        return Map<String, String>.from(result);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Plays a real local audio file via Android MediaPlayer
  static Future<void> playAudioFile(String path, {double volume = 0.8}) async {
    try {
      await _channel.invokeMethod('playAudioFile', {
        'path': path,
        'volume': volume,
      });
    } catch (_) {}
  }

  /// Pauses the Android MediaPlayer
  static Future<void> pauseAudioFile() async {
    try {
      await _channel.invokeMethod('pauseAudioFile');
    } catch (_) {}
  }

  /// Minimizes the app to background instead of closing or destroying the activity
  static Future<void> minimizeApp() async {
    try {
      await _channel.invokeMethod('minimizeApp');
    } catch (_) {}
  }

  /// Stops the Android MediaPlayer
  static Future<void> stopAudioFile() async {
    try {
      await _channel.invokeMethod('stopAudioFile');
    } catch (_) {}
  }

  /// Adjusts the Android MediaPlayer volume
  static Future<void> setMusicVolume(double volume) async {
    try {
      await _channel.invokeMethod('setMusicVolume', {
        'volume': volume,
      });
    } catch (_) {}
  }
}
