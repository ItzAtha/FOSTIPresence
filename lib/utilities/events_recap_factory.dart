import 'dart:io';
import 'package:attendance_management/manager/events_manager.dart';
import 'package:attendance_management/manager/logs_manager.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../manager/database_manager.dart';

class RecapFactory {
  List<Logs>? _logsList;
  final String _eventId;
  final Excel _workbook;

  int _startBaseIdColumn = -1;
  int _lastBaseIdColumn = -1;
  int _startBaseIdRow = -1;
  int _lastBaseIdRow = -1;

  int _startInfoIdColumn = -1;
  int _lastInfoIdColumn = -1;
  int _startInfoIdRow = -1;
  int _lastInfoIdRow = -1;

  Event? _event;
  List<int> _excelBytes = [];
  final List<String> _colName = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];

  final DatabaseManager _database;

  RecapFactory({required String eventId})
    : _eventId = eventId,
      _database = DatabaseManager(),
      _workbook = Excel.createExcel();

  Future<bool> _loadEventData() async {
    List<Event>? eventsList;
    dynamic rawEventData = await _database.readData(urlPath: 'api/event');
    dynamic rawLogData = await _database.readData(
      urlPath: 'api/event',
      dataId: _eventId,
      onlyReadLogs: true,
    );

    if (rawEventData != null && rawLogData != null) {
      eventsList = rawEventData as List<Event>;
      _logsList = rawLogData as List<Logs>;

      _event = eventsList.where((event) => event.id == _eventId).first;
      if (_event != null && _logsList!.isNotEmpty) {
        _logsList?.sort((a, b) => a.name.compareTo(b.name));
        return true;
      }
    }
    return false;
  }

  Future<RecapFactory?> createExcel() async {
    bool isDataLoad = await _loadEventData();

    if (!isDataLoad) {
      print("There are no users log in event $_eventId");
      return null;
    }

    Sheet worksheet = _workbook['PresenceRecap'];
    _workbook.delete('Sheet1');

    worksheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('G1'));
    CellStyle headerStyle = CellStyle(
      fontSize: 16,
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      backgroundColorHex: ExcelColor.fromHexString("#90EE90"),
    );

    _startBaseIdColumn = _startBaseIdRow = 0;
    Data headerCell = worksheet.cell(CellIndex.indexByString('A1'));
    headerCell.value = TextCellValue(_event!.name);
    headerCell.cellStyle = headerStyle;

    CellStyle subHeaderStyle = CellStyle(
      fontSize: 12,
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      backgroundColorHex: ExcelColor.fromHexString("#E0E0E0"),
    );

    Data colNIMCell = worksheet.cell(CellIndex.indexByString('A2'));
    colNIMCell.value = TextCellValue("NIM");
    colNIMCell.cellStyle = subHeaderStyle;

    Data colNameCell = worksheet.cell(CellIndex.indexByString('B2'));
    colNameCell.value = TextCellValue("Nama");
    colNameCell.cellStyle = subHeaderStyle;

    Data colDivisionCell = worksheet.cell(CellIndex.indexByString('C2'));
    colDivisionCell.value = TextCellValue("Divisi");
    colDivisionCell.cellStyle = subHeaderStyle;

    Data colLoginDateCell = worksheet.cell(CellIndex.indexByString('D2'));
    colLoginDateCell.value = TextCellValue("Tanggal Masuk");
    colLoginDateCell.cellStyle = subHeaderStyle;

    Data colLogoutDateCell = worksheet.cell(CellIndex.indexByString('E2'));
    colLogoutDateCell.value = TextCellValue("Tanggal Keluar");
    colLogoutDateCell.cellStyle = subHeaderStyle;

    Data colRoleCell = worksheet.cell(CellIndex.indexByString('F2'));
    colRoleCell.value = TextCellValue("Role");
    colRoleCell.cellStyle = subHeaderStyle;

    Data colInfoCell = worksheet.cell(CellIndex.indexByString('G2'));
    colInfoCell.value = TextCellValue("Keterangan");
    colInfoCell.cellStyle = subHeaderStyle;
    _lastBaseIdColumn = 6;

    for (int row = 0; row < _logsList!.length; row++) {
      List<dynamic> log = _logsList![row].toList();

      for (int column = 0; column < _colName.length; column++) {
        String columnKey = _colName[column];
        String columnValue = log[column];

        try {
          String formattedDate = DateFormat(
            "dd MMMM yyyy, HH:mm:ss",
          ).format(DateTime.parse(columnValue).toLocal());
          columnValue = formattedDate;
        } on FormatException {
          // IGNORED
        }

        Data colData = worksheet.cell(CellIndex.indexByString("$columnKey${row + 3}"));
        if (columnKey == 'B') {
          CellStyle nameCellStyle = CellStyle(textWrapping: TextWrapping.WrapText);
          colData.cellStyle = nameCellStyle;
        }
        colData.value = TextCellValue(columnValue);
      }

      _lastBaseIdRow = row + 3;
    }

    _startInfoIdColumn = _lastBaseIdColumn - 1;
    _startInfoIdRow = (_lastBaseIdRow + 3) - 1;
    worksheet.merge(
      CellIndex.indexByString('F${_lastBaseIdRow + 3}'),
      CellIndex.indexByString('G${_lastBaseIdRow + 3}'),
    );
    CellStyle colInfoHeaderStyle = CellStyle(
      fontSize: 12,
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      backgroundColorHex: ExcelColor.fromHexString("#90EE90"),
    );

    Data colInfoHeaderCell = worksheet.cell(CellIndex.indexByString('F${_lastBaseIdRow + 3}'));
    colInfoHeaderCell.value = TextCellValue("Keterangan");
    colInfoHeaderCell.cellStyle = colInfoHeaderStyle;

    CellStyle colInfoDataStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    worksheet.cell(CellIndex.indexByString('F${_lastBaseIdRow + 4}')).value = TextCellValue(
      "Hadir",
    );
    Data colInfoPresenceCell = worksheet.cell(CellIndex.indexByString('G${_lastBaseIdRow + 4}'));
    colInfoPresenceCell.value = IntCellValue(
      _logsList!.where((log) => log.information == 'HADIR').length,
    );
    colInfoPresenceCell.cellStyle = colInfoDataStyle;

    worksheet.cell(CellIndex.indexByString('F${_lastBaseIdRow + 5}')).value = TextCellValue("Izin");
    Data colInfoPermsCell = worksheet.cell(CellIndex.indexByString('G${_lastBaseIdRow + 5}'));
    colInfoPermsCell.value = IntCellValue(
      _logsList!.where((log) => log.information == 'IZIN').length,
    );
    colInfoPermsCell.cellStyle = colInfoDataStyle;

    worksheet.cell(CellIndex.indexByString('F${_lastBaseIdRow + 6}')).value = TextCellValue(
      "Total",
    );
    Data colInfoTotalCell = worksheet.cell(CellIndex.indexByString('G${_lastBaseIdRow + 6}'));
    colInfoTotalCell.value = FormulaCellValue('SUM(G${_lastBaseIdRow + 4}:G${_lastBaseIdRow + 5})');
    colInfoTotalCell.cellStyle = colInfoDataStyle;
    _lastInfoIdColumn = _lastBaseIdColumn;
    _lastInfoIdRow = _lastBaseIdRow + 6;

    worksheet.setColumnWidth(0, 15);
    worksheet.setColumnWidth(1, 50);
    worksheet.setColumnWidth(2, 10);
    worksheet.setColumnWidth(3, 30);
    worksheet.setColumnWidth(4, 30);
    worksheet.setColumnWidth(5, 10);
    worksheet.setColumnWidth(6, 15);

    Border cellBorder = Border(
      borderStyle: BorderStyle.Thin,
      borderColorHex: ExcelColor.fromHexString("#000000"),
    );

    for (int row = _startBaseIdRow; row < _lastBaseIdRow; row++) {
      for (int column = _startBaseIdColumn; column <= _lastBaseIdColumn; column++) {
        Data baseCell = worksheet.cell(
          CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
        );
        baseCell.cellStyle = (baseCell.cellStyle ?? CellStyle()).copyWith(
          fontFamilyVal: getFontFamily(FontFamily.Abadi_MT_Condensed_Extra_Bold),
          leftBorderVal: cellBorder,
          rightBorderVal: cellBorder,
          topBorderVal: cellBorder,
          bottomBorderVal: cellBorder,
        );
      }
    }

    for (int row = _startInfoIdRow; row < _lastInfoIdRow; row++) {
      for (int column = _startInfoIdColumn; column <= _lastInfoIdColumn; column++) {
        Data infoCell = worksheet.cell(
          CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
        );
        infoCell.cellStyle = (infoCell.cellStyle ?? CellStyle()).copyWith(
          fontFamilyVal: getFontFamily(FontFamily.Abadi_MT_Condensed_Extra_Bold),
          leftBorderVal: cellBorder,
          rightBorderVal: cellBorder,
          topBorderVal: cellBorder,
          bottomBorderVal: cellBorder,
        );
      }
    }

    _excelBytes = _workbook.save()!;
    return this;
  }

  Future<bool?> saveExcel() async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String fileName = '${_event!.name}.xlsx';
    String filePath = path.join(appDocDir.path, fileName);
    File file = File(filePath);
    await file.writeAsBytes(_excelBytes, flush: true);

    Uint8List savedExcelBytes;
    try {
      savedExcelBytes = Uint8List.fromList(_excelBytes);
    } catch (e) {
      print("Failed to save recap excel file as $fileName, exception: $e");
      return false;
    }

    String? savedResult = await FilePicker.platform.saveFile(
      bytes: savedExcelBytes,
      fileName: fileName,
    );
    if (savedResult == null) return null;

    print("Successfully save recap excel file as $fileName");
    return true;
  }
}
