import 'dart:async';

import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/platform/online.dart';
import 'package:flutter/material.dart';

/// Shown only while offline: says plainly that work is saved locally and
/// whether anything is waiting to sync. Offline already works; this only
/// surfaces it.
class OfflineStrip extends StatefulWidget {
  const OfflineStrip({super.key, this.pending, this.forceOffline = false});

  /// Whether local changes wait to sync; null leaves it unsaid.
  final bool Function()? pending;

  /// For tests and previews.
  final bool forceOffline;

  @override
  State<OfflineStrip> createState() => _OfflineStripState();
}

class _OfflineStripState extends State<OfflineStrip> {
  late bool _online = isOnline;
  StreamSubscription<bool>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = onlineChanges.listen((v) => setState(() => _online = v));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_online && !widget.forceOffline) return const SizedBox.shrink();
    final p = AppPalette.of(context);
    final tone = p.gradeTone('C');
    final waiting = widget.pending?.call() ?? false;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: p.surface,
          border: Border.all(color: p.outline),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: tone.fill,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_off_rounded, size: 16, color: tone.text),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Working offline',
                    style: TypeScale.body.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: p.text,
                    ),
                  ),
                  Text(
                    'Everything is saved on this device'
                    '${waiting ? ' · changes will sync when you reconnect' : ''}',
                    style: TypeScale.caption.copyWith(
                      fontSize: 10,
                      color: p.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
