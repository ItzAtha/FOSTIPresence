import 'dart:convert';
import 'dart:core';

class Logs {
  final String nim;
  final String name;
  final String division;
  final String dateLogin;
  final String dateLogout;
  final String role;
  final String information;

  Logs.defaultData()
    : this(
        nim: '',
        name: '',
        division: '',
        dateLogin: '',
        dateLogout: '',
        role: '',
        information: '',
      );

  Logs({
    required this.nim,
    required this.name,
    required this.division,
    required this.dateLogin,
    required this.dateLogout,
    required this.role,
    required this.information,
  });

  factory Logs.fromJson(Map<String, dynamic> json) => Logs(
    nim: json['log']['kartu']['mahasiswa']['nim'] as String? ?? '',
    name: json['log']['kartu']['mahasiswa']['nama'] as String? ?? '',
    division: json['log']['kartu']['mahasiswa']['divisi'] as String? ?? '',
    dateLogin: json['log']['tanggal_masuk'] as String? ?? '',
    dateLogout: json['log']['tanggal_keluar'] as String? ?? '',
    role: json['log']['role'] as String? ?? '',
    information: json['log']['keterangan'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'nim': nim,
    'nama': name,
    'divisi': division,
    'tanggal_masuk': dateLogin,
    'tanggal_keluar': dateLogout,
    'role': role,
    'keterangan': information,
  };

  List<dynamic> toList() => [nim, name, division, dateLogin, dateLogout, role, information];
}

List<Logs> parseLogs(String jsonString) {
  final Map<String, dynamic> root = jsonDecode(jsonString) as Map<String, dynamic>;

  final List<dynamic> data = (root['data']?['logs'] ?? []) as List<dynamic>;
  return data.map((e) => Logs.fromJson(e as Map<String, dynamic>)).toList();
}
