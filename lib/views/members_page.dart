import 'dart:async';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:attendance_management/manager/members_manager.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:toastification/toastification.dart';

import '../translations/locale_keys.g.dart';
import '../utilities/connectivity_utils.dart';
import '../manager/database_manager.dart';

class MemberPage extends StatefulWidget {
  const MemberPage({super.key});

  @override
  State<StatefulWidget> createState() => _MemberPageState();
}

enum Answer { YES, NO }

class _MemberPageState extends State<MemberPage> with WidgetsBindingObserver {
  int currentPage = 1;
  final int maxPerPage = 12;

  late bool isLoadingDone;
  bool isDataLoaded = false;

  Timer? wifiCheckerTask;
  bool isInternetConnected = false;

  List<Member> membersData = [];
  List<Member> filteredMembersData = [];

  String? selectedMode;
  final List<String> divisionList = ['RISTEK', 'HUBPUB', 'KEOR', 'BPHI'];

  final ScrollController scrollController = ScrollController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController memberNameController = TextEditingController();
  final TextEditingController memberNIMController = TextEditingController();

  late DatabaseManager database;
  StreamSubscription<Map<String, dynamic>?>? backgroundTaskSub;

  Future<void> fetchAllMembers({required String path}) async {
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

    dynamic rawEventsData = await database.readData(urlPath: path);
    if (!mounted) return;

    if (rawEventsData != null) {
      membersData = rawEventsData as List<Member>;
      membersData.sort((a, b) => a.name.compareTo(b.name));

      if (membersData.isNotEmpty) {
        setState(() {
          filteredMembersData = membersData;
          isDataLoaded = true;
        });
      } else {
        Toastification().show(
          context: context,
          title: Text(LocaleKeys.alert_notify_member_title.tr(context: context)),
          description: Text(
            LocaleKeys.alert_notify_member_description_no_data.tr(context: context),
          ),
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
        title: Text(LocaleKeys.alert_notify_member_title.tr(context: context)),
        description: Text(LocaleKeys.alert_notify_member_description_not_load.tr(context: context)),
        type: ToastificationType.info,
        style: ToastificationStyle.flat,
        alignment: Alignment.bottomCenter,
        autoCloseDuration: Duration(seconds: 2),
        animationDuration: Duration(milliseconds: 500),
      );
    }

    setState(() => isLoadingDone = true);
  }

  Map<int, List<Widget>> getEventList(List<Member> jsonData) {
    List<Widget> memberList = [];
    Map<int, List<Widget>> memberListPerPage = {};
    int indexPage = 1;

    for (final member in jsonData) {
      memberList.add(
        RepaintBoundary(
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Card(
                margin: const EdgeInsets.all(16.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.person, size: 40.0),
                      SizedBox(width: 16.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              member.name,
                              style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 6.0),
                            Text('NIM: ${member.nim}', style: TextStyle(fontSize: 16.0)),
                            SizedBox(height: 4.0),
                            Text(
                              LocaleKeys.member_page_division_label.tr(
                                context: context,
                                namedArgs: {'division': member.division},
                              ),
                              style: TextStyle(fontSize: 16.0),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 32,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    SizedBox(
                      width: 45.0,
                      height: 45.0,
                      child: FittedBox(
                        child: FloatingActionButton(
                          heroTag: "editMemberButton${member.id}",
                          tooltip: LocaleKeys.member_page_button_edit.tr(context: context),
                          onPressed: () => onEditButton(context: context, memberData: member),
                          shape: CircleBorder(),
                          backgroundColor: Colors.orange.shade600,
                          child: Icon(
                            Icons.edit,
                            color: Theme.of(context).brightness == Brightness.light
                                ? Colors.black
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      if (memberList.length == maxPerPage || member == jsonData.last) {
        memberListPerPage[indexPage++] = memberList;
        memberList = [];
      }
    }

    return memberListPerPage;
  }

  Future<void> onEditButton({required BuildContext context, required Member memberData}) async {
    Member member = memberData;

    if (!await ConnectivityUtils.checkConnection()) {
      if (!context.mounted) return;

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
      return;
    }

    memberNameController.text = member.name;
    memberNIMController.text = member.nim;
    setState(() => selectedMode = member.division);

    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              title: Text(
                LocaleKeys.member_page_dialog_title.tr(context: context),
                textAlign: TextAlign.center,
              ),
              content: Form(
                key: formKey,
                canPop: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SizedBox(height: 8.0),
                      TextFormField(
                        controller: memberNameController,
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: LocaleKeys.member_page_dialog_field_name.tr(context: context),
                          hintText: "Andi Setya Budi",
                          icon: Icon(Icons.person, size: 24.0),
                          border: OutlineInputBorder(),
                          errorMaxLines: 2,
                        ),
                        keyboardType: TextInputType.name,
                        textInputAction: TextInputAction.next,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (String? value) {
                          if (value.toString().isEmpty) {
                            return LocaleKeys.member_page_dialog_validation_name_required.tr(
                              context: context,
                            );
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 14.0),
                      TextFormField(
                        controller: memberNIMController,
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: LocaleKeys.member_page_dialog_field_nim.tr(context: context),
                          hintText: "L200250001",
                          icon: Icon(Icons.perm_identity, size: 24.0),
                          border: OutlineInputBorder(),
                          errorMaxLines: 2,
                        ),
                        keyboardType: TextInputType.name,
                        textInputAction: TextInputAction.next,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (String? value) {
                          bool isValidFormat = RegExp(r'^[A-Z][0-9]+$').hasMatch(value ?? '');
                          bool isNIMExists = membersData.any(
                            (user) => user.nim == value && user.id != member.id,
                          );

                          if (value.toString().isEmpty) {
                            return LocaleKeys.member_page_dialog_validation_nim_required_empty.tr(
                              context: context,
                            );
                          } else if (isNIMExists) {
                            return LocaleKeys.member_page_dialog_validation_nim_required_exists.tr(
                              context: context,
                            );
                          } else if (!isValidFormat) {
                            return LocaleKeys.member_page_dialog_validation_nim_required_invalid.tr(
                              context: context,
                            );
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 14.0),
                      Row(
                        children: <Widget>[
                          Icon(Icons.category, size: 24.0),
                          SizedBox(width: 16.0),
                          DropdownButton<String>(
                            value: selectedMode,
                            hint: Text(
                              LocaleKeys.member_page_dialog_field_division.tr(context: context),
                            ),
                            items: divisionList.map((item) {
                              return DropdownMenuItem<String>(value: item, child: Text(item));
                            }).toList(),
                            onChanged: (String? value) {
                              if (value == selectedMode) return;
                              dialogSetState(() => selectedMode = value);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    ElevatedButton(
                      onPressed: () => validateFormInput(member.id),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: Text(
                        LocaleKeys.member_page_dialog_button_update.tr(context: context),
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                    SizedBox(width: 24.0),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
                      child: Text(
                        LocaleKeys.member_page_dialog_button_cancel.tr(context: context),
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  void validateFormInput(String memberId) async {
    FormState? form = formKey.currentState;

    if (form != null) {
      if (form.validate()) {
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

        Map<String, dynamic> jsonData = {
          'nim': memberNIMController.text,
          'nama': memberNameController.text,
          'divisi': selectedMode,
        };

        if (!mounted) return;

        database
            .updateData(
              urlPath: 'api/mahasiswa',
              dataId: memberId,
              jsonData: jsonData,
              httpHeaders: {'Content-Type': 'application/json'},
            )
            .then((isSuccess) {
              if (!mounted) return;

              if (isSuccess) {
                fetchAllMembers(path: 'api/mahasiswa');

                Toastification().show(
                  context: context,
                  title: Text(LocaleKeys.alert_notify_member_title.tr(context: context)),
                  description: Text(
                    LocaleKeys.alert_notify_member_description_update_success.tr(context: context),
                  ),
                  type: ToastificationType.success,
                  style: ToastificationStyle.flat,
                  alignment: Alignment.bottomCenter,
                  autoCloseDuration: Duration(seconds: 2),
                  animationDuration: Duration(milliseconds: 500),
                );
              } else {
                Toastification().show(
                  context: context,
                  title: Text(LocaleKeys.alert_notify_member_title.tr(context: context)),
                  description: Text(
                    LocaleKeys.alert_notify_member_description_update_failed.tr(context: context),
                  ),
                  type: ToastificationType.error,
                  style: ToastificationStyle.flat,
                  alignment: Alignment.bottomCenter,
                  autoCloseDuration: Duration(seconds: 2),
                  animationDuration: Duration(milliseconds: 500),
                );
              }
            });
        Navigator.of(context).pop();
      }
    }
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
    fetchAllMembers(path: 'api/mahasiswa');
    startWiFiChecker();
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);

    scrollController.dispose();
    backgroundTaskSub?.cancel();
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
      appBar: AppBar(
        title: Center(child: Text(LocaleKeys.member_page_title.tr(context: context))),
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
      body: isLoadingDone
          ? isDataLoaded
                ? hasMembers()
                : noMembers()
          : Center(
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
                  Text(LocaleKeys.member_page_loading_data_process.tr(context: context)),
                ],
              ),
            ),
    );
  }

  Widget noMembers() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(Icons.person, size: 40.0),
                        SizedBox(width: 16.0),
                        Expanded(
                          child: Text(
                            LocaleKeys.member_page_loading_data_no_data_title.tr(context: context),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.0),
                    Divider(color: Colors.grey, thickness: 1.5),
                    SizedBox(height: 8.0),
                    Text(
                      LocaleKeys.member_page_loading_data_no_data_description.tr(context: context),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16.0),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget hasMembers() {
    return SingleChildScrollView(
      controller: scrollController,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              height: 50.0,
              margin: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
              child: SearchBar(
                leading: Icon(Icons.search),
                hintText: LocaleKeys.search_bar_member.tr(context: context),
                textInputAction: TextInputAction.search,
                onChanged: (String value) {
                  setState(() {
                    filteredMembersData = membersData
                        .where((event) => event.name.toLowerCase().contains(value.toLowerCase()))
                        .toList();

                    int calcLength = (filteredMembersData.length / maxPerPage).ceil();
                    if (!(calcLength > currentPage)) currentPage = calcLength;
                  });
                },
              ),
            ),
            ...AnimateList(
              interval: 300.ms,
              effects: [FadeEffect(duration: 300.ms)],
              children: <Widget>[...?getEventList(filteredMembersData)[currentPage]],
            ),
            SizedBox(height: 25.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                previousPageButton(),
                SizedBox(width: 20.0),
                Text(
                  LocaleKeys.paginating_page_info.tr(
                    context: context,
                    namedArgs: {
                      'current': '$currentPage',
                      'total':
                          '${getEventList(filteredMembersData).isEmpty ? 1 : getEventList(filteredMembersData).length}',
                    },
                  ),
                ),
                SizedBox(width: 20.0),
                nextPageButton(),
              ],
            ),
            SizedBox(height: 25.0),
          ],
        ),
      ),
    );
  }

  Widget previousPageButton() {
    final orientation = MediaQuery.of(context).orientation;

    if (orientation == Orientation.landscape) {
      return ElevatedButton(
        onPressed: currentPage > 1
            ? () {
                setState(() {
                  currentPage--;
                  scrollController.animateTo(
                    0.0,
                    duration: Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                });
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: currentPage > 1 ? Colors.blue.shade600 : Colors.grey,
        ),
        child: Text(
          LocaleKeys.paginating_page_previous.tr(context: context),
          style: TextStyle(color: currentPage > 1 ? Colors.black : Colors.grey),
        ),
      );
    } else {
      return ElevatedButton.icon(
        label: Icon(Icons.arrow_back_ios),
        style: ElevatedButton.styleFrom(
          backgroundColor: currentPage > 1 ? Colors.blue.shade600 : Colors.grey,
        ),
        onPressed: currentPage > 1
            ? () {
                setState(() {
                  currentPage--;
                  scrollController.animateTo(
                    0.0,
                    duration: Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                });
              }
            : null,
      );
    }
  }

  Widget nextPageButton() {
    final orientation = MediaQuery.of(context).orientation;

    if (orientation == Orientation.landscape) {
      return ElevatedButton(
        onPressed: getEventList(filteredMembersData).length > currentPage
            ? () {
                setState(() {
                  currentPage++;
                  scrollController.animateTo(
                    0.0,
                    duration: Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                });
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: getEventList(filteredMembersData).length > currentPage
              ? Colors.blue.shade600
              : Colors.grey,
        ),
        child: Text(
          LocaleKeys.paginating_page_next.tr(context: context),
          style: TextStyle(
            color: getEventList(filteredMembersData).length > currentPage
                ? Colors.black
                : Colors.grey,
          ),
        ),
      );
    } else {
      return ElevatedButton.icon(
        label: Icon(Icons.arrow_forward_ios),
        style: ElevatedButton.styleFrom(
          backgroundColor: getEventList(filteredMembersData).length > currentPage
              ? Colors.blue.shade600
              : Colors.grey,
        ),
        onPressed: getEventList(filteredMembersData).length > currentPage
            ? () {
                setState(() {
                  currentPage++;
                  scrollController.animateTo(
                    0.0,
                    duration: Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                });
              }
            : null,
      );
    }
  }
}
