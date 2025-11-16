import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:pulsator/pulsator.dart';
import 'package:toastification/toastification.dart';

import '../manager/events_manager.dart';
import '../translations/locale_keys.g.dart';
import '../utilities/events_recap_factory.dart';
import '../utilities/connectivity_utils.dart';
import '../manager/database_manager.dart';

class EventPage extends StatefulWidget {
  const EventPage({super.key});

  @override
  State<StatefulWidget> createState() => _EventPageState();
}

enum Answer { YES, NO }

class _EventPageState extends State<EventPage> with WidgetsBindingObserver {
  int currentPage = 1;
  final int maxPerPage = 12;

  late bool isLoadingDone;
  bool isDataLoaded = false;

  List<Event> eventsData = [];
  List<Event> filteredEventsData = [];

  Timer? wifiCheckerTask;
  bool isInternetConnected = false;

  DateTime? selectedDateTime;
  final ScrollController scrollController = ScrollController();

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController eventNameController = TextEditingController();
  final TextEditingController eventDescController = TextEditingController();
  final TextEditingController eventLocController = TextEditingController();
  final TextEditingController eventDateTimeController = TextEditingController();

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

    dynamic rawEventsData = await database.readData(urlPath: path);
    if (!mounted) return;

    if (rawEventsData != null) {
      eventsData = rawEventsData as List<Event>;
      if (eventsData.isNotEmpty) {
        setState(() {
          filteredEventsData = eventsData;
          isDataLoaded = true;
        });
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

  Map<int, List<Widget>> getEventList(List<Event> jsonData) {
    List<Widget> eventList = [];
    Map<int, List<Widget>> eventListPerPage = {};
    int indexPage = 1;

    for (final event in jsonData) {
      eventList.add(
        RepaintBoundary(
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Card(
                margin: const EdgeInsets.all(16.0),
                elevation: 5.0,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(Icons.event, size: 30.0),
                          SizedBox(width: 12.0),
                          Expanded(
                            child: Column(
                              children: <Widget>[
                                Text(
                                  event.name,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  DateFormat(
                                    'dd MMM yyyy, HH:mm',
                                  ).format(DateTime.parse(event.eventDate)),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  event.location,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 24.0),
                          Align(
                            widthFactor: 0.3,
                            child: SizedBox(
                              width: 40.0,
                              height: 40.0,
                              child: Pulsator(
                                style: PulseStyle(
                                  color: event.isActive ? Colors.green : Colors.red,
                                ),
                                count: 1,
                                duration: Duration(seconds: 1),
                                startFromScratch: false,
                                child: Container(
                                  width: 15.0,
                                  height: 15.0,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: event.isActive
                                        ? Colors.green.withValues(alpha: 0.7)
                                        : Colors.red.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.0),
                      Divider(color: Colors.grey, thickness: 1.5),
                      SizedBox(height: 6.0),
                      Text(
                        event.description,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14.0),
                      ),
                      SizedBox(height: 32.0),
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
                          heroTag: "editEventButton${event.id}",
                          tooltip: LocaleKeys.event_page_button_edit.tr(context: context),
                          onPressed: () => onAddEditButton(context, eventData: event),
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
                    SizedBox(width: 12.0),
                    SizedBox(
                      width: 45.0,
                      height: 45.0,
                      child: FittedBox(
                        child: FloatingActionButton(
                          heroTag: "downloadRecapButton${event.id}",
                          tooltip: LocaleKeys.event_page_button_download_recap.tr(context: context),
                          onPressed: () async {
                            if (!await ConnectivityUtils.checkConnection()) {
                              if (!mounted) return;

                              Toastification().show(
                                context: context,
                                title: Text(
                                  LocaleKeys.alert_notify_internet_title.tr(context: context),
                                ),
                                description: Text(
                                  LocaleKeys.alert_notify_internet_description.tr(context: context),
                                ),
                                type: ToastificationType.info,
                                style: ToastificationStyle.flat,
                                alignment: Alignment.bottomCenter,
                                autoCloseDuration: Duration(seconds: 2),
                                animationDuration: Duration(milliseconds: 500),
                              );
                              return;
                            }

                            if (!mounted) return;
                            Toastification().show(
                              context: context,
                              title: Text(LocaleKeys.alert_notify_event_title.tr(context: context)),
                              description: Text(
                                LocaleKeys.alert_notify_event_description_saving_recap_process.tr(
                                  context: context,
                                ),
                              ),
                              type: ToastificationType.info,
                              style: ToastificationStyle.flat,
                              alignment: Alignment.bottomCenter,
                              autoCloseDuration: Duration(seconds: 2),
                              animationDuration: Duration(milliseconds: 500),
                            );

                            RecapFactory recapFactory = RecapFactory(eventId: event.id);

                            await recapFactory.createExcel().then((factory) {
                              if (factory != null) {
                                factory.saveExcel().then((isSuccess) {
                                  if (!mounted || isSuccess == null) return;

                                  if (isSuccess) {
                                    Toastification().show(
                                      context: context,
                                      title: Text(
                                        LocaleKeys.alert_notify_event_title.tr(context: context),
                                      ),
                                      description: Text(
                                        LocaleKeys
                                            .alert_notify_event_description_saving_recap_success
                                            .tr(context: context),
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
                                      title: Text(
                                        LocaleKeys.alert_notify_event_title.tr(context: context),
                                      ),
                                      description: Text(
                                        LocaleKeys
                                            .alert_notify_event_description_saving_recap_failed
                                            .tr(context: context),
                                      ),
                                      type: ToastificationType.error,
                                      style: ToastificationStyle.flat,
                                      alignment: Alignment.bottomCenter,
                                      autoCloseDuration: Duration(seconds: 2),
                                      animationDuration: Duration(milliseconds: 500),
                                    );
                                  }
                                });
                              } else {
                                if (!mounted) return;

                                Toastification().show(
                                  context: context,
                                  title: Text(
                                    LocaleKeys.alert_notify_event_title.tr(context: context),
                                  ),
                                  description: Text(
                                    LocaleKeys
                                        .alert_notify_event_description_saving_recap_no_users_log
                                        .tr(context: context),
                                  ),
                                  type: ToastificationType.info,
                                  style: ToastificationStyle.flat,
                                  alignment: Alignment.bottomCenter,
                                  autoCloseDuration: Duration(seconds: 2),
                                  animationDuration: Duration(milliseconds: 500),
                                );
                              }
                            });
                          },
                          shape: CircleBorder(),
                          backgroundColor: Colors.lightGreen,
                          child: Icon(
                            Icons.download,
                            color: Theme.of(context).brightness == Brightness.light
                                ? Colors.black
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.0),
                    SizedBox(
                      width: 45.0,
                      height: 45.0,
                      child: FittedBox(
                        child: FloatingActionButton(
                          heroTag: "deleteEventButton${event.id}",
                          tooltip: LocaleKeys.event_page_button_delete.tr(context: context),
                          onPressed: () => onDeleteConfirm(context, eventId: event.id),
                          shape: CircleBorder(),
                          backgroundColor: Colors.red.shade600,
                          child: Icon(
                            Icons.delete,
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

      if (eventList.length == maxPerPage || event == jsonData.last) {
        eventListPerPage[indexPage++] = eventList;
        eventList = [];
      }
    }

    return eventListPerPage;
  }

  Future<void> onAddEditButton(BuildContext context, {Event? eventData}) async {
    bool hasEventData = eventData != null;
    Event event = eventData ?? Event.defaultData();
    String? formattedDate;

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

    if (hasEventData) {
      DateTime rawDateTime = DateTime.parse(event.eventDate);
      formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(rawDateTime);
    }

    eventNameController.text = hasEventData ? event.name : "";
    eventDescController.text = hasEventData ? event.description : "";
    eventLocController.text = hasEventData ? event.location : "";
    eventDateTimeController.text = (hasEventData ? formattedDate : "")!;

    if (!context.mounted) return;
    var eventAddEditForm = AlertDialog(
      title: Text(
        hasEventData
            ? LocaleKeys.event_page_dialog_edit_title.tr(context: context)
            : LocaleKeys.event_page_dialog_add_title.tr(context: context),
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
                controller: eventNameController,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: LocaleKeys.event_page_dialog_field_name.tr(context: context),
                  hintText: "Event FOSTI 202X",
                  icon: Icon(Icons.event_note, size: 24.0),
                  border: OutlineInputBorder(),
                  errorMaxLines: 2,
                ),
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.next,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (String? value) {
                  if (value.toString().isEmpty) {
                    return LocaleKeys.event_page_dialog_validation_name_required.tr(
                      context: context,
                    );
                  }
                  return null;
                },
              ),
              SizedBox(height: 14.0),
              TextFormField(
                controller: eventDescController,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: LocaleKeys.event_page_dialog_field_description.tr(context: context),
                  hintText: "FOSTI event held once a year",
                  icon: Icon(Icons.description, size: 24.0),
                  border: OutlineInputBorder(),
                  errorMaxLines: 2,
                ),
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.next,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (String? value) {
                  if (value.toString().isEmpty) {
                    return LocaleKeys.event_page_dialog_validation_description_required.tr(
                      context: context,
                    );
                  }
                  return null;
                },
              ),
              SizedBox(height: 14.0),
              TextFormField(
                controller: eventLocController,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: LocaleKeys.event_page_dialog_field_location.tr(context: context),
                  hintText: "Gedung J, Kampus 2, UMS",
                  icon: Icon(Icons.location_city, size: 24.0),
                  border: OutlineInputBorder(),
                  errorMaxLines: 2,
                ),
                maxLines: null,
                keyboardType: TextInputType.streetAddress,
                textInputAction: TextInputAction.next,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (String? value) {
                  if (value.toString().isEmpty) {
                    return LocaleKeys.event_page_dialog_validation_location_required.tr(
                      context: context,
                    );
                  }
                  return null;
                },
              ),
              SizedBox(height: 14.0),
              TextFormField(
                controller: eventDateTimeController,
                readOnly: true,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: LocaleKeys.event_page_dialog_field_date_label.tr(context: context),
                  hintText: LocaleKeys.event_page_dialog_field_date_hint.tr(context: context),
                  icon: Icon(Icons.date_range, size: 24.0),
                  border: OutlineInputBorder(),
                  errorMaxLines: 2,
                ),
                onTap: () async {
                  final DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: selectedDateTime ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2030),
                  );

                  if (pickedDate != null) {
                    final TimeOfDay? pickedTime = await showTimePicker(
                      context: !mounted ? this.context : context,
                      initialTime: TimeOfDay.fromDateTime(selectedDateTime ?? DateTime.now()),
                      builder: (BuildContext context, Widget? child) {
                        return MediaQuery(
                          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                          child: child!,
                        );
                      },
                    );

                    if (pickedTime != null) {
                      DateTime? rawDateTime;
                      int seconds = DateTime.now().second;
                      setState(() {
                        rawDateTime = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                          seconds,
                        );
                      });

                      String formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(rawDateTime!);
                      eventDateTimeController.text = formattedDate;
                    }
                  }
                },
                validator: (String? value) {
                  if (value.toString().isEmpty) {
                    return LocaleKeys.event_page_dialog_validation_date_required.tr(
                      context: context,
                    );
                  }
                  return null;
                },
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
              onPressed: () => validateFormInput(hasEventData, event.id),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: hasEventData
                  ? Text(
                      LocaleKeys.event_page_dialog_button_update.tr(context: context),
                      style: TextStyle(color: Colors.black),
                    )
                  : Text(
                      LocaleKeys.event_page_dialog_button_create.tr(context: context),
                      style: TextStyle(color: Colors.black),
                    ),
            ),
            SizedBox(width: 24.0),
            ElevatedButton(
              onPressed: () {
                if (eventDateTimeController.text.isEmpty) {
                  eventDateTimeController.text = "";
                }
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
              child: Text(
                LocaleKeys.event_page_dialog_button_cancel.tr(context: context),
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        ),
      ],
    );

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return eventAddEditForm;
      },
    );
  }

  void validateFormInput(bool isEditMode, String eventId) async {
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
          return;
        }

        DateTime rawDateTime = DateTime.parse(eventDateTimeController.text);
        DateTime dateTime = DateTime(
          rawDateTime.year,
          rawDateTime.month,
          rawDateTime.day,
          rawDateTime.hour + 7, // Adjusting for UTC+7 timezone
          rawDateTime.minute,
          rawDateTime.second,
        );
        DateTime rawUTCDateTime = dateTime.toUtc();
        String isoFormattedDate = rawUTCDateTime.toIso8601String();

        Map<String, dynamic> jsonData = {
          'judul': eventNameController.text,
          'deskripsi': eventDescController.text,
          'tanggal': isoFormattedDate,
          'lokasi': eventLocController.text,
        };

        if (!mounted) return;

        isEditMode
            ? database
                  .updateData(
                    urlPath: 'api/event',
                    dataId: eventId,
                    jsonData: jsonData,
                    httpHeaders: {'Content-Type': 'application/json'},
                  )
                  .then((isSuccess) {
                    if (!mounted) return;

                    if (isSuccess) {
                      fetchAllEvents(path: 'api/event');

                      Toastification().show(
                        context: context,
                        title: Text(LocaleKeys.alert_notify_event_title.tr(context: context)),
                        description: Text(
                          LocaleKeys.alert_notify_event_description_update_success.tr(
                            context: context,
                          ),
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
                        title: Text(LocaleKeys.alert_notify_event_title.tr(context: context)),
                        description: Text(
                          LocaleKeys.alert_notify_event_description_update_failed.tr(
                            context: context,
                          ),
                        ),
                        type: ToastificationType.error,
                        style: ToastificationStyle.flat,
                        alignment: Alignment.bottomCenter,
                        autoCloseDuration: Duration(seconds: 2),
                        animationDuration: Duration(milliseconds: 500),
                      );
                    }
                  })
            : database
                  .createData(
                    urlPath: 'api/event',
                    jsonData: jsonData,
                    httpHeaders: {'Content-Type': 'application/json'},
                  )
                  .then((isSuccess) {
                    if (!mounted) return;

                    if (isSuccess) {
                      fetchAllEvents(path: 'api/event');

                      Toastification().show(
                        context: context,
                        title: Text(LocaleKeys.alert_notify_event_title.tr(context: context)),
                        description: Text(
                          LocaleKeys.alert_notify_event_description_create_success.tr(
                            context: context,
                          ),
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
                        title: Text(LocaleKeys.alert_notify_event_title.tr(context: context)),
                        description: Text(
                          LocaleKeys.alert_notify_event_description_create_failed.tr(
                            context: context,
                          ),
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

  Future<Null> onDeleteConfirm(BuildContext context, {required String eventId}) async {
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

    if (!context.mounted) return;
    var eventDeleteConfirm = SimpleDialog(
      title: Center(
        child: Text(LocaleKeys.event_page_dialog_delete_confirm_title.tr(context: context)),
      ),
      children: <Widget>[
        Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                LocaleKeys.event_page_dialog_delete_confirm_description.tr(context: context),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 25.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, Answer.YES);
                  },
                  child: Text(LocaleKeys.event_page_dialog_button_yes.tr(context: context)),
                ),
                SizedBox(width: 10.0),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, Answer.NO);
                  },
                  child: Text(LocaleKeys.event_page_dialog_button_no.tr(context: context)),
                ),
                SizedBox(width: 20.0),
              ],
            ),
          ],
        ),
      ],
    );

    if (!context.mounted) return;

    if (await showDialog(
          context: context,
          builder: (BuildContext context) {
            return eventDeleteConfirm;
          },
        ) ==
        Answer.YES) {
      database.deleteData(urlPath: 'api/event', dataId: eventId).then((isSuccess) {
        if (!context.mounted) return;

        if (isSuccess) {
          fetchAllEvents(path: 'api/event');

          Toastification().show(
            context: context,
            title: Text(LocaleKeys.alert_notify_event_title.tr(context: context)),
            description: Text(
              LocaleKeys.alert_notify_event_description_delete_success.tr(context: context),
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
            title: Text(LocaleKeys.alert_notify_event_title.tr(context: context)),
            description: Text(
              LocaleKeys.alert_notify_event_description_delete_failed.tr(context: context),
            ),
            type: ToastificationType.error,
            style: ToastificationStyle.flat,
            alignment: Alignment.bottomCenter,
            autoCloseDuration: Duration(seconds: 2),
            animationDuration: Duration(milliseconds: 500),
          );
        }
      });
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
    fetchAllEvents(path: 'api/event');
    startWiFiChecker();
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);

    scrollController.dispose();
    wifiCheckerTask?.cancel();
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => onAddEditButton(context),
        tooltip: LocaleKeys.event_page_button_add.tr(context: context),
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? Colors.green.shade400
            : Colors.green.shade600,
        child: Icon(
          Icons.add,
          color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white,
        ),
      ),
      body: isLoadingDone
          ? isDataLoaded
                ? hasEvents()
                : noEvents()
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
                  Text(LocaleKeys.event_page_loading_data_process.tr(context: context)),
                ],
              ),
            ),
    );
  }

  Widget noEvents() {
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
                        Icon(Icons.event, size: 40.0),
                        SizedBox(width: 16.0),
                        Text(
                          LocaleKeys.event_page_loading_data_no_data_title.tr(context: context),
                          style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.0),
                    Divider(color: Colors.grey, thickness: 1.5),
                    SizedBox(height: 8.0),
                    Text(
                      LocaleKeys.event_page_loading_data_no_data_description.tr(context: context),
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

  Widget hasEvents() {
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
                hintText: LocaleKeys.search_bar_event.tr(context: context),
                textInputAction: TextInputAction.search,
                onChanged: (String value) {
                  setState(() {
                    filteredEventsData = eventsData
                        .where((event) => event.name.toLowerCase().contains(value.toLowerCase()))
                        .toList();

                    int calcLength = (filteredEventsData.length / maxPerPage).ceil();
                    if (!(calcLength > currentPage)) currentPage = calcLength;
                  });
                },
              ),
            ),
            ...AnimateList(
              interval: 300.ms,
              effects: [FadeEffect(duration: 300.ms)],
              children: <Widget>[...?getEventList(filteredEventsData)[currentPage]],
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
                          '${getEventList(filteredEventsData).isEmpty ? 1 : getEventList(filteredEventsData).length}',
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
        onPressed: getEventList(filteredEventsData).length > currentPage
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
          backgroundColor: getEventList(filteredEventsData).length > currentPage
              ? Colors.blue.shade600
              : Colors.grey,
        ),
        child: Text(
          LocaleKeys.paginating_page_next.tr(context: context),
          style: TextStyle(
            color: getEventList(filteredEventsData).length > currentPage
                ? Colors.black
                : Colors.grey,
          ),
        ),
      );
    } else {
      return ElevatedButton.icon(
        label: Icon(Icons.arrow_forward_ios),
        style: ElevatedButton.styleFrom(
          backgroundColor: getEventList(filteredEventsData).length > currentPage
              ? Colors.blue.shade600
              : Colors.grey,
        ),
        onPressed: getEventList(filteredEventsData).length > currentPage
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
