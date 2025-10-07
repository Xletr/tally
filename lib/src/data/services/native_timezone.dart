import 'package:flutter/services.dart';

const _channelName = 'tally/native_timezone';
const _methodName = 'getTimeZoneName';

final MethodChannel _channel = const MethodChannel(_channelName);

Future<String> loadLocalTimezone() async {
  try {
    final result = await _channel.invokeMethod<String>(_methodName);
    if (result == null || result.isEmpty) {
      return 'UTC';
    }
    return result;
  } catch (_) {
    return 'UTC';
  }
}
