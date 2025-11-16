import 'dart:convert';
import 'dart:core';

class Member {
  final String id;
  final String nim;
  final String name;
  final String division;
  final String cardUID;

  Member.defaultData() : id = '', nim = '', name = '', division = '', cardUID = '';

  Member({
    required this.id,
    required this.nim,
    required this.name,
    required this.division,
    required this.cardUID,
  });

  factory Member.fromJson(Map<String, dynamic> json) => Member(
    id: json['id'] as String,
    nim: json['nim'] as String? ?? '',
    name: json['nama'] as String? ?? '',
    division: json['divisi'] as String? ?? '',
    cardUID: json['uid'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nim': nim,
    'nama': name,
    'divisi': division,
    'uid': cardUID,
  };
}

List<Member> parseUser(String jsonString) {
  final Map<String, dynamic> root = jsonDecode(jsonString) as Map<String, dynamic>;
  final List<dynamic> data = (root['data'] ?? []) as List<dynamic>;
  return data.map((e) => Member.fromJson(e as Map<String, dynamic>)).toList();
}
