import 'dart:async';
import 'dart:convert';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:easy_localization/easy_localization.dart';

import '../manager/bluetooth_manager.dart';
import '../translations/locale_keys.g.dart';

class PresencePage extends StatefulWidget {
  const PresencePage({super.key});

  @override
  State<StatefulWidget> createState() => _PresencePageState();
}

class _PresencePageState extends State<PresencePage> {
  String consoleText = "";
  List<String> consoleTextList = [];

  Timer? consoleTask;
  String? selectedMode;
  bool isAutoScroll = true;
  bool isDisconnected = false;
  bool onManualPresence = false;

  final ScrollController consoleScrollController = ScrollController();
  final TextEditingController consoleChatController = TextEditingController();

  late List<String> presenceModeList;
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

    sendMessage(message: "Select presence options from dropdown below!");

    BluetoothManager.clearReceivedMessage();
    BluetoothManager.clearReceivedData();

    BluetoothDevice? device = BluetoothManager.getConnectedDevice;
    if (device != null) {
      bluetoothManager.sendBluetoothData(device, '2');
    }

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
          sendMessage(message: "Disconnected from device!");
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
            if (key == "onManualPresence" && value is bool) {
              setState(() => onManualPresence = value);

              if (!onManualPresence) {
                setState(() => selectedMode = null);
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
  void didChangeDependencies() {
    super.didChangeDependencies();

    presenceModeList = [
      LocaleKeys.control_panel_page_presence_mode_list_participant.tr(context: context),
      LocaleKeys.control_panel_page_presence_mode_list_committee.tr(context: context),
      LocaleKeys.control_panel_page_presence_mode_list_manual.tr(context: context),
    ];
  }

  @override
  void dispose() {
    super.dispose();
    consoleTask?.cancel();

    BluetoothDevice? device = BluetoothManager.getConnectedDevice;
    if (device != null) {
      bluetoothManager.sendBluetoothData(device, '${presenceModeList.length + 1}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text(LocaleKeys.control_panel_page_title_presence.tr(context: context)),
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
              child: Column(
                children: <Widget>[
                  DropdownButton<String>(
                    value: selectedMode,
                    hint: Text(
                      LocaleKeys.control_panel_page_presence_mode_title.tr(context: context),
                    ),
                    items: presenceModeList.map((item) {
                      return DropdownMenuItem<String>(
                        enabled: !onManualPresence,
                        value: item,
                        child: Text(
                          presenceModeList.indexOf(item) != (presenceModeList.length - 1)
                              ? LocaleKeys.control_panel_page_presence_mode_type.tr(
                                  context: context,
                                  namedArgs: {'mode': item},
                                )
                              : item,
                        ),
                      );
                    }).toList(),
                    onChanged: (String? value) {
                      if (value == selectedMode) return;
                      setState(() => selectedMode = value);

                      BluetoothDevice? device = BluetoothManager.getConnectedDevice;
                      if (device != null) {
                        bluetoothManager.sendBluetoothData(
                          device,
                          '${presenceModeList.indexOf(value!) + 1}',
                        );
                      }
                    },
                  ),
                  SizedBox(height: 5.0),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: consoleChatController,
                          enabled: onManualPresence,
                          decoration: InputDecoration(
                            hintText: LocaleKeys.control_panel_page_input_box.tr(context: context),
                          ),
                          onSubmitted: (value) {
                            sendMessage(message: value, newLine: false);
                            if (selectedMode == "Manual") {
                              BluetoothDevice? device = BluetoothManager.getConnectedDevice;
                              if (device != null) {
                                bluetoothManager.sendBluetoothData(device, value);
                              }
                            }
                            consoleChatController.text = "";
                          },
                        ),
                      ),
                      IconButton(
                        tooltip: LocaleKeys.control_panel_page_button_auto_scroll.tr(
                          context: context,
                        ),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
