import 'dart:async';

import 'package:attendance_management/manager/bluetooth_manager.dart';
import 'package:attendance_management/manager/events_manager.dart';
import 'package:attendance_management/manager/wifi_manager.dart';
import 'package:attendance_management/translations/locale_keys.g.dart';
import 'package:attendance_management/views/control_panel_page.dart';
import 'package:attendance_management/views/wifi_page.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:toastification/toastification.dart';

import '../utilities/connectivity_utils.dart';
import '../manager/database_manager.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  Event? activeEvent;
  List<Event> eventsData = [];

  Timer? wifiCheckerTask;
  bool isInternetConnected = false;

  Timer? espStatusChecker;
  bool isDataLoaded = false;

  late bool isLoadingDone;
  late bool isWiFiConnect;
  late bool isDeviceConnect;

  late DatabaseManager database;

  Future<void> fetchAllEvents({required String path}) async {
    setState(() => isLoadingDone = false);

    if (!await ConnectivityUtils.checkConnection()) {
      if (!mounted) return;

      Toastification().show(
        context: context,
        title: Text(LocaleKeys.alert_notify_internet_title.tr(context: context)),
        description: Text(LocaleKeys.alert_notify_internet_description.tr(context: context)),
        type: ToastificationType.info,
        style: ToastificationStyle.flat,
        alignment: Alignment.bottomCenter,
        autoCloseDuration: Duration(seconds: 2),
        animationDuration: Duration(milliseconds: 500),
      );

      setState(() => isLoadingDone = true);
      return;
    }

    dynamic rawData = await database.readData(urlPath: path);
    if (!mounted) return;

    if (rawData != null) {
      eventsData = rawData as List<Event>;
      if (eventsData.isNotEmpty) {
        setState(() {
          isDataLoaded = true;
          activeEvent = eventsData.where((event) => event.isActive == true).firstOrNull;
        });

        if (activeEvent == null) {
          Toastification().show(
            context: context,
            title: Text(LocaleKeys.alert_notify_event_title.tr(context: context)),
            description: Text(
              LocaleKeys.alert_notify_event_description_no_active.tr(context: context),
            ),
            type: ToastificationType.info,
            style: ToastificationStyle.flat,
            alignment: Alignment.bottomCenter,
            autoCloseDuration: Duration(seconds: 2),
            animationDuration: Duration(milliseconds: 500),
          );
        }

        isInternetConnected = true;
      } else {
        Toastification().show(
          context: context,
          title: Text(LocaleKeys.alert_notify_event_title.tr(context: context)),
          description: Text(LocaleKeys.alert_notify_event_description_no_data.tr(context: context)),
          type: ToastificationType.info,
          style: ToastificationStyle.flat,
          alignment: Alignment.bottomCenter,
          autoCloseDuration: Duration(seconds: 2),
          animationDuration: Duration(milliseconds: 500),
        );
      }
    } else {
      Toastification().show(
        context: context,
        title: Text(LocaleKeys.alert_notify_event_title.tr(context: context)),
        description: Text(LocaleKeys.alert_notify_event_description_not_load.tr(context: context)),
        type: ToastificationType.info,
        style: ToastificationStyle.flat,
        alignment: Alignment.bottomCenter,
        autoCloseDuration: Duration(seconds: 2),
        animationDuration: Duration(milliseconds: 500),
      );
    }

    setState(() => isLoadingDone = true);
  }

  void startWiFiChecker() {
    wifiCheckerTask = Timer.periodic(Duration(seconds: 5), (timer) async {
      if (!await ConnectivityUtils.checkConnection() && isInternetConnected) {
        setState(() => isInternetConnected = false);

        if (!mounted) return;
        Toastification().show(
          context: context,
          title: Text(LocaleKeys.alert_notify_internet_title.tr(context: context)),
          description: Text(LocaleKeys.alert_notify_internet_description.tr(context: context)),
          type: ToastificationType.info,
          style: ToastificationStyle.flat,
          alignment: Alignment.bottomCenter,
          autoCloseDuration: Duration(seconds: 2),
          animationDuration: Duration(milliseconds: 500),
        );
      }

      if (await ConnectivityUtils.checkConnection() && !isInternetConnected) {
        setState(() => isInternetConnected = true);
      }
    });
  }

  void cancelWiFiChecker() {
    if (wifiCheckerTask!.isActive) {
      wifiCheckerTask?.cancel();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    database = DatabaseManager();
    fetchAllEvents(path: 'api/event');

    setState(() {
      isWiFiConnect = WiFiManager.isESPWiFiConnected;
      isDeviceConnect = BluetoothManager.isBluetoothConnected;
    });

    startWiFiChecker();
    espStatusChecker = Timer.periodic(1.seconds, (timer) {
      setState(() {
        isWiFiConnect = WiFiManager.isESPWiFiConnected;
        isDeviceConnect = BluetoothManager.isBluetoothConnected;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);

    wifiCheckerTask?.cancel();
    espStatusChecker?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused) {
      cancelWiFiChecker();
    } else if (state == AppLifecycleState.resumed) {
      startWiFiChecker();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              SizedBox(height: 16.0),
              Card(
                margin: const EdgeInsets.all(12.0),
                clipBehavior: Clip.antiAlias,
                elevation: 10.0,
                child: Column(
                  children: <Widget>[
                    Container(
                      height: 50.0,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green.shade300, Colors.green.shade700],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(Icons.event),
                          SizedBox(width: 8.0),
                          Text(
                            LocaleKeys.home_page_event_title_active.tr(context: context),
                            style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: activeEvent != null
                          ? Column(
                              children: <Widget>[
                                Text(
                                  activeEvent!.name,
                                  style: const TextStyle(
                                    fontSize: 24.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                Text(
                                  DateFormat(
                                    'dd MMMM yyyy, HH:mm',
                                  ).format(DateTime.parse(activeEvent!.eventDate)),
                                  style: TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  activeEvent!.location,
                                  style: TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            )
                          : Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child: CircularProgressIndicator(),
                            ),
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.all(10.0),
                height: 180.0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        elevation: 5.0,
                        child: Column(
                          children: <Widget>[
                            Container(
                              height: 50.0,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.green.shade300, Colors.green.shade700],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Image.asset("assets/esp32-icon.png", width: 36.0, height: 36.0),
                                  SizedBox(width: 4.0),
                                  Text(
                                    LocaleKeys.home_page_esp_statuses_title.tr(context: context),
                                    style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      Icon(Icons.bluetooth),
                                      SizedBox(width: 8.0),
                                      Text(
                                        isDeviceConnect
                                            ? LocaleKeys.home_page_esp_statuses_status_connected.tr(
                                                context: context,
                                              )
                                            : LocaleKeys.home_page_esp_statuses_status_disconnected
                                                  .tr(context: context),
                                        style: const TextStyle(fontSize: 16.0),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 16.0),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      Icon(Icons.wifi),
                                      SizedBox(width: 8.0),
                                      Text(
                                        isWiFiConnect
                                            ? LocaleKeys.home_page_esp_statuses_status_connected.tr(
                                                context: context,
                                              )
                                            : LocaleKeys.home_page_esp_statuses_status_disconnected
                                                  .tr(context: context),
                                        style: const TextStyle(fontSize: 16.0),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 12.0),
                    Expanded(
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        elevation: 10.0,
                        child: Column(
                          children: <Widget>[
                            Container(
                              height: 50.0,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.green.shade300, Colors.green.shade700],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Icon(Icons.add_chart),
                                  SizedBox(width: 8.0),
                                  Text(
                                    LocaleKeys.home_page_event_title_total.tr(context: context),
                                    style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: isDataLoaded
                                    ? Text(
                                        eventsData.length.toString(),
                                        style: const TextStyle(
                                          fontSize: 48.0,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : CircularProgressIndicator(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 80.0),
              ElevatedButton(
                onPressed: () async {
                  if (!isWiFiConnect) {
                    Toastification().show(
                      context: context,
                      title: Text(LocaleKeys.alert_notify_esp_title.tr(context: context)),
                      description: Text(
                        LocaleKeys.alert_notify_esp_description_no_wifi.tr(context: context),
                      ),
                      type: ToastificationType.info,
                      style: ToastificationStyle.flat,
                      alignment: Alignment.bottomCenter,
                      autoCloseDuration: Duration(seconds: 2),
                      animationDuration: Duration(milliseconds: 500),
                    );
                    return;
                  }

                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (BuildContext context) {
                        return ControlPanelPage();
                      },
                    ),
                  );

                  setState(() {
                    isWiFiConnect = WiFiManager.isESPWiFiConnected;
                    isDeviceConnect = BluetoothManager.isBluetoothConnected;
                  });
                },
                style: ButtonStyle(minimumSize: WidgetStateProperty.all(Size(200, 50))),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.laptop),
                    SizedBox(width: 16.0),
                    Text(
                      LocaleKeys.home_page_button_control.tr(context: context),
                      style: TextStyle(fontSize: 16.0),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.0),
              ElevatedButton(
                onPressed: () async {
                  if (!isDeviceConnect) {
                    Toastification().show(
                      context: context,
                      title: Text(LocaleKeys.alert_notify_esp_title.tr(context: context)),
                      description: Text(
                        LocaleKeys.alert_notify_esp_description_no_bluetooth.tr(context: context),
                      ),
                      type: ToastificationType.info,
                      style: ToastificationStyle.flat,
                      alignment: Alignment.bottomCenter,
                      autoCloseDuration: Duration(seconds: 2),
                      animationDuration: Duration(milliseconds: 500),
                    );
                    return;
                  }

                  if (isWiFiConnect) {
                    Toastification().show(
                      context: context,
                      title: Text(LocaleKeys.alert_notify_esp_title.tr(context: context)),
                      description: Text(
                        LocaleKeys.alert_notify_esp_description_wifi_connected.tr(context: context),
                      ),
                      type: ToastificationType.info,
                      style: ToastificationStyle.flat,
                      alignment: Alignment.bottomCenter,
                      autoCloseDuration: Duration(seconds: 2),
                      animationDuration: Duration(milliseconds: 500),
                    );
                    return;
                  }

                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (BuildContext context) {
                        return WiFiPage();
                      },
                    ),
                  );

                  setState(() {
                    isWiFiConnect = WiFiManager.isESPWiFiConnected;
                    isDeviceConnect = BluetoothManager.isBluetoothConnected;
                  });
                },
                style: ButtonStyle(minimumSize: WidgetStateProperty.all(Size(200, 50))),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.wifi),
                    SizedBox(width: 16.0),
                    Text(
                      LocaleKeys.home_page_button_setup.tr(context: context),
                      style: TextStyle(fontSize: 16.0),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 30.0),
            ],
          ),
        ),
      ),
    );
  }
}
