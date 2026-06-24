import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class NetworkController extends GetxController {
  final Connectivity _connectivity = Connectivity();

  @override
  void onInit() {
    super.onInit();
    // Check initial connectivity status
    _connectivity.checkConnectivity().then(_updateConnectionStatus);
    // Listen for changes
    _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  void _updateConnectionStatus(List<ConnectivityResult> connectivityResults) {
    // If the list is empty or the ONLY result is 'none', there is no internet
    bool isOffline = connectivityResults.isEmpty || 
                    (connectivityResults.length == 1 && connectivityResults.contains(ConnectivityResult.none));
    
    if (isOffline) {
      if (!Get.isSnackbarOpen) {
        Get.rawSnackbar(
          messageText: const Text(
            'PLEASE CONNECT TO THE INTERNET',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold
            )
          ),
          isDismissible: false,
          duration: const Duration(days: 1),
          backgroundColor: Colors.red[400]!,
          icon: const Icon(Icons.wifi_off, color: Colors.white, size: 35),
          margin: EdgeInsets.zero,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } else {
      if (Get.isSnackbarOpen) {
        Get.closeCurrentSnackbar();
      }
    }
  }
}

class DependencyInjection {
  static void init() {
    Get.put<NetworkController>(NetworkController(), permanent: true);
  }
}
