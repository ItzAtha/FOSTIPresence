// lib/bluetooth_manager.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:attendance_management/manager/wifi_manager.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:toastification/toastification.dart';

import '../translations/locale_keys.g.dart';

class BluetoothManager {
  final BuildContext? _context;

  final _serviceUUID = Guid("3707a02f-16d0-4b0f-8465-540cf4f1e049");
  final _charUUIDReceiver = Guid("d62cc1aa-931c-488d-986f-023109b1a5b7"); // write -> ESP32
  final _charUUIDMessage = Guid(
    "a2f490c0-128c-43e1-baee-4bba3ffcdb3b",
  ); // notify <- ESP32 as message transmitter
  final _charUUIDData = Guid(
    "a29d643b-4fda-446d-b9fd-118f540a902d",
  ); // notify <- ESP32 as data transmitter
  final _charUUIDRealtimeData = Guid(
    "a1766831-fec3-4749-92f2-931d54506e94",
  ); // notify <- ESP32 as real-time data transmitter

  static String _receivedData = "";
  static String _receivedRealtimeData = "";
  static final List<String> _receivedMessage = [];

  Timer? _espBTCheckerTask;
  StreamSubscription<List<ScanResult>>? _scanningBTSub;
  StreamSubscription<BluetoothAdapterState>? _enableBTSub;
  StreamSubscription<BluetoothConnectionState>? _connectedBTListenerSub;
  final List<StreamSubscription<List<int>>?> _receiverListenerSub = [];

  static final ValueNotifier<Map<BluetoothDevice, BluetoothConnectionState>> _foundDevicesList =
      ValueNotifier<Map<BluetoothDevice, BluetoothConnectionState>>({});

  BluetoothManager({BuildContext? context}) : _context = context;

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final requiredPermissions = [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.locationWhenInUse,
      ];

      try {
        final statuses = await requiredPermissions.request();
        for (var perm in requiredPermissions) {
          if (statuses[perm] != PermissionStatus.granted) {
            if (_context != null && !_context.mounted) return;

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
        if (_context != null && !_context.mounted) return;

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
    if (!await FlutterBluePlus.isSupported) {
      print("Bluetooth isn't support in this device!");
      return false;
    }

    _enableBTSub = FlutterBluePlus.adapterState.listen(
      (state) {
        print("Current bluetooth state: $state");

        if (state == BluetoothAdapterState.off) {
          if (_context != null && !_context.mounted) return;

          Toastification().show(
            context: _context,
            title: Text(LocaleKeys.alert_notify_bluetooth_title.tr(context: _context)),
            description: Text(
              LocaleKeys.alert_notify_bluetooth_description_request_enable_bt.tr(context: _context),
            ),
            type: ToastificationType.info,
            style: ToastificationStyle.flat,
            alignment: Alignment.bottomCenter,
            autoCloseDuration: Duration(seconds: 2),
            animationDuration: Duration(milliseconds: 500),
          );
        } else {
          print("Bluetooth connected! Starting scanning...");
        }
      },
      onError: (e) {
        print("Error during bluetooth enable requests: $e");
        _enableBTSub?.cancel();
        return false;
      },
    );

    if (!kIsWeb && Platform.isAndroid) {
      try {
        await FlutterBluePlus.turnOn();
      } catch (e) {
        if (!_context!.mounted) return false;

        Toastification().show(
          context: _context,
          title: Text(LocaleKeys.alert_notify_bluetooth_title.tr(context: _context)),
          description: Text(
            LocaleKeys.alert_notify_bluetooth_description_bt_not_enable.tr(context: _context),
          ),
          type: ToastificationType.info,
          style: ToastificationStyle.flat,
          alignment: Alignment.bottomCenter,
          autoCloseDuration: Duration(seconds: 2),
          animationDuration: Duration(milliseconds: 500),
        );
        _enableBTSub?.cancel();
        return false;
      }
    }

    _enableBTSub?.cancel();
    await _startScanning();
    return true;
  }

  Future<void> _startScanning() async {
    await _requestPermissions();

    _foundDevicesList.value.clear();

    _scanningBTSub = FlutterBluePlus.onScanResults.listen(
      (results) {
        if (results.isNotEmpty) {
          ScanResult result = results.last;
          BluetoothDevice device = result.device;

          if (!_foundDevicesList.value.containsKey(device)) {
            _foundDevicesList.value[device] = BluetoothConnectionState.disconnected;
            print(
              "Found device: ${device.remoteId} - ${device.platformName.isEmpty ? "Unknown Device" : device.platformName}",
            );
          }
        }
      },
      onError: (e) {
        print("Error during bluetooth scanning: $e");
        throw Exception('Scanning error: $e');
      },
    );

    FlutterBluePlus.cancelWhenScanComplete(_scanningBTSub as StreamSubscription<List<ScanResult>>);

    await FlutterBluePlus.startScan(timeout: 10.seconds);
    await FlutterBluePlus.isScanning.where((value) => !value).first;

    if (getConnectedDevice != null) {
      BluetoothDevice device = getConnectedDevice!;
      _foundDevicesList.value[device] = BluetoothConnectionState.connected;
      print(
        "Found connected device: ${device.remoteId} - ${device.platformName.isEmpty ? "Unknown Device" : device.platformName}",
      );
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    print("Connecting to device ${device.remoteId}");

    try {
      await device.connect(license: License.free);
      if (_context != null && !_context.mounted) return;

      Toastification().show(
        context: _context,
        title: Text(LocaleKeys.alert_notify_bluetooth_title.tr(context: _context)),
        description: Text(
          LocaleKeys.alert_notify_bluetooth_description_bt_success_connect.tr(
            context: _context,
            namedArgs: {
              'device': device.platformName.isEmpty
                  ? LocaleKeys.bluetooth_page_unknown_device.tr(context: _context)
                  : device.platformName,
            },
          ),
        ),
        type: ToastificationType.success,
        style: ToastificationStyle.flat,
        alignment: Alignment.bottomCenter,
        autoCloseDuration: Duration(seconds: 2),
        animationDuration: Duration(milliseconds: 500),
      );
      print(
        'Connected to device ${device.platformName.isEmpty ? "Unknown Device" : device.platformName}',
      );
      _startBluetoothListener(device);
    } catch (e) {
      _foundDevicesList.value[device] = BluetoothConnectionState.disconnected;
      Toastification().show(
        context: _context,
        title: Text(LocaleKeys.alert_notify_bluetooth_title.tr(context: _context)),
        description: Text(
          LocaleKeys.alert_notify_bluetooth_description_bt_fail_connect.tr(
            context: _context,
            namedArgs: {
              'device': device.platformName.isEmpty
                  ? LocaleKeys.bluetooth_page_unknown_device.tr(context: _context)
                  : device.platformName,
            },
          ),
        ),
        type: ToastificationType.error,
        style: ToastificationStyle.flat,
        alignment: Alignment.bottomCenter,
        autoCloseDuration: Duration(seconds: 2),
        animationDuration: Duration(milliseconds: 500),
      );
      throw Exception('Connection failed: $e');
    }
  }

  Future<void> disconnectFromDevice(BluetoothDevice device) async {
    print("Disconnecting from device ${device.remoteId}");

    if (device.isConnected) {
      try {
        await device.disconnect();
        if (_context != null && !_context.mounted) return;

        Toastification().show(
          context: _context,
          title: Text(LocaleKeys.alert_notify_bluetooth_title.tr(context: _context)),
          description: Text(
            LocaleKeys.alert_notify_bluetooth_description_bt_success_disconnect.tr(
              context: _context,
              namedArgs: {
                'device': device.platformName.isEmpty
                    ? LocaleKeys.bluetooth_page_unknown_device.tr(context: _context)
                    : device.platformName,
              },
            ),
          ),
          type: ToastificationType.success,
          style: ToastificationStyle.flat,
          alignment: Alignment.bottomCenter,
          autoCloseDuration: Duration(seconds: 2),
          animationDuration: Duration(milliseconds: 500),
        );
        print(
          'Disconnected from device ${device.platformName.isEmpty ? "Unknown Device" : device.platformName}',
        );
      } catch (e) {
        Toastification().show(
          context: _context,
          title: Text(LocaleKeys.alert_notify_bluetooth_title.tr(context: _context)),
          description: Text(
            LocaleKeys.alert_notify_bluetooth_description_bt_fail_disconnect.tr(
              context: _context,
              namedArgs: {
                'device': device.platformName.isEmpty
                    ? LocaleKeys.bluetooth_page_unknown_device.tr(context: _context)
                    : device.platformName,
              },
            ),
          ),
          type: ToastificationType.error,
          style: ToastificationStyle.flat,
          alignment: Alignment.bottomCenter,
          autoCloseDuration: Duration(seconds: 2),
          animationDuration: Duration(milliseconds: 500),
        );
        throw Exception('Disconnection failed: $e');
      }
    } else {
      Toastification().show(
        context: _context,
        title: Text(LocaleKeys.alert_notify_bluetooth_title.tr(context: _context)),
        description: Text(
          LocaleKeys.alert_notify_bluetooth_description_bt_already_disconnect.tr(
            context: _context,
            namedArgs: {
              'device': device.platformName.isEmpty
                  ? LocaleKeys.bluetooth_page_unknown_device.tr(context: _context)
                  : device.platformName,
            },
          ),
        ),
        type: ToastificationType.info,
        style: ToastificationStyle.flat,
        alignment: Alignment.bottomCenter,
        autoCloseDuration: Duration(seconds: 2),
        animationDuration: Duration(milliseconds: 500),
      );
      print('No active connection to disconnect');
    }
  }

  void _startBluetoothListener(BluetoothDevice device) {
    _connectedBTListenerSub = device.connectionState.listen(
      (state) async {
        if (state == BluetoothConnectionState.disconnected) {
          _foundDevicesList.value[device] = BluetoothConnectionState.disconnected;
          print(
            "Disconnected from device ${device.platformName} | ${_foundDevicesList.value[device]}",
          );
        } else if (state == BluetoothConnectionState.connected) {
          _foundDevicesList.value[device] = BluetoothConnectionState.connected;
          print("Connected to device ${device.platformName} | ${_foundDevicesList.value[device]}");

          BluetoothCharacteristic deviceMessageChar = await _getCharacteristic(
            device,
            _charUUIDMessage,
          );
          BluetoothCharacteristic deviceDataChar = await _getCharacteristic(device, _charUUIDData);
          BluetoothCharacteristic deviceRealtimeDataChar = await _getCharacteristic(
            device,
            _charUUIDRealtimeData,
          );

          _receiverListenerSub.add(
            deviceMessageChar.onValueReceived.listen((value) async {
              String decodedMessage = "";

              try {
                decodedMessage = utf8.decode(value, allowMalformed: false);
              } catch (e) {
                print("Invalid decoded message! Skip...");
                return;
              }

              if (decodedMessage.trim().isEmpty) return;

              print("Received message from ESP32: ${decodedMessage.trim()}");
              if (decodedMessage.contains('</nl>')) {
                decodedMessage = decodedMessage.replaceAll('</nl>', '\n');
              }
              _receivedMessage.add(decodedMessage);
            }),
          );

          _receiverListenerSub.add(
            deviceDataChar.onValueReceived.listen((value) async {
              String decodedData = "";

              try {
                decodedData = utf8.decode(value, allowMalformed: false);
              } catch (e) {
                print("Invalid decoded data! Skip...");
                return;
              }

              if (decodedData.trim().isEmpty) return;

              print("Received data from ESP32: ${decodedData.trim()}");
              _receivedData = decodedData;
            }),
          );

          _receiverListenerSub.add(
            deviceRealtimeDataChar.onValueReceived.listen((value) async {
              String decodedRealtimeData = "";

              try {
                decodedRealtimeData = utf8.decode(value, allowMalformed: false);
              } catch (e) {
                print("Invalid decoded real-time data! Skip...");
                return;
              }

              if (decodedRealtimeData.trim().isEmpty) return;

              print("Received real-time data from ESP32: ${decodedRealtimeData.trim()}");
              _receivedRealtimeData = decodedRealtimeData;

              await Future.delayed(1.seconds, () {
                _receivedRealtimeData = "";
                decodedRealtimeData = "";
              });
            }),
          );

          for (var sub in _receiverListenerSub) {
            device.cancelWhenDisconnected(sub as StreamSubscription<List<int>>, delayed: true);
          }
          await deviceDataChar.setNotifyValue(true);
          await deviceMessageChar.setNotifyValue(true);
          await deviceRealtimeDataChar.setNotifyValue(true);
          _startESP32BTCheckerTask();
        }
      },
      onError: (e) {
        if (_context != null && !_context.mounted) return;

        Toastification().show(
          context: _context,
          title: Text(LocaleKeys.alert_notify_bluetooth_title.tr(context: _context)),
          description: Text(
            LocaleKeys.alert_notify_bluetooth_description_bt_connection_error.tr(
              context: _context,
              namedArgs: {
                'device': device.platformName.isEmpty
                    ? LocaleKeys.bluetooth_page_unknown_device.tr(context: _context)
                    : device.platformName,
              },
            ),
          ),
          type: ToastificationType.info,
          style: ToastificationStyle.flat,
          alignment: Alignment.bottomCenter,
          autoCloseDuration: Duration(seconds: 2),
          animationDuration: Duration(milliseconds: 500),
        );
        print('Connection error: $e');
      },
    );

    device.cancelWhenDisconnected(
      _connectedBTListenerSub as StreamSubscription<BluetoothConnectionState>,
      delayed: true,
      next: true,
    );
  }

  void _startESP32BTCheckerTask() {
    if (_espBTCheckerTask != null) return;

    _espBTCheckerTask = Timer.periodic(1.seconds, (timer) async {
      if (!isBluetoothConnected) {
        print("ESP32 Bluetooth disconnected! Stopping Bluetooth task...");
        WiFiManager.setESPWiFiConnect = false;

        _espBTCheckerTask?.cancel();
        _espBTCheckerTask = null;
      }
    });
  }

  void sendBluetoothData(BluetoothDevice device, String data) async {
    BluetoothCharacteristic deviceCharacter = await _getCharacteristic(device, _charUUIDReceiver);

    if (device.isConnected) {
      String rawData = data.trim();
      List<int> encodedData = utf8.encode(rawData);
      await deviceCharacter.write(encodedData);
    } else {
      if (_context != null && !_context.mounted) return;

      Toastification().show(
        context: _context,
        title: Text(LocaleKeys.alert_notify_bluetooth_title.tr(context: _context)),
        description: Text(
          LocaleKeys.alert_notify_bluetooth_description_no_active_bt.tr(context: _context),
        ),
        type: ToastificationType.info,
        style: ToastificationStyle.flat,
        alignment: Alignment.bottomCenter,
        autoCloseDuration: Duration(seconds: 2),
        animationDuration: Duration(milliseconds: 500),
      );
      print('No active connection to send message');
    }
  }

  Future<BluetoothCharacteristic> _getCharacteristic(BluetoothDevice device, Guid charUuid) async {
    final services = await device.discoverServices();

    for (final service in services) {
      if (service.uuid == _serviceUUID) {
        for (final character in service.characteristics) {
          if (character.uuid == charUuid) {
            return character;
          }
        }
      }
    }
    throw Exception('Characteristic $charUuid not found on service $_serviceUUID');
  }

  static List<BluetoothDevice> get getDevicesList => _foundDevicesList.value.keys.toList();

  static ValueNotifier<Map<BluetoothDevice, BluetoothConnectionState>> get getDeviceStatus =>
      _foundDevicesList;

  static List<String> get getReceivedMessage => _receivedMessage;

  static String get getReceivedData => _receivedData;

  static String get getReceivedRealtimeData => _receivedRealtimeData;

  static void clearReceivedMessage() => _receivedMessage.clear();

  static void clearReceivedData() => _receivedData = "";

  static bool get isBluetoothConnected =>
      FlutterBluePlus.connectedDevices.any((device) => device.isConnected);

  static BluetoothDevice? get getConnectedDevice =>
      FlutterBluePlus.connectedDevices.where((device) => device.isConnected).firstOrNull;
}
