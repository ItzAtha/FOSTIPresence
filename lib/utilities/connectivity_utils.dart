import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityUtils {
  static Future<bool> checkConnection() async {
    List<ConnectivityResult> results = await (Connectivity().checkConnectivity());
    return !results.contains(ConnectivityResult.none);
  }
}
