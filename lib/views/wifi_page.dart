import 'dart:async';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:attendance_management/manager/wifi_manager.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import 'package:wifi_scan/wifi_scan.dart';

import '../translations/locale_keys.g.dart';

class WiFiPage extends StatefulWidget {
  const WiFiPage({super.key});

  @override
  State<StatefulWidget> createState() => _WiFiPageState();
}

class _WiFiPageState extends State<WiFiPage> {
  bool isScanning = true;
  bool isConnecting = false;
  late WiFiManager wifiManager;

  Future<void> onWiFiListRefresh() async {
    setState(() => isScanning = true);

    wifiManager.initialize().then((isSuccess) {
      if (!mounted) return;
      if (isSuccess) {
        setState(() => isScanning = false);

        Toastification().show(
          context: context,
          title: Text(LocaleKeys.alert_notify_wifi_title.tr(context: context)),
          description: Text(
            LocaleKeys.alert_notify_wifi_description_success_rediscover.tr(context: context),
          ),
          type: ToastificationType.info,
          style: ToastificationStyle.flat,
          alignment: Alignment.bottomCenter,
          autoCloseDuration: Duration(seconds: 2),
          animationDuration: Duration(milliseconds: 500),
        );
        print('WiFi initialization success');
      } else {
        Toastification().show(
          context: context,
          title: Text(LocaleKeys.alert_notify_wifi_title.tr(context: context)),
          description: Text(
            LocaleKeys.alert_notify_wifi_description_fail_rediscover.tr(context: context),
          ),
          type: ToastificationType.info,
          style: ToastificationStyle.flat,
          alignment: Alignment.bottomCenter,
          autoCloseDuration: Duration(seconds: 2),
          animationDuration: Duration(milliseconds: 500),
        );
        print('WiFi initialization failed');
      }
    });
  }

  @override
  void initState() {
    super.initState();

    wifiManager = WiFiManager(context: context);
    wifiManager.initialize().then((isSuccess) {
      if (!mounted) return;
      if (isSuccess) {
        setState(() => isScanning = false);

        Toastification().show(
          context: context,
          title: Text(LocaleKeys.alert_notify_wifi_title.tr(context: context)),
          description: Text(
            LocaleKeys.alert_notify_wifi_description_success_discover.tr(context: context),
          ),
          type: ToastificationType.info,
          style: ToastificationStyle.flat,
          alignment: Alignment.bottomCenter,
          autoCloseDuration: Duration(seconds: 2),
          animationDuration: Duration(milliseconds: 500),
        );
        print('WiFi initialization success');
      } else {
        Toastification().show(
          context: context,
          title: Text(LocaleKeys.alert_notify_wifi_title.tr(context: context)),
          description: Text(
            LocaleKeys.alert_notify_wifi_description_fail_discover.tr(context: context),
          ),
          type: ToastificationType.info,
          style: ToastificationStyle.flat,
          alignment: Alignment.bottomCenter,
          autoCloseDuration: Duration(seconds: 2),
          animationDuration: Duration(milliseconds: 500),
        );
        print('WiFi initialization failed');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(child: Text(LocaleKeys.wifi_page_title.tr(context: context))),
        leading: BackButton(),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade400, Colors.green.shade800],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        leadingWidth: 55.0,
        actions: <Widget>[
          ValueListenableBuilder<AdaptiveThemeMode?>(
            valueListenable: AdaptiveTheme.of(context).modeChangeNotifier,
            builder: (context, mode, _) {
              final isLight = mode == AdaptiveThemeMode.light;
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  return RotationTransition(
                    turns: child.key == ValueKey('icon1')
                        ? Tween<double>(begin: 1, end: 0.75).animate(animation)
                        : Tween<double>(begin: 0.75, end: 1).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: IconButton(
                  key: ValueKey(isLight ? 'icon1' : 'icon2'),
                  onPressed: () {
                    if (isLight) {
                      AdaptiveTheme.of(context).setDark();
                    } else {
                      AdaptiveTheme.of(context).setLight();
                    }
                  },
                  icon: Icon(isLight ? Icons.wb_sunny : Icons.nights_stay),
                ),
              );
            },
          ),
        ],
      ),
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
                  Text(LocaleKeys.wifi_page_loading_data_process.tr(context: context)),
                ],
              ),
            )
          : WiFiManager.getWiFiList.isNotEmpty
          ? RefreshIndicator(
              onRefresh: onWiFiListRefresh,
              child: ListView.builder(
                physics: AlwaysScrollableScrollPhysics(),
                itemCount: WiFiManager.getWiFiList.length,
                itemBuilder: (context, index) {
                  WiFiAccessPoint wifi = WiFiManager.getWiFiList[index];

                  return ValueListenableBuilder<Map<WiFiAccessPoint, WiFiConnectionState>>(
                    valueListenable: WiFiManager.getWiFiStatus,
                    builder: (context, value, _) {
                      return ListTile(
                        title: Text(wifi.ssid),
                        subtitle: Text(wifi.bssid),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton(
                              onPressed: !isConnecting && !WiFiManager.isESPWiFiConnected
                                  ? () async {
                                      String password = "";
                                      setState(() => isConnecting = true);
                                      value[wifi] = WiFiConnectionState.connecting;

                                      var result = await showDialog<bool>(
                                        context: context,
                                        builder: (context) {
                                          bool showPassword = false;

                                          return StatefulBuilder(
                                            builder: (context, dialogSetState) {
                                              return AlertDialog(
                                                title: Text(
                                                  LocaleKeys.wifi_page_connect_dialog_title.tr(
                                                    context: context,
                                                  ),
                                                ),
                                                content: Row(
                                                  children: [
                                                    Expanded(
                                                      child: TextField(
                                                        obscureText: !showPassword,
                                                        onChanged: (value) {
                                                          password = value.trim();
                                                        },
                                                        decoration: InputDecoration(
                                                          labelText: LocaleKeys
                                                              .wifi_page_connect_dialog_input_box
                                                              .tr(
                                                                context: context,
                                                                namedArgs: {'ssid': wifi.ssid},
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                    IconButton(
                                                      icon: Icon(
                                                        showPassword
                                                            ? Icons.visibility
                                                            : Icons.visibility_off,
                                                      ),
                                                      onPressed: () {
                                                        dialogSetState(
                                                          () => showPassword = !showPassword,
                                                        );
                                                        print(showPassword);
                                                      },
                                                    ),
                                                  ],
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () {
                                                      Navigator.pop(context, true);
                                                    },
                                                    child: Text(
                                                      LocaleKeys.wifi_page_connect_dialog_button.tr(
                                                        context: context,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                        },
                                      );

                                      if (result == null) {
                                        print("Cancelled WiFi connection to ${wifi.ssid}");
                                        value[wifi] = WiFiConnectionState.disconnected;
                                        setState(() => isConnecting = false);
                                        return;
                                      }

                                      bool? isSuccess = await wifiManager.connectToWiFi(
                                        wifi,
                                        password,
                                      );
                                      if (!context.mounted || isSuccess == null) {
                                        setState(() => isConnecting = false);
                                        return;
                                      }

                                      if (isSuccess) {
                                        Toastification().show(
                                          context: context,
                                          title: Text(
                                            LocaleKeys.alert_notify_esp_title.tr(context: context),
                                          ),
                                          description: Text(
                                            LocaleKeys.alert_notify_esp_description_success_connect
                                                .tr(
                                                  context: context,
                                                  namedArgs: {'ssid': wifi.ssid},
                                                ),
                                          ),
                                          type: ToastificationType.success,
                                          style: ToastificationStyle.flat,
                                          alignment: Alignment.bottomCenter,
                                          autoCloseDuration: Duration(seconds: 2),
                                          animationDuration: Duration(milliseconds: 500),
                                        );
                                        Navigator.of(context).pop();
                                      } else {
                                        setState(() => isConnecting = false);

                                        Toastification().show(
                                          context: context,
                                          title: Text(
                                            LocaleKeys.alert_notify_esp_title.tr(context: context),
                                          ),
                                          description: Text(
                                            LocaleKeys.alert_notify_esp_description_fail_connect.tr(
                                              context: context,
                                              namedArgs: {'ssid': wifi.ssid},
                                            ),
                                          ),
                                          type: ToastificationType.error,
                                          style: ToastificationStyle.flat,
                                          alignment: Alignment.bottomCenter,
                                          autoCloseDuration: Duration(seconds: 2),
                                          animationDuration: Duration(milliseconds: 500),
                                        );
                                      }
                                    }
                                  : null,
                              child: value[wifi] == WiFiConnectionState.disconnected
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
                                  : value[wifi] == WiFiConnectionState.connected
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
                                  : value[wifi] == WiFiConnectionState.connecting
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
                  onRefresh: onWiFiListRefresh,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Center(
                        child: Text(
                          LocaleKeys.wifi_page_loading_data_no_device.tr(context: context),
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
