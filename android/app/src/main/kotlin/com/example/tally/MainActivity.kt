package com.example.tally

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {
  private val channelName = "tally/native_timezone"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
      when (call.method) {
        "getTimeZoneName" -> {
          val timeZoneId = TimeZone.getDefault().id
          result.success(timeZoneId)
        }
        else -> result.notImplemented()
      }
    }
  }
}
