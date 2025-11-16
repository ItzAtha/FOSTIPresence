import 'dart:async';

import 'package:attendance_management/manager/bluetooth_manager.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:toastification/toastification.dart';

import '../translations/locale_keys.g.dart';

class BluetoothPage extends StatefulWidget {
  const BluetoothPage({super.key});

  @override
  State<StatefulWidget> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  bool isScanning = true;
  bool isConnecting = false;
  late BluetoothManager bluetoothManager;

  Future<void> onBluetoothListRefresh() async {
    setState(() => isScanning = true);

    bluetoothManager.initialize().then((isSuccess) {
      if (!mounted) return;
      if (isSuccess) {
        setState(() => isScanning = false);

        Toastification().show(
          context: context,
          title: Text(LocaleKeys.alert_notify_bluetooth_title.tr(context: context)),
          description: Text(
            LocaleKeys.alert_notify_bluetooth_description_success_rediscover.tr(context: context),
          ),
          type: ToastificationType.info,
          style: ToastificationStyle.flat,
          alignment: Alignment.bottomCenter,
          autoCloseDuration: Duration(seconds: 2),
          animationDuration: Duration(milliseconds: 500),
        );
        print('Bluetooth initialization success');
      } else {
        Toastification().show(
          context: context,
          title: Text(LocaleKeys.alert_notify_bluetooth_title.tr(context: context)),
          description: Text(
            LocaleKeys.alert_notify_bluetooth_description_fail_rediscover.tr(context: context),
          ),
          type: ToastificationType.info,
          style: ToastificationStyle.flat,
          alignment: Alignment.bottomCenter,
          autoCloseDuration: Duration(seconds: 2),
          animationDuration: Duration(milliseconds: 500),
        );
        print('Bluetooth initialization failed');
      }
    });
  }

  @override
  void initState() {
    super.initState();

    bluetoothManager = BluetoothManager(context: context);
    bluetoothManager.initialize().then((isSuccess) {
      if (!mounted) return;
      if (isSuccess) {
        setState(() => isScanning = false);

        Toastification().show(
          context: context,
          title: Text(LocaleKeys.alert_notify_bluetooth_title.tr(context: context)),
          description: Text(
            LocaleKeys.alert_notify_bluetooth_description_success_discover.tr(context: context),
          ),
          type: ToastificationType.info,
          style: ToastificationStyle.flat,
          alignment: Alignment.bottomCenter,
          autoCloseDuration: Duration(seconds: 2),
          animationDuration: Duration(milliseconds: 500),
        );
        print('Bluetooth initialization success');
      } else {
        Toastification().show(
          context: context,
          title: Text(LocaleKeys.alert_notify_bluetooth_title.tr(context: context)),
          description: Text(
            LocaleKeys.alert_notify_bluetooth_description_fail_discover.tr(context: context),
          ),
          type: ToastificationType.info,
          style: ToastificationStyle.flat,
          alignment: Alignment.bottomCenter,
          autoCloseDuration: Duration(seconds: 2),
          animationDuration: Duration(milliseconds: 500),
        );
        print('Bluetooth initialization failed');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isScanning
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).brightness == Brightness.light
                          ? Colors.green.shade300
                          : Colors.green.shade200,
                    ),
                  ),
                  SizedBox(height: 16.0),
                  Text(LocaleKeys.bluetooth_page_loading_data_process.tr(context: context)),
                ],
              ),
            )
          : BluetoothManager.getDevicesList.isNotEmpty
          ? RefreshIndicator(
              onRefresh: onBluetoothListRefresh,
              child: ListView.builder(
                physics: AlwaysScrollableScrollPhysics(),
                itemCount: BluetoothManager.getDevicesList.length,
                itemBuilder: (context, index) {
                  BluetoothDevice device = BluetoothManager.getDevicesList[index];

                  return ValueListenableBuilder<Map<BluetoothDevice, BluetoothConnectionState>>(
                    valueListenable: BluetoothManager.getDeviceStatus,
                    builder: (context, value, _) {
                      return ListTile(
                        title: Text(
                          device.platformName.isEmpty
                              ? LocaleKeys.bluetooth_page_unknown_device.tr(context: context)
                              : device.platformName,
                        ),
                        subtitle: Text(device.remoteId.str),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton(
                              onPressed: !isConnecting
                                  ? () async {
                                      setState(() => isConnecting = true);

                                      if (!device.isConnected) {
                                        try {
                                          value[device] = BluetoothConnectionState.connecting;
                                          if (BluetoothManager.isBluetoothConnected) {
                                            Toastification().show(
                                              context: context,
                                              title: Text(
                                                LocaleKeys.alert_notify_bluetooth_title.tr(
                                                  context: context,
                                                ),
                                              ),
                                              description: Text(
                                                LocaleKeys
                                                    .alert_notify_bluetooth_description_already_connected
                                                    .tr(context: context),
                                              ),
                                              type: ToastificationType.warning,
                                              style: ToastificationStyle.flat,
                                              alignment: Alignment.bottomCenter,
                                              autoCloseDuration: Duration(seconds: 2),
                                              animationDuration: Duration(milliseconds: 500),
                                            );
                                            value[device] = BluetoothConnectionState.disconnected;
                                            setState(() => isConnecting = false);
                                            return;
                                          }

                                          await bluetoothManager.connectToDevice(device);
                                        } catch (e) {
                                          print('Connection failed: $e');
                                        }
                                      } else {
                                        try {
                                          value[device] = BluetoothConnectionState.disconnecting;
                                          await bluetoothManager.disconnectFromDevice(device);
                                        } catch (e) {
                                          print('Disconnection failed: $e');
                                        }
                                      }

                                      setState(() => isConnecting = false);
                                    }
                                  : null,
                              child: value[device] == BluetoothConnectionState.disconnected
                                  ? Row(
                                      children: [
                                        Text(
                                          LocaleKeys.device_button_state_connect.tr(
                                            context: context,
                                          ),
                                        ),
                                        SizedBox(width: 8.0),
                                        Icon(Icons.link, color: Colors.green),
                                      ],
                                    )
                                  : value[device] == BluetoothConnectionState.connected
                                  ? Row(
                                      children: [
                                        Text(
                                          LocaleKeys.device_button_state_disconnect.tr(
                                            context: context,
                                          ),
                                        ),
                                        SizedBox(width: 8.0),
                                        Icon(Icons.link_off, color: Colors.red),
                                      ],
                                    )
                                  : value[device] == BluetoothConnectionState.connecting
                                  ? Row(
                                      children: [
                                        Text(
                                          LocaleKeys.device_button_state_connecting.tr(
                                            context: context,
                                          ),
                                        ),
                                        SizedBox(width: 12.0),
                                        SizedBox(
                                          width: 12.0,
                                          height: 12.0,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.0,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              Theme.of(context).brightness == Brightness.light
                                                  ? Colors.green.shade300
                                                  : Colors.green.shade200,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        Text(
                                          LocaleKeys.device_button_state_disconnecting.tr(
                                            context: context,
                                          ),
                                        ),
                                        SizedBox(width: 8.0),
                                        SizedBox(
                                          width: 12.0,
                                          height: 12.0,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.0,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              Theme.of(context).brightness == Brightness.light
                                                  ? Colors.green.shade300
                                                  : Colors.green.shade200,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                return RefreshIndicator(
                  onRefresh: onBluetoothListRefresh,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Center(
                        child: Text(
                          LocaleKeys.bluetooth_page_loading_data_no_device.tr(context: context),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16.0, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
