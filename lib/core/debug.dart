import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// The Debug section's password check. CI passes only a salted hash
/// (--dart-define=DEBUG_KEY); builds without it keep Debug shut, except
/// local debug builds.
class DebugGate {
  static const _key = String.fromEnvironment('DEBUG_KEY');

  static bool check(String password) {
    if (_key.isEmpty) return kDebugMode;
    return sha256.convert(utf8.encode('sisyphus-debug:$password')).toString() == _key;
  }
}
