// lib/pwa_helper/pwa_web.dart

import 'dart:html' as html;
import 'dart:js' as js;

import 'package:cgpa_calculator/pwa_helper/install_platform.dart';

class PwaHelper {
  /// Running as the installed app rather than in a browser tab.
  static bool get isStandalone =>
      html.window.matchMedia('(display-mode: standalone)').matches ||
      (js.context['navigator']['standalone'] == true);

  static InstallPlatform get platform {
    final ua = html.window.navigator.userAgent.toLowerCase();
    // iPads report themselves as a Mac with a touch screen.
    final touchMac =
        ua.contains('macintosh') &&
        (html.window.navigator.maxTouchPoints ?? 0) > 0;
    if (ua.contains('iphone') ||
        ua.contains('ipad') ||
        ua.contains('ipod') ||
        touchMac) {
      return InstallPlatform.ios;
    }
    if (ua.contains('android')) return InstallPlatform.android;
    return InstallPlatform.desktop;
  }

  /// Opens the browser's own install prompt. False when it has none to offer
  /// (Safari, Firefox, or a prompt already used or dismissed).
  static bool tryNativePrompt() {
    try {
      return js.context.callMethod('promptInstall') == true;
    } catch (_) {
      return false;
    }
  }
}
