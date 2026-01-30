/// HTTP constants for Ably REST API.
library;

/// Ably protocol version.
const String ablyProtocolVersion = '2';

/// SDK version.
const String sdkVersion = '0.1.0';

/// Default Ably agent string.
const String ablyAgent = 'ably-dart/$sdkVersion';

/// Default REST host.
const String defaultRestHost = 'rest.ably.io';

/// Default fallback hosts.
const List<String> defaultFallbackHosts = [
  'a.ably-realtime.com',
  'b.ably-realtime.com',
  'c.ably-realtime.com',
  'd.ably-realtime.com',
  'e.ably-realtime.com',
];

/// HTTP header names.
class HttpHeaders {
  static const String contentType = 'Content-Type';
  static const String accept = 'Accept';
  static const String authorization = 'Authorization';
  static const String ablyVersion = 'X-Ably-Version';
  static const String ablyAgent = 'Ably-Agent';
  static const String ablyErrorCode = 'X-Ably-Errorcode';
  static const String ablyErrorMessage = 'X-Ably-Errormessage';
  static const String link = 'Link';
}

/// Content types.
class ContentTypes {
  static const String json = 'application/json';
  static const String msgpack = 'application/x-msgpack';
}
