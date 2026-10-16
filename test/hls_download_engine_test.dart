import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/downloads/hls_download_engine.dart';
import 'package:seanime_app/core/downloads/online_stream_downloader.dart';

Uint8List _hex(String value) {
  final clean = value.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
  final out = Uint8List(clean.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

String _toHex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('HlsDownloadEngine AES-128-CBC', () {
    // Vector generated with:
    //   openssl enc -aes-128-cbc -K <key> -iv <iv>
    const key = '000102030405060708090a0b0c0d0e0f';
    const iv = '101112131415161718191a1b1c1d1e1f';
    const plainText = '00112233445566778899aabbccddeeff';
    const cipherText =
        '1eca870ffea114b7fd6cf363c30b96b1'
        '0d47f7c33722bae48a4489a6bb9d993d';

    test('decrypts and strips PKCS7 padding', () {
      final result = HlsDownloadEngine.decryptAes128Cbc(
        _hex(cipherText),
        _hex(key),
        _hex(iv),
      );
      expect(_toHex(result), plainText);
    });

    test('rejects an invalid key length', () {
      expect(
        () => HlsDownloadEngine.decryptAes128Cbc(
          _hex(cipherText),
          _hex('0011'),
          _hex(iv),
        ),
        throwsA(isA<HlsDownloadException>()),
      );
    });

    test('derives the default IV from the media sequence (big-endian)', () {
      expect(_toHex(HlsDownloadEngine.sequenceIv(0)), '00000000000000000000000000000000');
      expect(
        _toHex(HlsDownloadEngine.sequenceIv(0x0102030405060708)),
        '00000000000000000102030405060708',
      );
    });
  });

  group('OnlineStreamDownloader.isValidMediaHeader', () {
    test('accepts MP4 (ftyp) and fMP4 (styp/moof)', () {
      expect(
        OnlineStreamDownloader.isValidMediaHeader(
          _hex('0000001c6674797069736f6d00000000'),
        ),
        isTrue,
      );
      expect(
        OnlineStreamDownloader.isValidMediaHeader(
          _hex('00000014737479700000000000000000'),
        ),
        isTrue,
      );
      expect(
        OnlineStreamDownloader.isValidMediaHeader(
          _hex('000000146d6f6f660000000000000000'),
        ),
        isTrue,
      );
    });

    test('accepts MPEG-TS when sync bytes line up', () {
      final ts = Uint8List(376)..fillRange(0, 376, 0x00);
      ts[0] = 0x47;
      ts[188] = 0x47;
      expect(OnlineStreamDownloader.isValidMediaHeader(ts), isTrue);
    });

    test('accepts Matroska (EBML magic)', () {
      expect(
        OnlineStreamDownloader.isValidMediaHeader(
          _hex('1a45dfa3a3a3a3a3a3a3a3a3'),
        ),
        isTrue,
      );
    });

    test('rejects encrypted garbage and short buffers', () {
      expect(
        OnlineStreamDownloader.isValidMediaHeader(
          _hex('81412221a5d4e0ff81412221a5d4e0ff'),
        ),
        isFalse,
      );
      expect(
        OnlineStreamDownloader.isValidMediaHeader(_hex('0000001c')),
        isFalse,
      );
    });
  });
}
