import 'package:ably_dart/ably_dart.dart';
import 'package:test/test.dart';

/// Fallback and Endpoint Configuration Tests
///
/// Spec points: REC1, REC2, REC3
void main() {
  group('Fallback and Endpoint Configuration', () {
    group('REC1 - Primary Domain Configuration', () {
      test('REC1a - Default primary domain is rest.ably.io', () {
        final options = ClientOptions.fromKey('appId.keyId:keySecret');
        expect(options.effectiveRestHost, equals('rest.ably.io'));
      });

      group('REC1b2 - Endpoint as explicit hostname', () {
        test('hostname with period is explicit', () {
          final options = ClientOptions(
            key: 'appId.keyId:keySecret',
            endpoint: 'custom.host.com',
          );
          expect(options.effectiveRestHost, equals('custom.host.com'));
        });

        test('localhost is explicit hostname', () {
          final options = ClientOptions(
            key: 'appId.keyId:keySecret',
            endpoint: 'localhost',
          );
          expect(options.effectiveRestHost, equals('localhost'));
        });

        test('IPv6 address is explicit hostname', () {
          final options = ClientOptions(
            key: 'appId.keyId:keySecret',
            endpoint: '[::1]',
          );
          expect(options.effectiveRestHost, equals('[::1]'));
        });
      });

      group('REC1b3 - Endpoint as nonprod routing policy', () {
        test('nonprod:id format creates nonprod domain', () {
          final options = ClientOptions(
            key: 'appId.keyId:keySecret',
            endpoint: 'nonprod:myapp',
          );
          expect(
            options.effectiveRestHost,
            equals('myapp.nonprod-realtime.ably.net'),
          );
        });
      });

      group('REC1b4 - Endpoint as production routing policy', () {
        test('non-explicit endpoint creates production domain', () {
          final options = ClientOptions(
            key: 'appId.keyId:keySecret',
            endpoint: 'myapp',
          );
          expect(
            options.effectiveRestHost,
            equals('myapp.realtime.ably.net'),
          );
        });
      });

      group('REC1b1 - Endpoint conflicts with deprecated options', () {
        test('endpoint conflicts with environment', () {
          expect(
            () => ClientOptions(
              key: 'appId.keyId:keySecret',
              endpoint: 'myapp',
              environment: 'sandbox',
            ),
            throwsA(isA<ArgumentError>()),
          );
        });

        test('endpoint conflicts with restHost', () {
          expect(
            () => ClientOptions(
              key: 'appId.keyId:keySecret',
              endpoint: 'myapp',
              restHost: 'custom.host.com',
            ),
            throwsA(isA<ArgumentError>()),
          );
        });

        test('endpoint conflicts with realtimeHost', () {
          expect(
            () => ClientOptions(
              key: 'appId.keyId:keySecret',
              endpoint: 'myapp',
              realtimeHost: 'custom.realtime.com',
            ),
            throwsA(isA<ArgumentError>()),
          );
        });

        test('endpoint conflicts with fallbackHostsUseDefault', () {
          expect(
            () => ClientOptions(
              key: 'appId.keyId:keySecret',
              endpoint: 'myapp',
              fallbackHostsUseDefault: true,
            ),
            throwsA(isA<ArgumentError>()),
          );
        });
      });

      group('REC1c - Deprecated environment option', () {
        test('REC1c2 - environment determines primary domain', () {
          final options = ClientOptions(
            key: 'appId.keyId:keySecret',
            environment: 'sandbox',
          );
          expect(options.effectiveRestHost, equals('sandbox-rest.ably.io'));
        });

        test('REC1c1 - environment conflicts with restHost', () {
          expect(
            () => ClientOptions(
              key: 'appId.keyId:keySecret',
              environment: 'sandbox',
              restHost: 'custom.host.com',
            ),
            throwsA(isA<ArgumentError>()),
          );
        });
      });

      group('REC1d - Deprecated restHost option', () {
        test('REC1d1 - restHost determines primary domain', () {
          final options = ClientOptions(
            key: 'appId.keyId:keySecret',
            restHost: 'custom.rest.host',
          );
          expect(options.effectiveRestHost, equals('custom.rest.host'));
        });

        test('REC1d2 - realtimeHost can be set separately', () {
          final options = ClientOptions(
            key: 'appId.keyId:keySecret',
            realtimeHost: 'custom.realtime.host',
          );
          // realtimeHost doesn't affect REST host
          expect(options.effectiveRestHost, equals('rest.ably.io'));
          expect(options.realtimeHost, equals('custom.realtime.host'));
        });
      });
    });

    group('REC2 - Fallback Domains Configuration', () {
      test('REC2c1 - Default fallback domains', () {
        final options = ClientOptions.fromKey('appId.keyId:keySecret');
        // effectiveFallbackHosts returns null to use default from constants
        expect(options.effectiveFallbackHosts, isNull);
      });

      test('REC2a2 - Custom fallbackHosts option', () {
        final customHosts = ['fallback1.example.com', 'fallback2.example.com'];
        final options = ClientOptions(
          key: 'appId.keyId:keySecret',
          fallbackHosts: customHosts,
        );
        expect(options.effectiveFallbackHosts, equals(customHosts));
      });

      test('REC2a1 - fallbackHosts conflicts with fallbackHostsUseDefault', () {
        expect(
          () => ClientOptions(
            key: 'appId.keyId:keySecret',
            fallbackHosts: ['host.com'],
            fallbackHostsUseDefault: true,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('REC2b - Deprecated fallbackHostsUseDefault option', () {
        final options = ClientOptions(
          key: 'appId.keyId:keySecret',
          fallbackHostsUseDefault: false,
        );
        expect(options.effectiveFallbackHosts, isNull);
      });

      test('REC2c2 - Explicit hostname endpoint has no fallbacks', () {
        final options = ClientOptions(
          key: 'appId.keyId:keySecret',
          endpoint: 'custom.host.com',
        );
        expect(options.effectiveFallbackHosts, isNull);
      });

      test('REC2c3 - Nonprod routing policy fallback domains', () {
        final options = ClientOptions(
          key: 'appId.keyId:keySecret',
          endpoint: 'nonprod:myapp',
        );
        final fallbacks = options.effectiveFallbackHosts!;
        expect(fallbacks.length, equals(5));
        expect(
          fallbacks[0],
          equals('myapp.a-fallback.nonprod-realtime.ably.net'),
        );
        expect(
          fallbacks[1],
          equals('myapp.b-fallback.nonprod-realtime.ably.net'),
        );
      });

      test('REC2c4 - Production routing policy fallback domains (via endpoint)',
          () {
        final options = ClientOptions(
          key: 'appId.keyId:keySecret',
          endpoint: 'myapp',
        );
        final fallbacks = options.effectiveFallbackHosts!;
        expect(fallbacks.length, equals(5));
        expect(fallbacks[0], equals('myapp.a-fallback.realtime.ably.net'));
        expect(fallbacks[1], equals('myapp.b-fallback.realtime.ably.net'));
      });

      test(
          'REC2c5 - Production routing policy fallback domains (via deprecated environment)',
          () {
        final options = ClientOptions(
          key: 'appId.keyId:keySecret',
          environment: 'sandbox',
        );
        final fallbacks = options.effectiveFallbackHosts!;
        expect(fallbacks.length, equals(5));
        expect(fallbacks[0], equals('sandbox.a-fallback.realtime.ably.net'));
        expect(fallbacks[1], equals('sandbox.b-fallback.realtime.ably.net'));
      });

      test('REC2c6 - Custom restHost has no fallbacks', () {
        final options = ClientOptions(
          key: 'appId.keyId:keySecret',
          restHost: 'custom.host.com',
        );
        expect(options.effectiveFallbackHosts, isNull);
      });
    });

    group('REC3 - Connectivity Check URL', () {
      test('REC3a - Default connectivity check URL', () {
        final options = ClientOptions.fromKey('appId.keyId:keySecret');
        expect(
          options.effectiveConnectivityCheckUrl,
          equals('https://internet-up.ably-realtime.com/is-the-internet-up.txt'),
        );
      });

      test('REC3b - Custom connectivity check URL', () {
        final options = ClientOptions(
          key: 'appId.keyId:keySecret',
          connectivityCheckUrl: 'https://custom-check.example.com/check',
        );
        expect(
          options.effectiveConnectivityCheckUrl,
          equals('https://custom-check.example.com/check'),
        );
      });
    });
  });
}
