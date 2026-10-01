/// One open WebSocket, as the live client needs it: text frames in and out.
/// The web build wraps `package:web`'s socket; tests inject a fake.
abstract class LiveChannel {
  /// Text frames from the server; done when the socket drops.
  Stream<String> get messages;

  void send(String frame);

  void close();
}
