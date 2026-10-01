import 'package:cgpa_calculator/core/live/live_channel.dart';

Future<LiveChannel> connect(String url, List<String> protocols) =>
    Future.error(UnsupportedError('live socket needs the web'));
