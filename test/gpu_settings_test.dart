import 'package:flutter_test/flutter_test.dart';
import 'package:aniting/core/player/renderer_info.dart';
import 'package:aniting/data/models/gpu_settings.dart';

void main() {
  group('GpuSettings.fromJson', () {
    test('parses the backend payload', () {
      final settings = GpuSettings.fromJson({
        'gpus': [
          {
            'name': 'NVIDIA GeForce RTX 3050 Ti Laptop GPU',
            'vendor': 'NVIDIA',
            'dedicated': true,
          },
          {
            'name': 'Intel(R) UHD Graphics',
            'vendor': 'Intel Corporation',
            'dedicated': false,
          },
        ],
        'preference': 'high',
        'canSetPreference': true,
        'executablePath': r'C:\Apps\aniting.exe',
        'note': 'restart required',
      });

      expect(settings.gpus.length, 2);
      expect(settings.preference, GpuPreference.high);
      expect(settings.canSetPreference, isTrue);
      expect(settings.hasDedicatedGpu, isTrue);
      expect(settings.dedicatedGpu?.name, contains('RTX 3050'));
      expect(settings.note, 'restart required');
    });

    test('skips nameless adapters and tolerates missing fields', () {
      final settings = GpuSettings.fromJson({
        'gpus': [
          {'name': ''},
          {'vendor': 'Intel'},
          {'name': 'Intel(R) UHD Graphics'},
        ],
      });

      expect(settings.gpus.length, 1);
      expect(settings.preference, GpuPreference.auto);
      expect(settings.canSetPreference, isFalse);
      expect(settings.hasDedicatedGpu, isFalse);
    });
  });

  group('ingestMpvLogLine', () {
    setUp(resetRendererInfo);
    tearDown(resetRendererInfo);

    test('captures vendor and renderer from real mpv log lines', () {
      // Lines taken verbatim from `mpv --msg-level=vo/gpu=debug`.
      expect(ingestMpvLogLine("[vo/gpu] GL_VERSION='3.0.0 - Build 32'"), isFalse);
      ingestMpvLogLine("[vo/gpu] GL_VENDOR='Intel'");
      final captured = ingestMpvLogLine(
        "[vo/gpu] GL_RENDERER='Intel(R) UHD Graphics'",
      );

      expect(captured, isTrue);
      final info = activeRenderer.value;
      expect(info, isNotNull);
      expect(info!.renderer, 'Intel(R) UHD Graphics');
      expect(info.vendor, 'Intel');
      expect(info.label, 'Intel(R) UHD Graphics');
    });

    test('ignores unrelated lines', () {
      expect(ingestMpvLogLine('[vo/gpu] Loaded extension GL_ARB_sync.'), isFalse);
      expect(activeRenderer.value, isNull);
    });

    test('appends the vendor when the renderer does not include it', () {
      ingestMpvLogLine("[vo/gpu] GL_VENDOR='NVIDIA Corporation'");
      ingestMpvLogLine("[vo/gpu] GL_RENDERER='RTX 3050 Ti'");

      expect(activeRenderer.value!.label, 'RTX 3050 Ti (NVIDIA Corporation)');
    });
  });
}
