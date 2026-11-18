import 'dart:js_interop';

@JS('eval')
external JSAny? _jsEval(String code);

void playWebSynthSound(String type) {
  try {
    final jsCode = '''
      (function() {
        try {
          var AudioCtx = window.AudioContext || window.webkitAudioContext;
          if (!AudioCtx) return;
          if (!window.__dytavaAudioCtx) {
            window.__dytavaAudioCtx = new AudioCtx();
          }
          var ctx = window.__dytavaAudioCtx;
          if (ctx.state === 'suspended') {
            ctx.resume();
          }
          var now = ctx.currentTime;
          var osc = ctx.createOscillator();
          var gain = ctx.createGain();
          osc.connect(gain);
          gain.connect(ctx.destination);

          if ('$type' === 'success') {
            // Chuông 2 nốt trong sáng: 523.25Hz (C5) -> 659.25Hz (E5)
            osc.type = 'sine';
            osc.frequency.setValueAtTime(523.25, now);
            osc.frequency.exponentialRampToValueAtTime(659.25, now + 0.12);
            gain.gain.setValueAtTime(0.15, now);
            gain.gain.exponentialRampToValueAtTime(0.001, now + 0.35);
            osc.start(now);
            osc.stop(now + 0.35);
          } else if ('$type' === 'error') {
            // Âm cảnh báo: 220Hz -> 180Hz sawtooth mềm
            osc.type = 'triangle';
            osc.frequency.setValueAtTime(240, now);
            osc.frequency.exponentialRampToValueAtTime(160, now + 0.25);
            gain.gain.setValueAtTime(0.18, now);
            gain.gain.exponentialRampToValueAtTime(0.001, now + 0.3);
            osc.start(now);
            osc.stop(now + 0.3);
          } else if ('$type' === 'toast') {
            // Pop nhẹ: 587.33Hz (D5) -> 880Hz (A5)
            osc.type = 'sine';
            osc.frequency.setValueAtTime(587.33, now);
            osc.frequency.exponentialRampToValueAtTime(880, now + 0.08);
            gain.gain.setValueAtTime(0.12, now);
            gain.gain.exponentialRampToValueAtTime(0.001, now + 0.18);
            osc.start(now);
            osc.stop(now + 0.18);
          } else {
            // Click nhẹ: 800Hz decay siêu nhanh
            osc.type = 'sine';
            osc.frequency.setValueAtTime(800, now);
            gain.gain.setValueAtTime(0.08, now);
            gain.gain.exponentialRampToValueAtTime(0.001, now + 0.05);
            osc.start(now);
            osc.stop(now + 0.05);
          }
        } catch (e) {}
      })();
    ''';
    _jsEval(jsCode);
  } catch (_) {}
}
