import 'dart:convert';
import 'dart:core';

class Event {
  final String id;
  final String name;
  final String description;
  final String eventDate;
  final String location;
  final bool isActive;

  Event.defaultData()
    : id = '',
      name = '',
      description = '',
      eventDate = '',
      location = '',
      isActive = true;

  Event({
    required this.id,
    required this.name,
    required this.description,
    required this.eventDate,
    required this.location,
    required this.isActive,
  });

  factory Event.fromJson(Map<String, dynamic> json) => Event(
    id: json['id'] as String,
    name: json['judul'] as String? ?? '',
    description: json['deskripsi'] as String? ?? '',
    eventDate: json['tanggal'] as String? ?? '',
    location: json['lokasi'] as String? ?? '',
    isActive: json['isActive'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'judul': name,
    'deskripsi': description,
    'tanggal': eventDate,
    'lokasi': location,
    'isActive': isActive,
  };
}

Event getActiveEvent(List<Event> events) {
  try {
    return events.firstWhere((event) => event.isActive);
  } catch (e) {
    return Event.defaultData();
  }
}

List<Event> parseEvent(String jsonString) {
  final Map<String, dynamic> root = jsonDecode(jsonString) as Map<String, dynamic>;
  final List<dynamic> data = (root['data'] ?? []) as List<dynamic>;
  return data.map((e) => Event.fromJson(e as Map<String, dynamic>)).toList();
}
