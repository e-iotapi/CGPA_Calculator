import 'package:cgpa_calculator/app/theme/palette.dart';

export 'package:cgpa_calculator/app/theme/palette.dart';

/// The original name for a theme. The colours now live in
/// `app/theme/palette.dart`; this alias keeps old call sites compiling until
/// they move to [AppPalette] directly.
typedef Constants = AppPalette;

/// The user-selectable themes, in picker order.
final List<Constants> themes = AppPalette.named;
