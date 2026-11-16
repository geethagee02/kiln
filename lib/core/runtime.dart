import 'dart:async';
import 'dart:math';

class StudioClock {
  StudioClock([DateTime Function()? now]) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  DateTime now() => _now().toUtc();
}

class IdGen {
  IdGen([String Function()? next]) : _next = next ?? _randomId;

  final String Function() _next;

  String next() => _next();

  static String _randomId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

class ChangeBus {
  final _controller = StreamController<void>.broadcast();

  Stream<void> get stream => _controller.stream;

  void ping() {
    if (!_controller.isClosed) _controller.add(null);
  }

  void dispose() {
    _controller.close();
  }
}

const unset = Object();
