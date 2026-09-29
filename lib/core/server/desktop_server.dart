import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class DesktopServer {
  Process? _process;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  String? _findBinary(String? customPath) {
    final isWin = Platform.isWindows;
    final binaryName = isWin ? 'seanime.exe' : 'seanime';
    final exeDir = Platform.resolvedExecutable.replaceAll(RegExp(r'[^/\\]+$'), '');

    final candidatePaths = [
      if (customPath != null && customPath.isNotEmpty) ...[
        customPath,
        if (isWin && !customPath.toLowerCase().endsWith('.exe')) '$customPath.exe',
      ],
      './backend/$binaryName',
      './backend/seanime',
      '${Directory.current.path}/backend/$binaryName',
      '${Directory.current.path}/backend/seanime',
      '$exeDir$binaryName',
      '${exeDir}backend/$binaryName',
      '${exeDir}seanime',
      '${exeDir}backend/seanime',
      './$binaryName',
      './seanime',
    ];

    for (final path in candidatePaths) {
      if (File(path).existsSync()) {
        return path;
      }
    }
    return null;
  }

  Future<bool> start({
    String? executablePath,
    int port = 43211,
    String? dataDir,
  }) async {
    if (_isRunning) return true;

    final resolvedBinary = _findBinary(executablePath);
    if (resolvedBinary == null) {
      debugPrint('DesktopServer: Executable seanime not found in candidate paths');
      return false;
    }

    try {
      final args = <String>[
        '--desktop-sidecar',
        '--disable-password',
        '--port', port.toString(),
        '--host', '127.0.0.1',
        if (dataDir != null) ...['--datadir', dataDir],
      ];

      debugPrint('DesktopServer: Launching $resolvedBinary with args: $args');
      final env = Map<String, String>.from(Platform.environment);
      env['GOMEMLIMIT'] = '512MiB';
      env['GODEBUG'] = 'madvdontneed=1';

      _process = await Process.start(
        resolvedBinary,
        args,
        environment: env,
      );
      _isRunning = true;

      _process!.stdout.transform(utf8.decoder).listen((data) {
        debugPrint('[Seanime Server]: $data');
      });

      _process!.stderr.transform(utf8.decoder).listen((data) {
        debugPrint('[Seanime Server ERR]: $data');
      });

      _process!.exitCode.then((code) {
        debugPrint('[Seanime Server] Process exited with code: $code');
        _isRunning = false;
        _process = null;
      });

      return true;
    } catch (e) {
      debugPrint('DesktopServer start error: $e');
      _isRunning = false;
      return false;
    }
  }

  Future<void> stop() async {
    if (_process != null) {
      if (Platform.isWindows) {
        _process!.kill();
      } else {
        _process!.kill(ProcessSignal.sigterm);
        await Future.delayed(const Duration(milliseconds: 500));
        if (_process != null) {
          _process!.kill(ProcessSignal.sigkill);
        }
      }
      _process = null;
      _isRunning = false;
    }
  }
}
