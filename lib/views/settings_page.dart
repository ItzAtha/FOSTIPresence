import 'dart:async';

import 'package:attendance_management/translations/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_android/shared_preferences_android.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:toastification/toastification.dart';

import '../manager/bluetooth_manager.dart';
import '../utilities/language.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  late bool isDeviceConnect;
  late Language selectedLanguage;
  late SharedPreferencesAsync preferences;
  late SharedPreferencesAsyncAndroidOptions prefsOption;

  Timer? btCheckerTask;
  late bool autoReconnectBTEnable;
  late bool autoReconnectWiFiEnable;

  Future<void> loadSettingsData() async {
    bool? autoReconnectBT = await preferences.getBool('autoReconnectBT');
    bool? autoReconnectWiFi = await preferences.getBool('autoReconnectWiFi');

    setState(() {
      autoReconnectBTEnable = autoReconnectBT ?? false;
      autoReconnectWiFiEnable = autoReconnectWiFi ?? true;
    });
  }

  @override
  void initState() {
    super.initState();

    prefsOption = SharedPreferencesAsyncAndroidOptions(
      backend: SharedPreferencesAndroidBackendLibrary.SharedPreferences,
      originalSharedPreferencesOptions: AndroidSharedPreferencesStoreOptions(
        fileName: 'settings_data',
      ),
    );

    preferences = SharedPreferencesAsync(options: prefsOption);
    loadSettingsData();

    setState(() => isDeviceConnect = BluetoothManager.isBluetoothConnected);
    btCheckerTask = Timer.periodic(1.seconds, (timer) {
      setState(() => isDeviceConnect = BluetoothManager.isBluetoothConnected);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    setState(
      () => selectedLanguage = Language.allLanguages.firstWhere(
        (lang) => lang.code == context.locale.languageCode,
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    btCheckerTask?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: EdgeInsets.all(16.0),
        child: ListView(
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  LocaleKeys.setting_page_general_app_title.tr(context: context),
                  textAlign: TextAlign.start,
                  style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                ),
                Divider(color: Colors.grey, thickness: 1.5),
                SizedBox(height: 10.0),
                ListTile(
                  title: Text(
                    LocaleKeys.setting_page_general_app_auto_reconnect_bt_title.tr(
                      context: context,
                    ),
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    LocaleKeys.setting_page_general_app_auto_reconnect_bt_description.tr(
                      context: context,
                    ),
                  ),
                  onTap: () async {
                    // Not yet implements, will be implements in next app update
                    Toastification().show(
                      context: context,
                      title: Text(LocaleKeys.alert_notify_coming_soon_title.tr(context: context)),
                      description: Text(
                        LocaleKeys.alert_notify_coming_soon_description.tr(context: context),
                      ),
                      type: ToastificationType.info,
                      style: ToastificationStyle.flat,
                      alignment: Alignment.bottomCenter,
                      autoCloseDuration: Duration(seconds: 2),
                      animationDuration: Duration(milliseconds: 500),
                    );
                  },
                  trailing: Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: autoReconnectBTEnable,
                      onChanged: (bool value) async {
                        // Not yet implements, will be implements in next app update
                        Toastification().show(
                          context: context,
                          title: Text(
                            LocaleKeys.alert_notify_coming_soon_title.tr(context: context),
                          ),
                          description: Text(
                            LocaleKeys.alert_notify_coming_soon_description.tr(context: context),
                          ),
                          type: ToastificationType.info,
                          style: ToastificationStyle.flat,
                          alignment: Alignment.bottomCenter,
                          autoCloseDuration: Duration(seconds: 2),
                          animationDuration: Duration(milliseconds: 500),
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(height: 5.0),
                ExpansionTile(
                  title: Text(
                    LocaleKeys.setting_page_general_app_language_title.tr(context: context),
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    LocaleKeys.setting_page_general_app_language_description.tr(context: context),
                  ),
                  trailing: Text(selectedLanguage.name, style: TextStyle(fontSize: 12.0)),
                  children: <Widget>[
                    RadioGroup(
                      groupValue: selectedLanguage,
                      onChanged: (value) {
                        setState(() {
                          selectedLanguage = value!;
                          context.setLocale(Locale(selectedLanguage.code));
                        });
                      },
                      child: Column(
                        children: <Widget>[
                          for (final lang in Language.allLanguages)
                            RadioListTile(title: Text(lang.name), value: lang),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.0),
                Text(
                  LocaleKeys.setting_page_general_esp_title.tr(context: context),
                  textAlign: TextAlign.start,
                  style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                ),
                Text(
                  LocaleKeys.setting_page_general_esp_subtitle.tr(context: context),
                  textAlign: TextAlign.start,
                  style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500, color: Colors.grey),
                ),
                Divider(color: Colors.grey, thickness: 1.5),
                SizedBox(height: 10.0),
                ListTile(
                  title: Text(
                    LocaleKeys.setting_page_general_esp_auto_reconnect_wifi_title.tr(
                      context: context,
                    ),
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    LocaleKeys.setting_page_general_esp_auto_reconnect_wifi_description.tr(
                      context: context,
                    ),
                  ),
                  enabled: isDeviceConnect,
                  onTap: () async {
                    // Not yet implements, will be implements in next app update
                    Toastification().show(
                      context: context,
                      title: Text(LocaleKeys.alert_notify_coming_soon_title.tr(context: context)),
                      description: Text(
                        LocaleKeys.alert_notify_coming_soon_description.tr(context: context),
                      ),
                      type: ToastificationType.info,
                      style: ToastificationStyle.flat,
                      alignment: Alignment.bottomCenter,
                      autoCloseDuration: Duration(seconds: 2),
                      animationDuration: Duration(milliseconds: 500),
                    );
                  },
                  trailing: Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: autoReconnectWiFiEnable,
                      onChanged: isDeviceConnect
                          ? (bool value) async {
                              // Not yet implements, will be implements in next app update
                              Toastification().show(
                                context: context,
                                title: Text(
                                  LocaleKeys.alert_notify_coming_soon_title.tr(context: context),
                                ),
                                description: Text(
                                  LocaleKeys.alert_notify_coming_soon_description.tr(
                                    context: context,
                                  ),
                                ),
                                type: ToastificationType.info,
                                style: ToastificationStyle.flat,
                                alignment: Alignment.bottomCenter,
                                autoCloseDuration: Duration(seconds: 2),
                                animationDuration: Duration(milliseconds: 500),
                              );
                            }
                          : null,
                    ),
                  ),
                ),
                SizedBox(height: 16.0),
                Text(
                  LocaleKeys.setting_page_more_info_title.tr(context: context),
                  textAlign: TextAlign.start,
                  style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                ),
                Divider(color: Colors.grey, thickness: 1.5),
                SizedBox(height: 10.0),
                ListTile(
                  title: Text(
                    LocaleKeys.setting_page_more_info_user_guidebook_title.tr(context: context),
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    LocaleKeys.setting_page_more_info_user_guidebook_description.tr(
                      context: context,
                    ),
                  ),
                  onTap: () {
                    // Not yet implements, will be implements in next app update
                    Toastification().show(
                      context: context,
                      title: Text(LocaleKeys.alert_notify_coming_soon_title.tr(context: context)),
                      description: Text(
                        LocaleKeys.alert_notify_coming_soon_description.tr(context: context),
                      ),
                      type: ToastificationType.info,
                      style: ToastificationStyle.flat,
                      alignment: Alignment.bottomCenter,
                      autoCloseDuration: Duration(seconds: 2),
                      animationDuration: Duration(milliseconds: 500),
                    );
                  },
                ),
                ListTile(
                  title: Text(
                    LocaleKeys.setting_page_more_info_about_app_title.tr(context: context),
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    LocaleKeys.setting_page_more_info_about_app_description.tr(context: context),
                  ),
                  onTap: () async {
                    final PackageInfo info = await PackageInfo.fromPlatform();
                    if (!context.mounted) return;

                    showAboutDialog(
                      context: context,
                      applicationIcon: Image.asset("assets/app-icon.png", scale: 12.0),
                      applicationName: info.appName,
                      applicationVersion: 'v${info.version} (Build ${info.buildNumber})',
                      applicationLegalese: '\u{a9} 2025 Atha - FOSTI UMS',
                      children: <Widget>[
                        SizedBox(height: 24.0),
                        Text(
                          LocaleKeys.setting_page_more_info_about_app_dialog.tr(context: context),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
