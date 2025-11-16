import 'dart:async';
import 'dart:convert';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:attendance_management/utilities/members_data_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:easy_localization/easy_localization.dart';

import '../manager/bluetooth_manager.dart';
import '../translations/locale_keys.g.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<StatefulWidget> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  String consoleText = "";
  List<String> consoleTextList = [];

  Timer? consoleTask;
  bool isAutoScroll = true;
  bool isDisconnected = false;
  bool onRegisterCard = false;

  bool isNIMNotFound = false;
  bool isExcelFileFound = false;

  final ScrollController consoleScrollController = ScrollController();
  final TextEditingController consoleChatController = TextEditingController();

  late MembersData membersData;
  late BluetoothManager bluetoothManager;

  void sendMessage({required String message, bool newLine = true, bool allowEmptyMessage = false}) {
    if (message.trim().isEmpty && !allowEmptyMessage) return;

    if (consoleTextList.length >= 500) {
      consoleTextList.removeAt(0);
    }

    if (!newLine) {
      consoleTextList[consoleTextList.length - 1] = consoleTextList[consoleTextList.length - 1]
          .substring(0, consoleTextList.elementAt(consoleTextList.length - 1).length - 2);
      consoleTextList.add("$message\n");
    } else {
      String formattedText = message;
      if (!message.endsWith("\n")) {
        formattedText += "\n";
      }
      consoleTextList.add(formattedText);
    }

    setState(() => consoleText = consoleTextList.join(""));
  }

  @override
  void initState() {
    super.initState();
    bluetoothManager = BluetoothManager(context: context);
    membersData = MembersData(fileName: 'Daftar Anggota FOSTI.xlsx');

    sendMessage(message: "Load FOSTI members data excel...");
    membersData
        .loadData()
        .then((isSuccess) {
          if (!mounted) return;

          if (isSuccess) {
            isExcelFileFound = true;
            sendMessage(message: "FOSTI members data loaded successfully.");
          } else {
            sendMessage(message: "Failed to load FOSTI members data. Maybe excel file not set?");
          }
          sendMessage(message: "", allowEmptyMessage: true);

          BluetoothManager.clearReceivedMessage();
          BluetoothManager.clearReceivedData();

          BluetoothDevice? device = BluetoothManager.getConnectedDevice;
          if (device != null) {
            bluetoothManager.sendBluetoothData(device, '1');
          }
        })
        .catchError((error) {
          print("Error loading FOSTI members data excel: $error");
          sendMessage(
            message: "Error loading FOSTI members data excel. Maybe excel file is corrupted?",
          );
          sendMessage(message: "", allowEmptyMessage: true);
        });

    consoleTask = Timer.periodic(500.milliseconds, (timer) {
      dynamic receivedMessage;

      List<String> messages = [
        BluetoothManager.getReceivedData,
        ...BluetoothManager.getReceivedMessage,
      ];
      BluetoothManager.clearReceivedMessage();

      if (!BluetoothManager.isBluetoothConnected) {
        if (!isDisconnected) {
          isDisconnected = true;
          sendMessage(message: "Bluetooth disconnected from ESP32!");
        }
        return;
      } else {
        isDisconnected = false;
      }

      for (String message in messages) {
        try {
          receivedMessage = jsonDecode(message) as Map<String, dynamic>;
        } catch (e) {
          receivedMessage = message;
        }

        if (receivedMessage is String) {
          sendMessage(message: receivedMessage);
        } else if (receivedMessage is Map<String, dynamic>) {
          receivedMessage.forEach((key, value) {
            if (key == "onRegisterCard" && value is bool) {
              isNIMNotFound = false;
              setState(() => onRegisterCard = value);

              if (!onRegisterCard && consoleChatController.text.isNotEmpty) {
                setState(() => consoleChatController.text = "");
              }
            }
          });
        }
      }

      if (isAutoScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          consoleScrollController.animateTo(
            consoleScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    consoleTask?.cancel();

    BluetoothDevice? device = BluetoothManager.getConnectedDevice;
    if (device != null) {
      if (onRegisterCard) {
        bluetoothManager.sendBluetoothData(device, 'cancel');
      }
      bluetoothManager.sendBluetoothData(device, 'cancel');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text(LocaleKeys.control_panel_page_title_register.tr(context: context)),
        ),
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
      body: Center(
        child: Column(
          children: <Widget>[
            Expanded(
              child: Container(
                margin: EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0),
                padding: EdgeInsets.all(16.0),
                width: double.infinity,
                color: Colors.green.shade900.withValues(alpha: 0.2),
                child: Scrollbar(
                  child: SingleChildScrollView(
                    controller: consoleScrollController,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        children: <Widget>[
                          Text(
                            consoleText,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              color: Colors.greenAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.all(8.0),
              padding: EdgeInsets.all(16.0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: consoleChatController,
                      enabled: onRegisterCard,
                      decoration: InputDecoration(
                        hintText: LocaleKeys.control_panel_page_input_box.tr(context: context),
                      ),
                      onSubmitted: (value) {
                        String messageValue = value.trim();

                        sendMessage(message: messageValue, newLine: false);
                        BluetoothDevice? device = BluetoothManager.getConnectedDevice;
                        if (device == null) return;

                        if (!isNIMNotFound &&
                            isExcelFileFound &&
                            messageValue.toLowerCase() != "cancel") {
                          sendMessage(message: "", allowEmptyMessage: true);
                          sendMessage(message: "Checking NIM in excel file....");
                          List<String> data = membersData.findStudentByNIM(
                            messageValue.toUpperCase(),
                          );

                          if (data.isNotEmpty) {
                            sendMessage(message: "NIM found: ${data[2]} - ${data[1]}");
                            sendMessage(message: "Using automatic presence mode.");

                            String decodedData = jsonEncode(data);
                            messageValue = decodedData;
                            setState(() => onRegisterCard = false);
                          } else {
                            sendMessage(message: "NIM not found in FOSTI members excel data.");
                            sendMessage(message: "Using manual presence mode.");
                            isNIMNotFound = true;
                          }
                        }

                        bluetoothManager.sendBluetoothData(device, messageValue);
                        print("Value: $messageValue");
                        consoleChatController.text = "";
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: LocaleKeys.control_panel_page_button_auto_scroll.tr(context: context),
                    isSelected: isAutoScroll,
                    onPressed: () => setState(() => isAutoScroll = !isAutoScroll),
                    selectedIcon: Icon(Icons.play_circle),
                    icon: Icon(Icons.stop_circle),
                  ),
                  IconButton(
                    tooltip: LocaleKeys.control_panel_page_button_clear_monitor.tr(
                      context: context,
                    ),
                    onPressed: () => setState(() {
                      consoleTextList.clear();
                      consoleText = "";
                    }),
                    icon: Icon(Icons.clear),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
