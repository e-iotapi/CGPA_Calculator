// lib/pwa_helper/pwa_web.dart

import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/material.dart';
import 'package:cgpa_calculator/constants.dart';

class PwaHelper {
  static bool get isWebPlatform => true;

  static bool get isIOSWeb {
    final ua = html.window.navigator.userAgent.toLowerCase();
    final isIos = ua.contains('iphone') || 
                  ua.contains('ipad') || 
                  ua.contains('ipod');
    // Also detect modern iPads which masquerade as Mac but have touch support
    final isMacTouch = ua.contains('macintosh') && 
                       html.window.navigator.maxTouchPoints != null && 
                       html.window.navigator.maxTouchPoints! > 0;
    return isIos || isMacTouch;
  }

  static bool get isAndroidWeb {
    final ua = html.window.navigator.userAgent.toLowerCase();
    return ua.contains('android');
  }

  static void promptInstall(BuildContext context, Constants theme) {
    if (isIOSWeb) {
      showIOSInstallOverlay(context, theme);
    } else {
      try {
        js.context.callMethod('promptInstall');
        print('Web promptInstall executed.');
      } catch (e) {
        // Fallback info Snackbars for other web platforms if promptInstall isn't defined or fails
        final ua = html.window.navigator.userAgent.toLowerCase();
        String message = "Click on Share => Add to Home Screen => Add";
        if (ua.contains('win') || ua.contains('mac') || ua.contains('linux')) {
          message = "Click on Settings => Cast, Save and Share => Install Page as app";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: theme.cardcolor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: theme.bordcolor, width: 1),
            ),
            content: Text(
              message,
              style: TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: theme.textcolor,
              ),
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  static void showIOSInstallOverlay(BuildContext context, Constants theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.backcolor,
      isScrollControlled: true,
      elevation: 30,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: theme.bordcolor.withValues(alpha: 0.3), width: 1),
      ),
      builder: (BuildContext context) {
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 28,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top drag/grab handle
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: theme.sepcolor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                SizedBox(height: 24),
                
                // Header: Logo, Title, Subtitle
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: theme.highcolor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: theme.bordcolor.withValues(alpha: 0.5), width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Image.asset(
                          'icons/Icon-192.png',
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.calculate_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Install CGPA Calculator",
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Montserrat',
                              color: theme.textcolor,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Add to Home Screen for quick access and full offline utility.",
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'Montserrat',
                              color: theme.textcolor.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Divider(
                    color: theme.sepcolor.withValues(alpha: 0.2),
                    thickness: 1,
                  ),
                ),
                
                // Step 1
                _buildStepItem(
                  number: "1",
                  text: "Tap the browser Share button in the Safari toolbar.",
                  icon: Icon(
                    Icons.ios_share,
                    color: theme.highcolor,
                    size: 24,
                  ),
                  theme: theme,
                ),
                SizedBox(height: 16),
                
                // Step 2
                _buildStepItem(
                  number: "2",
                  text: "Scroll down the sharing menu and select 'Add to Home Screen'.",
                  icon: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.textcolor.withValues(alpha: 0.8), width: 1.8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.add,
                        color: theme.textcolor,
                        size: 16,
                      ),
                    ),
                  ),
                  theme: theme,
                ),
                SizedBox(height: 16),
                
                // Step 3
                _buildStepItem(
                  number: "3",
                  text: "Tap 'Add' in the top-right corner of the popup to finish.",
                  icon: Text(
                    "Add",
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                    ),
                  ),
                  theme: theme,
                ),
                
                SizedBox(height: 28),
                
                // Confirm action button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.highcolor,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Got it, thanks!",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildStepItem({
    required String number,
    required String text,
    required Widget icon,
    required Constants theme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: theme.textcolor.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Montserrat',
                fontSize: 15,
                color: theme.textcolor,
              ),
            ),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Montserrat',
              color: theme.textcolor.withValues(alpha: 0.9),
              height: 1.3,
            ),
          ),
        ),
        SizedBox(width: 12),
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.textcolor.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
          ),
          child: icon,
        ),
      ],
    );
  }
}
