import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:seanime_app/core/constants/app_constants.dart';
import 'package:seanime_app/core/storage/app_storage_paths.dart';

class DesktopServer {
  Process? _process;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  String? _findBinary(String? customPath) {
    final isWin = Platform.isWindows;
    final binaryNames = isWin
        ? ['aniting.exe', 'aniting-server.exe', 'seanime.exe']
        : ['aniting', 'aniting-server', 'seanime'];
    final exeDir = Platform.resolvedExecutable.replaceAll(RegExp(r'[^/\\]+$'), '');

    final candidatePaths = [
      if (customPath != null && customPath.isNotEmpty) ...[
        customPath,
        if (isWin && !customPath.toLowerCase().endsWith('.exe')) '$customPath.exe',
      ],
      for (final bin in binaryNames) ...[
        './backend/$bin',
        '${Directory.current.path}/backend/$bin',
        '$exeDir$bin',
        '${exeDir}backend/$bin',
        './$bin',
      ],
    ];

    for (final path in candidatePaths) {
      if (File(path).existsSync()) {
        return path;
      }
    }
    return null;
  }

  void _ensureBuiltinTorrentConfig(String dir) {
    try {
      final configFile = File('$dir/config.toml');
      if (configFile.existsSync()) {
        final content = configFile.readAsStringSync();
        if (!content.contains('builtintorrentclient')) {
          configFile.writeAsStringSync('$content\n\n[experimental]\nbuiltintorrentclient = true\n');
        }
      }
    } catch (e) {
      debugPrint('DesktopServer: could not ensure builtin torrent config: $e');
    }
  }

  Future<bool> start({
    String? executablePath,
    int port = AppConstants.defaultPort,
    String host = '127.0.0.1',
    String? dataDir,
  }) async {
    if (_isRunning) return true;

    final resolvedBinary = _findBinary(executablePath);
    if (resolvedBinary == null) {
      debugPrint('DesktopServer: Executable seanime not found in candidate paths');
      return false;
    }

    // Always use dedicated Aniting server directory (%APPDATA%\Aniting or ~/.config/aniting)
    final resolvedDataDir = dataDir ?? await AppStoragePaths.getServerDataDirectory();

    _ensureBuiltinTorrentConfig(resolvedDataDir);

    try {
      final args = <String>[
        '--desktop-sidecar',
        '--disable-password',
        '--port', port.toString(),
        '--host', host,
        '--datadir', resolvedDataDir,
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
        debugPrint('[Aniting Server]: $data');
      });

      _process!.stderr.transform(utf8.decoder).listen((data) {
        debugPrint('[Aniting Server ERR]: $data');
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
