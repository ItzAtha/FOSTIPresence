import 'dart:async';
import 'dart:io';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:animations/animations.dart';
import 'package:attendance_management/manager/bluetooth_manager.dart';
import 'package:attendance_management/manager/database_manager.dart';
import 'package:attendance_management/translations/locale_keys.g.dart';
import 'package:attendance_management/views/members_page.dart';
import 'package:attendance_management/views/presence_menu_page.dart';
import 'package:attendance_management/views/register_page.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:toastification/toastification.dart';
import 'package:path/path.dart' as path;

import '../manager/events_manager.dart';

class ControlPanelPage extends StatefulWidget {
  const ControlPanelPage({super.key});

  @override
  State<ControlPanelPage> createState() => _ControlPanelPageState();
}

class _ControlPanelPageState extends State<ControlPanelPage> {
  Timer? eventDataChecker;
  bool isDeviceConnect = false;
  bool isEventDataEmpty = false;

  late DatabaseManager database;
  late BluetoothManager bluetoothManager;

  @override
  void initState() {
    super.initState();

    database = DatabaseManager();
    bluetoothManager = BluetoothManager(context: context);

    eventDataChecker = Timer.periodic(500.milliseconds, (timer) async {
      setState(() => isDeviceConnect = BluetoothManager.isBluetoothConnected);

      dynamic rawEventData = await database.readData(urlPath: 'api/event');
      if (rawEventData == null) return;

      if (!mounted) return;

      List<Event> eventDataList = rawEventData as List<Event>;
      setState(() => isEventDataEmpty = eventDataList.isEmpty);
    });
  }

  @override
  void dispose() {
    super.dispose();
    eventDataChecker?.cancel();
  }

  void showEmptyEventDialog() {
    var emptyDialog = SimpleDialog(
      title: Center(child: Text(LocaleKeys.alert_notify_event_title.tr(context: context))),
      children: <Widget>[
        Text(
          LocaleKeys.alert_notify_event_description_no_data_dialog.tr(context: context),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 25.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(LocaleKeys.control_page_menu_button_ok.tr(context: context)),
            ),
            SizedBox(width: 20.0),
          ],
        ),
      ],
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return emptyDialog;
      },
    );
  }

  void showESP32NotConnectDialog() {
    var esp32NotConnectDialog = SimpleDialog(
      title: Center(child: Text(LocaleKeys.alert_notify_esp_title.tr(context: context))),
      children: <Widget>[
        Text(
          LocaleKeys.alert_notify_esp_description_no_esp.tr(context: context),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 25.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(LocaleKeys.control_page_menu_button_ok.tr(context: context)),
            ),
            SizedBox(width: 20.0),
          ],
        ),
      ],
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return esp32NotConnectDialog;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(child: Text(LocaleKeys.control_page_title.tr(context: context))),
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
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: <Widget>[
              SizedBox(height: 50.0),
              Card(
                margin: const EdgeInsets.all(16.0),
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
                          Icon(Icons.add_card_outlined),
                          SizedBox(width: 4.0),
                          Text(
                            LocaleKeys.control_page_menu_register_title.tr(context: context),
                            style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: <Widget>[
                          Text(
                            LocaleKeys.control_page_menu_register_description.tr(context: context),
                            style: const TextStyle(fontSize: 14.2),
                            textAlign: TextAlign.justify,
                          ),
                          SizedBox(height: 8.0),
                          Divider(color: Colors.grey, thickness: 1.5),
                          SizedBox(height: 8.0),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              SizedBox(
                                width: 42.0,
                                height: 42.0,
                                child: FittedBox(
                                  child: FloatingActionButton(
                                    heroTag: "setDataButton",
                                    tooltip: LocaleKeys.control_page_menu_register_action_set_excel
                                        .tr(context: context),
                                    onPressed: () async {
                                      FilePickerResult? result = await FilePicker.platform
                                          .pickFiles(
                                            type: FileType.custom,
                                            allowedExtensions: ['xlsx'],
                                          );

                                      if (result != null) {
                                        File file = File(result.files.single.path!);
                                        Directory? appDocDir = await getExternalStorageDirectory();
                                        String newPath = path.join(
                                          appDocDir!.path,
                                          result.files.single.name,
                                        );

                                        try {
                                          File savedFile = await file.copy(newPath);
                                          if (!context.mounted) return;

                                          print("File saved to: ${savedFile.path}");
                                          Toastification().show(
                                            context: context,
                                            title: Text(
                                              LocaleKeys.alert_notify_file_title.tr(
                                                context: context,
                                              ),
                                            ),
                                            description: Text(
                                              LocaleKeys.alert_notify_file_description_success_set
                                                  .tr(
                                                    context: context,
                                                    namedArgs: {
                                                      'fileName': result.files.single.name,
                                                    },
                                                  ),
                                            ),
                                            type: ToastificationType.success,
                                            style: ToastificationStyle.flat,
                                            alignment: Alignment.bottomCenter,
                                            autoCloseDuration: Duration(seconds: 2),
                                            animationDuration: Duration(milliseconds: 500),
                                          );
                                        } catch (e) {
                                          if (!context.mounted) return;
                                          print("Error saving file: $e");

                                          Toastification().show(
                                            context: context,
                                            title: Text(
                                              LocaleKeys.alert_notify_file_title.tr(
                                                context: context,
                                              ),
                                            ),
                                            description: Text(
                                              LocaleKeys.alert_notify_file_description_fail_set.tr(
                                                context: context,
                                                namedArgs: {'fileName': result.files.single.name},
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
                                    },
                                    shape: CircleBorder(),
                                    backgroundColor: Colors.green.shade400,
                                    child: Icon(
                                      Icons.add,
                                      color: Theme.of(context).brightness == Brightness.light
                                          ? Colors.black
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              OpenContainer(
                                transitionDuration: 500.ms,
                                openBuilder: (BuildContext context, VoidCallback closeContainer) {
                                  return const MemberPage();
                                },
                                closedBuilder: (BuildContext context, VoidCallback openContainer) {
                                  return SizedBox(
                                    width: 42.0,
                                    height: 42.0,
                                    child: FittedBox(
                                      child: FloatingActionButton(
                                        heroTag: "showDataButton",
                                        tooltip: LocaleKeys
                                            .control_page_menu_register_action_show_members
                                            .tr(context: context),
                                        onPressed: openContainer,
                                        shape: CircleBorder(),
                                        backgroundColor: Colors.blue.shade600,
                                        child: Icon(
                                          Icons.person,
                                          color: Theme.of(context).brightness == Brightness.light
                                              ? Colors.black
                                              : Colors.white,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                closedShape: const CircleBorder(),
                                closedColor: Colors.transparent,
                                closedElevation: 6.0,
                              ),
                              SizedBox(width: 32.0),
                              ElevatedButton(
                                onPressed: !isEventDataEmpty && isDeviceConnect
                                    ? () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (BuildContext context) {
                                              return RegisterPage();
                                            },
                                          ),
                                        );
                                      }
                                    : !isDeviceConnect
                                    ? showESP32NotConnectDialog
                                    : showEmptyEventDialog,
                                style: ButtonStyle(
                                  minimumSize: WidgetStateProperty.all(Size(120, 40)),
                                ),
                                child: Text(
                                  LocaleKeys.control_page_menu_button_open.tr(context: context),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Card(
                margin: const EdgeInsets.all(16.0),
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
                          Icon(Icons.co_present),
                          SizedBox(width: 8.0),
                          Text(
                            LocaleKeys.control_page_menu_presence_title.tr(context: context),
                            style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: <Widget>[
                          Text(
                            LocaleKeys.control_page_menu_presence_description.tr(context: context),
                            style: const TextStyle(fontSize: 14.2),
                            textAlign: TextAlign.justify,
                          ),
                          SizedBox(height: 8.0),
                          Divider(color: Colors.grey, thickness: 1.5),
                          SizedBox(height: 8.0),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: !isEventDataEmpty && isDeviceConnect
                                  ? () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (BuildContext context) {
                                            return PresencePage();
                                          },
                                        ),
                                      );
                                    }
                                  : !isDeviceConnect
                                  ? showESP32NotConnectDialog
                                  : showEmptyEventDialog,
                              style: ButtonStyle(
                                minimumSize: WidgetStateProperty.all(Size(120, 40)),
                              ),
                              child: Text(
                                LocaleKeys.control_page_menu_button_open.tr(context: context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Card(
                margin: const EdgeInsets.all(16.0),
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
                          Icon(Icons.file_present),
                          SizedBox(width: 4.0),
                          Text(
                            LocaleKeys.control_page_menu_presence_logs_title.tr(context: context),
                            style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: <Widget>[
                          Text(
                            LocaleKeys.control_page_menu_presence_logs_description.tr(
                              context: context,
                            ),
                            style: const TextStyle(fontSize: 14.2),
                            textAlign: TextAlign.justify,
                          ),
                          SizedBox(height: 8.0),
                          Divider(color: Colors.grey, thickness: 1.5),
                          SizedBox(height: 8.0),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: null,
                              style: ButtonStyle(
                                minimumSize: WidgetStateProperty.all(Size(120, 40)),
                              ),
                              child: Text(
                                LocaleKeys.control_page_menu_button_open.tr(context: context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 50.0),
            ],
          ),
        ),
      ),
    );
  }
}
