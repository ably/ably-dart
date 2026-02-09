import 'package:ably_dart/ably_dart.dart';
import 'package:test/test.dart';

/// Token Types Tests
///
/// Spec points: TD1, TD2, TD3, TD4, TD5, TK1, TK2, TK3, TK4, TK5, TK6,
///              TE1, TE2, TE3, TE4, TE5, TE6
void main() {
  group('TokenDetails', () {
    group('TD1-TD5 - TokenDetails structure', () {
      test('TD1 - token attribute', () {
        final tokenDetails = TokenDetails(
          token: 'test-token',
          expires: 1234567890000,
        );
        expect(tokenDetails.token, equals('test-token'));
      });

      test('TD2 - expires attribute (milliseconds since epoch)', () {
        final tokenDetails = TokenDetails(
          token: 'test-token',
          expires: 1234567890000,
        );
        expect(tokenDetails.expires, equals(1234567890000));
      });

      test('TD3 - issued attribute', () {
        final tokenWithIssued = TokenDetails(
          token: 'test-token',
          expires: 1234567890000,
          issued: 1234567800000,
        );
        expect(tokenWithIssued.issued, equals(1234567800000));
      });

      test('TD4 - capability attribute (JSON string)', () {
        final tokenWithCapability = TokenDetails(
          token: 'test-token',
          expires: 1234567890000,
          capability: '{"*":["*"]}',
        );
        expect(tokenWithCapability.capability, equals('{"*":["*"]}'));
      });

      test('TD5 - clientId attribute', () {
        final tokenWithClient = TokenDetails(
          token: 'test-token',
          expires: 1234567890000,
          clientId: 'my-client',
        );
        expect(tokenWithClient.clientId, equals('my-client'));
      });
    });

    group('TD - TokenDetails from JSON', () {
      test('deserializes from JSON response', () {
        final jsonData = {
          'token': 'deserialized-token',
          'expires': 1234567890000,
          'issued': 1234567800000,
          'capability': '{"channel-1":["publish"]}',
          'clientId': 'json-client',
          'keyName': 'appId.keyId',
        };

        final tokenDetails = TokenDetails.fromJson(jsonData);

        expect(tokenDetails.token, equals('deserialized-token'));
        expect(tokenDetails.expires, equals(1234567890000));
        expect(tokenDetails.issued, equals(1234567800000));
        expect(tokenDetails.capability, equals('{"channel-1":["publish"]}'));
        expect(tokenDetails.clientId, equals('json-client'));
      });
    });
  });

  group('TokenParams', () {
    group('TK1-TK6 - TokenParams structure', () {
      test('TK1 - ttl attribute (milliseconds)', () {
        final params = TokenParams(ttl: 3600000);
        expect(params.ttl, equals(3600000));
      });

      test('TK1 - ttl defaults to null when not specified', () {
        // RSA5 depends on this — null means "let server decide"
        final params = TokenParams();
        expect(params.ttl, isNull);
      });

      test('TK2 - capability attribute', () {
        final params = TokenParams(capability: '{"*":["subscribe"]}');
        expect(params.capability, equals('{"*":["subscribe"]}'));
      });

      test('TK2 - capability defaults to null when not specified', () {
        // RSA6 depends on this — null means "use key capabilities"
        final params = TokenParams();
        expect(params.capability, isNull);
      });

      test('TK3 - clientId attribute', () {
        final params = TokenParams(clientId: 'param-client');
        expect(params.clientId, equals('param-client'));
      });

      test('TK4 - timestamp attribute (milliseconds since epoch)', () {
        final params = TokenParams(timestamp: 1234567890000);
        expect(params.timestamp, equals(1234567890000));
      });

      test('TK5 - nonce attribute', () {
        final params = TokenParams(nonce: 'unique-nonce-value');
        expect(params.nonce, equals('unique-nonce-value'));
      });

      test('TK6 - All attributes together', () {
        final params = TokenParams(
          ttl: 7200000,
          capability: '{"*":["*"]}',
          clientId: 'full-client',
          timestamp: 1234567890000,
          nonce: 'full-nonce',
        );

        expect(params.ttl, equals(7200000));
        expect(params.capability, equals('{"*":["*"]}'));
        expect(params.clientId, equals('full-client'));
        expect(params.timestamp, equals(1234567890000));
        expect(params.nonce, equals('full-nonce'));
      });
    });

    group('TK - TokenParams to query string', () {
      test('converts to query parameters', () {
        final params = TokenParams(
          ttl: 3600000,
          clientId: 'query-client',
          capability: '{"ch":["pub"]}',
        );

        final queryMap = params.toQueryParams();

        expect(queryMap['ttl'], equals('3600000'));
        expect(queryMap['clientId'], equals('query-client'));
        expect(queryMap['capability'], equals('{"ch":["pub"]}'));
      });
    });
  });

  group('TokenRequest', () {
    group('TE1-TE6 - TokenRequest structure', () {
      test('TE1 - keyName attribute', () {
        final request = TokenRequest(
          keyName: 'appId.keyId',
          timestamp: 1234567890000,
          nonce: 'nonce-1',
        );
        expect(request.keyName, equals('appId.keyId'));
      });

      test('TE2 - ttl attribute', () {
        final request = TokenRequest(
          keyName: 'appId.keyId',
          ttl: 3600000,
          timestamp: 1234567890000,
          nonce: 'nonce-2',
        );
        expect(request.ttl, equals(3600000));
      });

      test('TE2 - ttl defaults to null when not specified', () {
        // RSA5 depends on this — createTokenRequest must be able to omit ttl
        final request = TokenRequest(
          keyName: 'appId.keyId',
          timestamp: 1234567890000,
          nonce: 'nonce-2b',
        );
        expect(request.ttl, isNull);
      });

      test('TE3 - capability attribute', () {
        final request = TokenRequest(
          keyName: 'appId.keyId',
          capability: '{"*":["*"]}',
          timestamp: 1234567890000,
          nonce: 'nonce-3',
        );
        expect(request.capability, equals('{"*":["*"]}'));
      });

      test('TE3 - capability defaults to null when not specified', () {
        // RSA6 depends on this — createTokenRequest must be able to omit capability
        final request = TokenRequest(
          keyName: 'appId.keyId',
          timestamp: 1234567890000,
          nonce: 'nonce-3b',
        );
        expect(request.capability, isNull);
      });

      test('TE4 - clientId attribute', () {
        final request = TokenRequest(
          keyName: 'appId.keyId',
          clientId: 'request-client',
          timestamp: 1234567890000,
          nonce: 'nonce-4',
        );
        expect(request.clientId, equals('request-client'));
      });

      test('TE5 - timestamp attribute', () {
        final request = TokenRequest(
          keyName: 'appId.keyId',
          timestamp: 1234567890000,
          nonce: 'nonce-5',
        );
        expect(request.timestamp, equals(1234567890000));
      });

      test('TE6 - nonce attribute', () {
        final request = TokenRequest(
          keyName: 'appId.keyId',
          timestamp: 1234567890000,
          nonce: 'unique-nonce',
        );
        expect(request.nonce, equals('unique-nonce'));
      });
    });

    group('TE - TokenRequest with mac (signature)', () {
      test('includes mac signature', () {
        final request = TokenRequest(
          keyName: 'appId.keyId',
          timestamp: 1234567890000,
          nonce: 'nonce-value',
          mac: 'signature-base64',
        );

        expect(request.mac, equals('signature-base64'));
      });
    });

    group('TE - TokenRequest to JSON', () {
      test('serializes correctly for transmission', () {
        final request = TokenRequest(
          keyName: 'appId.keyId',
          ttl: 3600000,
          capability: '{"*":["*"]}',
          clientId: 'json-client',
          timestamp: 1234567890000,
          nonce: 'json-nonce',
          mac: 'json-mac',
        );

        final jsonData = request.toJson();

        expect(jsonData['keyName'], equals('appId.keyId'));
        expect(jsonData['ttl'], equals(3600000));
        expect(jsonData['capability'], equals('{"*":["*"]}'));
        expect(jsonData['clientId'], equals('json-client'));
        expect(jsonData['timestamp'], equals(1234567890000));
        expect(jsonData['nonce'], equals('json-nonce'));
        expect(jsonData['mac'], equals('json-mac'));
      });
    });

    group('TE - TokenRequest from JSON', () {
      test('deserializes from JSON', () {
        final jsonData = {
          'keyName': 'appId.keyId',
          'ttl': 7200000,
          'capability': '{"ch":["sub"]}',
          'clientId': 'from-json-client',
          'timestamp': 1234567899999,
          'nonce': 'from-json-nonce',
          'mac': 'from-json-mac',
        };

        final request = TokenRequest.fromJson(jsonData);

        expect(request.keyName, equals('appId.keyId'));
        expect(request.ttl, equals(7200000));
        expect(request.capability, equals('{"ch":["sub"]}'));
        expect(request.clientId, equals('from-json-client'));
        expect(request.timestamp, equals(1234567899999));
        expect(request.nonce, equals('from-json-nonce'));
        expect(request.mac, equals('from-json-mac'));
      });
    });
  });
}
