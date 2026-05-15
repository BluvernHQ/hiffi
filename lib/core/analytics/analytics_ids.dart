import 'dart:math';

String generateHexId({int bytes = 16}) {
  final rnd = Random.secure();
  final b = List<int>.generate(bytes, (_) => rnd.nextInt(256));
  final sb = StringBuffer();
  for (final v in b) {
    sb.write(v.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

