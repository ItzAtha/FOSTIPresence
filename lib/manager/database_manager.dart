import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'events_manager.dart';
import 'logs_manager.dart';
import 'members_manager.dart';

class DatabaseManager {
  final String _baseURL = "https://fostipresensiapi.vercel.app";
  String _databaseStatus = 'Idle';

  Future<bool> createData({
    required String urlPath,
    required Map<String, dynamic> jsonData,
    Map<String, String>? httpHeaders,
    bool showLogs = false,
  }) async {
    Uri url = Uri.parse("$_baseURL/$urlPath");
    bool isSuccess = false;

    try {
      String httpBody = jsonEncode(jsonData);
      final response = await http
          .post(url, headers: httpHeaders, body: httpBody)
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        _databaseStatus = 'POST ${url.toString()} -> OK (${response.statusCode})';
        isSuccess = true;
      } else {
        _databaseStatus = 'POST ${url.toString()} -> FAILURE (${response.statusCode})';
      }
    } on FormatException catch (fe) {
      _databaseStatus = 'JSON Format Error: $fe';
    } catch (e) {
      _databaseStatus = 'HTTP Error: $e';
    }

    if (kDebugMode && showLogs) {
      print(_databaseStatus);
    }

    return isSuccess;
  }

  Future<bool> updateData({
    required String urlPath,
    required String dataId,
    required Map<String, dynamic> jsonData,
    Map<String, String>? httpHeaders,
    bool showLogs = false,
  }) async {
    Uri url = Uri.parse("$_baseURL/$urlPath/$dataId");
    bool isSuccess = false;

    try {
      String httpBody = jsonEncode(jsonData);
      final response = await http
          .put(url, headers: httpHeaders, body: httpBody)
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        _databaseStatus = 'UPDATE ${url.toString()} -> OK (200)';
        isSuccess = true;
      } else {
        _databaseStatus = 'UPDATE ${url.toString()} -> FAILURE (${response.statusCode})';
      }
    } on FormatException catch (fe) {
      _databaseStatus = 'JSON Format Error: $fe';
    } catch (e) {
      _databaseStatus = 'HTTP Error: $e';
    }

    if (kDebugMode && showLogs) {
      print(_databaseStatus);
    }

    return isSuccess;
  }

  Future<bool> deleteData({
    required String urlPath,
    required String dataId,
    bool showLogs = false,
  }) async {
    Uri url = Uri.parse("$_baseURL/$urlPath/$dataId");
    bool isSuccess = false;

    try {
      final response = await http.delete(url).timeout(Duration(seconds: 10));
      if (response.statusCode == 200) {
        _databaseStatus = 'DELETE ${url.toString()} -> OK (200)';
        isSuccess = true;
      } else {
        _databaseStatus = 'DELETE ${url.toString()} -> FAILURE (${response.statusCode})';
      }
    } on FormatException catch (fe) {
      _databaseStatus = 'JSON Format Error: $fe';
    } catch (e) {
      _databaseStatus = 'HTTP Error: $e';
    }

    if (kDebugMode && showLogs) {
      print(_databaseStatus);
    }

    return isSuccess;
  }

  Future<dynamic> readData({
    required String urlPath,
    String dataId = "",
    bool onlyReadLogs = false,
    bool showLogs = false,
  }) async {
    Uri url = Uri.parse("$_baseURL/$urlPath/$dataId");
    dynamic dataList;

    try {
      final response = await http.get(url).timeout(Duration(seconds: 10));
      final responseBody = response.body;

      if (response.statusCode == 200) {
        if (urlPath.endsWith('mahasiswa')) {
          dataList = parseUser(responseBody);
        } else if (urlPath.endsWith('event')) {
          if (onlyReadLogs && dataId != "") {
            dataList = parseLogs(responseBody);
          } else {
            dataList = parseEvent(responseBody);
          }
        }

        _databaseStatus = 'GET ${url.toString()} -> OK (200)';
      } else if (response.statusCode == 404 ||
          (response.statusCode == 200 && responseBody.isEmpty)) {
        _databaseStatus = 'GET ${url.toString()} -> NOT FOUND (404)';
      } else {
        _databaseStatus = 'GET ${url.toString()} -> FAILURE (${response.statusCode})';
      }
    } on FormatException catch (fe) {
      _databaseStatus = 'JSON Format Error: $fe';
    } catch (e) {
      _databaseStatus = 'HTTP Error: $e';
    }

    if (kDebugMode && showLogs) {
      print(_databaseStatus);
    }

    return dataList;
  }
}
