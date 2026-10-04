/// Non-web builds have no Worker to ask.
Future<({int status, String body})> httpGet(String url) =>
    throw UnsupportedError('httpGet needs the web build');
