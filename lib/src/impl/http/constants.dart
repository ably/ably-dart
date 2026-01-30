/// HTTP constants for Ably REST API.
library;

/// Ably protocol version.
const String ablyProtocolVersion = '2';

/// SDK version.
const String sdkVersion = '0.1.0';

/// Default Ably agent string.
const String ablyAgent = 'ably-dart/$sdkVersion';

/// Default REST host (REC1a - primary domain for production).
const String defaultRestHost = 'rest.ably.io';

/// Default primary domain per REC1a specification.
const String defaultPrimaryDomain = 'main.realtime.ably.net';

/// Default fallback hosts (REC2c1).
const List<String> defaultFallbackHosts = [
  'a.ably-realtime.com',
  'b.ably-realtime.com',
  'c.ably-realtime.com',
  'd.ably-realtime.com',
  'e.ably-realtime.com',
];

/// Fallback domain suffixes for nonprod routing policy (REC2c3).
const List<String> nonprodFallbackSuffixes = [
  'a-fallback.nonprod-realtime.ably.net',
  'b-fallback.nonprod-realtime.ably.net',
  'c-fallback.nonprod-realtime.ably.net',
  'd-fallback.nonprod-realtime.ably.net',
  'e-fallback.nonprod-realtime.ably.net',
];

/// Fallback domain suffixes for production routing policy (REC2c4/REC2c5).
const List<String> productionFallbackSuffixes = [
  'a-fallback.realtime.ably.net',
  'b-fallback.realtime.ably.net',
  'c-fallback.realtime.ably.net',
  'd-fallback.realtime.ably.net',
  'e-fallback.realtime.ably.net',
];

/// Default connectivity check URL (REC3a).
const String defaultConnectivityCheckUrl = 'https://internet-up.ably-realtime.com/is-the-internet-up.txt';

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
