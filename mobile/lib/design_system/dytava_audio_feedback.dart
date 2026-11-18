import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'dytava_audio_io.dart'
    if (dart.library.js_interop) 'dytava_audio_web.dart';

enum DytavaSound {
  click,
  success,
  error,
  toast,
}

/// Dịch vụ phản hồi âm thanh và xúc giác (Haptics & Audio) chuẩn Dytava
class DytavaAudioFeedback {
  DytavaAudioFeedback._();

  static bool soundEnabled = true;

  /// Phát phản hồi khi click / tap tương tác
  static Future<void> playClick() async {
    if (!soundEnabled) return;
    try {
      if (kIsWeb) {
        playWebSynthSound('click');
      } else {
        await SystemSound.play(SystemSoundType.click);
        await HapticFeedback.selectionClick();
      }
    } catch (_) {}
  }

  /// Phát phản hồi thành công (Tải tệp thành công, hoàn thành đối chiếu)
  static Future<void> playSuccess() async {
    if (!soundEnabled) return;
    try {
      if (kIsWeb) {
        playWebSynthSound('success');
      } else {
        await HapticFeedback.mediumImpact();
        await SystemSound.play(SystemSoundType.click);
      }
    } catch (_) {}
  }

  /// Phát phản hồi khi có lỗi / cảnh báo
  static Future<void> playError() async {
    if (!soundEnabled) return;
    try {
      if (kIsWeb) {
        playWebSynthSound('error');
      } else {
        await HapticFeedback.heavyImpact();
        await SystemSound.play(SystemSoundType.alert);
      }
    } catch (_) {}
  }

  /// Phản hồi nhẹ khi Toast thông báo xuất hiện
  static Future<void> playToast() async {
    if (!soundEnabled) return;
    try {
      if (kIsWeb) {
        playWebSynthSound('toast');
      } else {
        await HapticFeedback.lightImpact();
        await SystemSound.play(SystemSoundType.click);
      }
    } catch (_) {}
  }
}
