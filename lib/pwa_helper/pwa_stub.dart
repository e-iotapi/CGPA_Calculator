// lib/pwa_helper/pwa_stub.dart

import 'package:flutter/material.dart';

class PwaHelper {
  static bool get isWebPlatform => false;
  static bool get isIOSWeb => false;
  static bool get isAndroidWeb => false;

  static void promptInstall(BuildContext context, dynamic theme) {
    // No-op fallback on native mobile platforms
  }
}
