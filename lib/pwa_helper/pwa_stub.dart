// lib/pwa_helper/pwa_stub.dart

import 'package:cgpa_calculator/pwa_helper/install_platform.dart';

class PwaHelper {
  static bool get isStandalone => false;
  static InstallPlatform get platform => InstallPlatform.desktop;
  static bool tryNativePrompt() => false;
}
