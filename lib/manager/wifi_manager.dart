// lib/bluetooth_manager.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:attendance_management/manager/bluetooth_manager.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:toastification/toastification.dart';
import 'package:wifi_scan/wifi_scan.dart';

import '../translations/locale_keys.g.dart';

enum WiFiConnectionState { disconnecting, disconnected, connecting, connected }

enum WiFiStatus { error, failed, success, disconnect, unknown }

class WiFiManager {
  final BuildContext _context;
  final BluetoothManager bluetoothManager;

  Timer? _espWiFiCheckerTask;
  static bool _isESPWiFiConnected = false;

  StreamSubscription<List<WiFiAccessPoint>>? _scanningWiFiSub;
  static final ValueNotifier<Map<WiFiAccessPoint, WiFiConnectionState>> _foundWiFisList =
      ValueNotifier<Map<WiFiAccessPoint, WiFiConnectionState>>({});

  WiFiManager({required BuildContext context})
    : _context = context,
      bluetoothManager = BluetoothManager(context: context);

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final requiredPermissions = [Permission.locationWhenInUse];

      try {
        final statuses = await requiredPermissions.request();
        for (var perm in requiredPermissions) {
          if (statuses[perm] != PermissionStatus.granted) {
            if (!_context.mounted) return;

            Toastification().show(
              context: _context,
              title: Text(LocaleKeys.alert_notify_permission_title.tr(context: _context)),
              description: Text(
                LocaleKeys.alert_notify_permission_description_not_granted.tr(
                  context: _context,
                  namedArgs: {'permission': perm.toString()},
                ),
              ),
              type: ToastificationType.info,
              style: ToastificationStyle.flat,
              alignment: Alignment.bottomCenter,
              autoCloseDuration: Duration(seconds: 2),
              animationDuration: Duration(milliseconds: 500),
            );
            throw Exception('Permission $perm not granted');
          }
        }
      } catch (e) {
        if (!_context.mounted) return;

        Toastification().show(
          context: _context,
          title: Text(LocaleKeys.alert_notify_permission_title.tr(context: _context)),
          description: Text(
            LocaleKeys.alert_notify_permission_description_request_fail.tr(context: _context),
          ),
          type: ToastificationType.info,
          style: ToastificationStyle.flat,
          alignment: Alignment.bottomCenter,
          autoCloseDuration: Duration(seconds: 2),
          animationDuration: Duration(milliseconds: 500),
        );
        throw Exception('Permission request failed: $e');
      }
    }
  }

  Future<bool> initialize() async {
    return await _startScanning();
  }

  Future<bool> _startScanning() async {
    await _requestPermissions();

    final canStartScanWiFi = await WiFiScan.instance.canStartScan();
    if (canStartScanWiFi != CanStartScan.yes) {
      if (!_context.mounted) return false;

      Toastification().show(
        context: _context,
        title: Text(LocaleKeys.alert_notify_wifi_title.tr(context: _context)),
        description: Text(
          LocaleKeys.alert_notify_wifi_description_cant_start_scan.tr(
            context: _context,
            namedArgs: {'reason': canStartScanWiFi.name},
          ),
        ),
        type: ToastificationType.info,
        style: ToastificationStyle.flat,
        alignment: Alignment.bottomCenter,
        autoCloseDuration: Duration(seconds: 2),
        animationDuration: Duration(milliseconds: 500),
      );
      return false;
    }

    _foundWiFisList.value.clear();

    final canGetScannedResults = await WiFiScan.instance.canGetScannedResults();
    if (canGetScannedResults != CanGetScannedResults.yes) {
      if (!_context.mounted) return false;
      Toastification().show(
        context: _context,
        title: Text(LocaleKeys.alert_notify_wifi_title.tr(context: _context)),
        description: Text(
          LocaleKeys.alert_notify_wifi_description_cant_get_scan_result.tr(
            context: _context,
            namedArgs: {'reason': canGetScannedResults.name},
          ),
        ),
        type: ToastificationType.info,
        style: ToastificationStyle.flat,
        alignment: Alignment.bottomCenter,
        autoCloseDuration: Duration(seconds: 2),
        animationDuration: Duration(milliseconds: 500),
      );
      return false;
    }

    _scanningWiFiSub = WiFiScan.instance.onScannedResultsAvailable.listen(
      (results) {
        if (results.isNotEmpty) {
          WiFiAccessPoint wifi = results.last;

          if (!_foundWiFisList.value.containsKey(wifi)) {
            if (_foundWiFisList.value.keys.where((a) => a.ssid == wifi.ssid).isNotEmpty) return;

            _foundWiFisList.value[wifi] = WiFiConnectionState.disconnected;
            print("Found device: ${wifi.ssid} - ${wifi.bssid}");
          }
        }
      },
      onError: (e) {
        print("Error during WiFi scanning: $e");
        throw Exception('Scanning error: $e');
      },
    );

    await WiFiScan.instance.startScan();
    await Future.delayed(10.seconds, () => _scanningWiFiSub?.cancel());
    return true;
  }

  Future<bool?> connectToWiFi(WiFiAccessPoint wifi, String password) async {
    print("Connecting to WiFi ${wifi.ssid} with password $password");

    BluetoothManager.clearReceivedData();
    BluetoothDevice? device = BluetoothManager.getConnectedDevice;
    if (device == null) return false;

    String data = '{"ssid":"${wifi.ssid}","password":"$password"}';
    bluetoothManager.sendBluetoothData(device, data);

    Timer? timeoutTimer;
    Completer timeoutCompleter = Completer<bool>();

    timeoutTimer = Timer.periodic(500.milliseconds, (timer) {
      String callbackData = BluetoothManager.getReceivedData;

      if (callbackData.isEmpty) return;
      Map<String, dynamic> data = jsonDecode(callbackData) as Map<String, dynamic>;
      if (!data.containsKey("wifiStatusCode")) return;

      WiFiStatus status;
      try {
        status = (data["wifiStatusCode"] as int).toWiFiStatus();
      } catch (e) {
        print("Failed to decode WiFi status. Exception: $e");
        return;
      }

      if (status == WiFiStatus.success) {
        _foundWiFisList.value[wifi] = WiFiConnectionState.connected;
        _isESPWiFiConnected = true;
        _startESPWiFiCheckerTask();
        timeoutCompleter.complete(true);
      } else {
        _foundWiFisList.value[wifi] = WiFiConnectionState.disconnected;
        timeoutCompleter.complete(false);
      }
      timer.cancel();
    });

    return await timeoutCompleter.future.timeout(
      30.seconds,
      onTimeout: () {
        timeoutTimer?.cancel();
        _foundWiFisList.value[wifi] = WiFiConnectionState.disconnected;
        return false;
      },
    );
  }

  void _startESPWiFiCheckerTask() {
    if (_espWiFiCheckerTask != null) return;

    _espWiFiCheckerTask = Timer.periodic(1.seconds, (timer) {
      if (!_isESPWiFiConnected) {
        _espWiFiCheckerTask?.cancel();
        _espWiFiCheckerTask = null;
      }

      String callbackData = BluetoothManager.getReceivedRealtimeData;
      if (callbackData.isEmpty) return;

      Map<String, dynamic> callbacksData;
      try {
        callbacksData = jsonDecode(callbackData) as Map<String, dynamic>;
      } catch (e) {
        print("Failed to decode callback data. Exception: $e");
        return;
      }

      if (!callbacksData.containsKey("wifiStatusCode")) return;
      int statusCode = callbacksData["wifiStatusCode"] as int;
      WiFiStatus status = statusCode.toWiFiStatus();

      if (status == WiFiStatus.failed || status == WiFiStatus.error) {
        print("ESP32 WiFi disconnected! Stopping WiFi task...");
        _isESPWiFiConnected = false;

        _espWiFiCheckerTask?.cancel();
        _espWiFiCheckerTask = null;
      }
    });
  }

  static List<WiFiAccessPoint> get getWiFiList => _foundWiFisList.value.keys.toList();

  static ValueNotifier<Map<WiFiAccessPoint, WiFiConnectionState>> get getWiFiStatus =>
      _foundWiFisList;

  static bool get isESPWiFiConnected => _isESPWiFiConnected;

  static set setESPWiFiConnect(bool isConnect) {
    _isESPWiFiConnected = isConnect;
  }

  static bool get isAnyWiFiConnected => _foundWiFisList.value
      .map((key, value) => MapEntry(key, value == WiFiConnectionState.connected))
      .containsValue(true);

  static WiFiAccessPoint get getConnectedWiFi => _foundWiFisList.value.entries
      .firstWhere(
        (entry) => entry.value == WiFiConnectionState.connected,
        orElse: () {
          throw Exception('No connected WiFi found');
        },
      )
      .key;
}

extension WiFiCodeStatus on int {
  WiFiStatus toWiFiStatus() {
    switch (this) {
      case -1:
        return WiFiStatus.error;
      case 0:
        return WiFiStatus.failed;
      case 1:
        return WiFiStatus.success;
      case 2:
        return WiFiStatus.disconnect;
      default:
        return WiFiStatus.unknown;
    }
  }
}
