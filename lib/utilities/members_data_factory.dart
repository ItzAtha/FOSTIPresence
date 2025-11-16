import 'dart:convert';
import 'dart:io';

import 'package:attendance_management/utilities/string_similar.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class MembersData {
  late Excel _workbook;
  final String _fileName;

  final List<String> divisionList = [
    "Keilmuan dan Riset Teknologi",
    "Hubungan Publik",
    "Keorganisasian",
    "RisTek",
    "HubPub",
    "Keor",
  ];

  MembersData({required String fileName}) : _fileName = fileName;

  Future<bool> loadData() async {
    Directory? appDocDir = await getExternalStorageDirectory();
    String filePath = path.join(appDocDir!.path, _fileName);

    File file = File(filePath);
    if (!await file.exists()) {
      print("File not found: $filePath");
      return false;
    }

    List<int> bytes = await file.readAsBytes();
    try {
      _workbook = Excel.decodeBytes(bytes);
    } catch (e) {
      print("Error decoding Excel file: $e");
      return false;
    }
    print("Data loaded from $_fileName");
    return true;
  }

  Map<String, List<List<String>>> _getStudentsList() {
    List<CellIndex> startIdColumns = [];
    Map<String, List<List<String>>> studentsDataMap = {};

    if (_workbook.sheets.isEmpty) {
      print("No sheets found in the workbook.");
      return studentsDataMap;
    }

    Sheet worksheet = _workbook.sheets.values.first;
    for (var rows in worksheet.rows) {
      for (var cell in rows) {
        if (cell == null) continue;

        bool hasMatch = divisionList.any(
          (division) => StringSimilar.jaccardSimilarity(cell.value.toString(), division) >= 0.8,
        );
        if (hasMatch) {
          print("Found Division on Index ${cell.cellIndex}!");
          startIdColumns.add(cell.cellIndex);
          break;
        }
      }
    }

    for (var startIdColumn in startIdColumns) {
      String divName = worksheet
          .cell(
            CellIndex.indexByColumnRow(
              columnIndex: startIdColumn.columnIndex,
              rowIndex: startIdColumn.rowIndex,
            ),
          )
          .value
          .toString();
      List<List<String>> studentsData = [];

      print("Start ID Column: ${startIdColumn.columnIndex}, Row: ${startIdColumn.rowIndex}");
      int columnIndex = startIdColumn.columnIndex;
      int rowIndex = startIdColumn.rowIndex;

      for (int row = rowIndex; row < worksheet.maxRows; row++) {
        List<String> tempStudentsData = [];

        for (int column = columnIndex + 1; column < worksheet.maxColumns - 2; column++) {
          var cell = worksheet.cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row));

          if (cell.value == null || row == rowIndex + 1) continue;
          print("Cell at Row: $row, Col: $column has value: ${cell.value}");
          tempStudentsData.add(cell.value.toString());
        }

        if (tempStudentsData.isNotEmpty) {
          studentsData.add(tempStudentsData);
        }
        print("==================================================================");

        var cell = worksheet.cell(
          CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: row),
        );
        if (cell.value == null) {
          studentsDataMap[divName] = studentsData;
          break;
        }
      }
    }

    print(
      "===================================================================================================",
    );
    studentsDataMap.forEach((key, value) {
      print("Division: $key");
      for (var student in value) {
        print("Student Data: ${student.toString()}");
      }
    });
    print(
      "===================================================================================================",
    );
    String encodedData = jsonEncode(studentsDataMap);
    print("Encoded Students Data: $encodedData");
    return studentsDataMap;
  }

  List<String> findStudentByNIM(String nim) {
    List<String> foundStudent = [];
    Map<String, List<List<String>>> studentsDataMap = _getStudentsList();

    studentsDataMap.forEach((division, studentsList) {
      for (var student in studentsList) {
        if (student.isNotEmpty && student[1] == nim) {
          if (StringSimilar.jaccardSimilarity(division, "Keilmuan dan Riset Teknologi") >= 0.8) {
            division = "RISTEK";
          } else if (StringSimilar.jaccardSimilarity(division, "Hubungan Publik") >= 0.8) {
            division = "HUBPUB";
          } else if (StringSimilar.jaccardSimilarity(division, "Keorganisasian") >= 0.8) {
            division = "KEOR";
          }

          foundStudent.add(division);
          foundStudent.addAll(student);
          print("Found Student in Division $division: ${student.toString()}");
          break;
        }
      }
    });

    if (foundStudent.isEmpty) {
      print("No Student found with NIM: $nim");
    }

    return foundStudent;
  }
}
