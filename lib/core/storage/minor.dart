import 'package:cgpa_calculator/core/models/minors.dart';
import 'package:hive/hive.dart';

Box get _settings => Hive.box('settingsBox');

/// The minor the student is pursuing, or null.
Minor? get chosenMinor => minorNamed(_settings.get('minor') as String?);

/// Null stops pursuing one.
Future<void> setChosenMinor(Minor? m) =>
    m == null ? _settings.delete('minor') : _settings.put('minor', m.name);

/// The offshoot tab's last view: the offshoot score, or the minor.
bool get offshootShowsMinor => _settings.get('offshoot_view') == 'minor';

Future<void> setOffshootShowsMinor(bool minor) =>
    _settings.put('offshoot_view', minor ? 'minor' : 'offshoot');
