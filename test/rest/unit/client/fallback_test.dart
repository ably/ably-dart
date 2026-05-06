import 'dart:async';

import 'package:ably_dart/ably_dart.dart';
import 'package:test/test.dart';

import '../../../helpers/mock_http_client.dart';

/// Fallback and Endpoint Configuration Tests
///
/// Spec points: REC1, REC2, REC3, RSC15f
void main() {
  group('Fallback and Endpoint Configuration', () {
    group('REC1 - Primary Domain Configuration', () {
      // UTS: rest/unit/REC1a/default-primary-domain-0
      test('REC1a - Default primary domain is main.realtime.ably.net', () {
        final options = ClientOptions.fromKey('appId.keyId:keySecret');
        expect(options.primaryDomain, equals('main.realtime.ably.net'));
        expect(options.effectiveRestHost, equals('main.realtime.ably.net'));
        expect(options.effectiveRealtimeHost, equals('main.realtime.ably.net'));
      });

      group('REC1b2 - Endpoint as explicit hostname', () {
        // UTS: rest/unit/REC1b2/explicit-hostname-with-period-0
        test('hostname with period is explicit', () {
          final options = ClientOptions(
            key: 'appId.keyId:keySecret',
            endpoint: 'custom.host.com',
          );
          expect(options.primaryDomain, equals('custom.host.com'));
        });

        // UTS: rest/unit/REC1b2/endpoint-localhost-1
        test('localhost is explicit hostname', () {
          final options = ClientOptions(
            key: 'appId.keyId:keySecret',
            endpoint: 'localhost',
          );
          expect(options.primaryDomain, equals('localhost'));
        });

        // UTS: rest/unit/REC1b2/endpoint-ipv6-address-2
        test('IPv6 address with :: is explicit hostname', () {
          final options = ClientOptions(
            key: 'appId.keyId:keySecret',
            endpoint: '::1',
          );
          expect(options.primaryDomain, equals('::1'));
        });
      });

      group('REC1b3 - Endpoint as nonprod routing policy', () {
        // UTS: rest/unit/REC1b3/nonprod-routing-policy-0
        test('nonprod:id format creates nonprod domain', () {
          final options = ClientOptions(
            key: 'appId.keyId:keySecret',
            endpoint: 'nonprod:myapp',
          );
          expect(
            options.primaryDomain,
            equals('myapp.realtime.ably-nonprod.net'),
          );
        });
      });

      group('REC1b4 - Endpoint as production routing policy', () {
        // UTS: rest/unit/REC1b4/production-routing-policy-0
        test('non-explicit endpoint creates production domain', () {
          final options = ClientOptions(
            key: 'appId.keyId:keySecret',
            endpoint: 'myapp',
          );
          expect(
            options.primaryDomain,
            equals('myapp.realtime.ably.net'),
          );
        });

        // UTS: rest/unit/REC2c5/production-environment-fallback-domains-0
        test('sandbox is a production routing policy', () {
          final options = ClientOptions(
            key: 'appId.keyId:keySecret',
            endpoint: 'sandbox',
          );
          expect(
            options.primaryDomain,
            equals('sandbox.realtime.ably.net'),
          );
        });
      });

    });

    group('REC2 - Fallback Domains Configuration', () {
      // UTS: rest/unit/REC2c1/default-fallback-domains-0
      test('REC2c1 - Default fallback domains', () {
        final options = ClientOptions.fromKey('appId.keyId:keySecret');
        // effectiveFallbackHosts returns null to use default from constants
        expect(options.effectiveFallbackHosts, isNull);
      });

      // UTS: rest/unit/REC2a2/custom-fallback-hosts-0
      test('REC2a2 - Custom fallbackHosts option', () {
        final customHosts = ['fallback1.example.com', 'fallback2.example.com'];
        final options = ClientOptions(
          key: 'appId.keyId:keySecret',
          fallbackHosts: customHosts,
        );
        expect(options.effectiveFallbackHosts, equals(customHosts));
      });

      // UTS: rest/unit/REC2c2/explicit-hostname-no-fallbacks-0
      test('REC2c2 - Explicit hostname endpoint has no fallbacks', () {
        final options = ClientOptions(
          key: 'appId.keyId:keySecret',
          endpoint: 'custom.host.com',
        );
        expect(options.effectiveFallbackHosts, isNull);
      });

      // UTS: rest/unit/REC2c3/nonprod-fallback-domains-0
      test('REC2c3 - Nonprod routing policy fallback domains', () {
        final options = ClientOptions(
          key: 'appId.keyId:keySecret',
          endpoint: 'nonprod:myapp',
        );
        final fallbacks = options.effectiveFallbackHosts!;
        expect(fallbacks.length, equals(5));
        expect(
          fallbacks[0],
          equals('myapp.a.fallback.ably-realtime-nonprod.com'),
        );
        expect(
          fallbacks[1],
          equals('myapp.b.fallback.ably-realtime-nonprod.com'),
        );
      });

      // UTS: rest/unit/REC2c4/production-endpoint-fallback-domains-0
      test('REC2c4 - Production routing policy fallback domains (via endpoint)',
          () {
        final options = ClientOptions(
          key: 'appId.keyId:keySecret',
          endpoint: 'myapp',
        );
        final fallbacks = options.effectiveFallbackHosts!;
        expect(fallbacks.length, equals(5));
        expect(fallbacks[0], equals('myapp.a.fallback.ably-realtime.com'));
        expect(fallbacks[1], equals('myapp.b.fallback.ably-realtime.com'));
      });

    });

    group('REC3 - Connectivity Check URL', () {
      // UTS: rest/unit/REC3a/default-connectivity-check-url-0
      test('REC3a - Default connectivity check URL', () {
        final options = ClientOptions.fromKey('appId.keyId:keySecret');
        expect(
          options.effectiveConnectivityCheckUrl,
          equals('https://internet-up.ably-realtime.com/is-the-internet-up.txt'),
        );
      });

      // UTS: rest/unit/REC3b/custom-connectivity-check-url-0
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

    group('RSC15f - Fallback host caching', () {
      test(
          'RSC15f - expired preferred fallback not resurrected by late '
          'in-flight success', () async {
        PendingRequest? heldRequest;
        var requestIndex = 0;
        final hosts = <String>[];

        final mockHttp = MockHttpClient(
          onRequest: (req) {
            requestIndex++;
            hosts.add(req.url.host);
            if (requestIndex == 1) {
              req.respondWith(500, {
                'error': {
                  'message': 'fail',
                  'code': 50000,
                  'statusCode': 500,
                },
              });
            } else if (requestIndex == 2) {
              req.respondWith(200, [1000]);
            } else if (requestIndex == 3) {
              heldRequest = req;
            } else {
              req.respondWith(200, [1000]);
            }
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions(
            key: 'appId.keyId:keySecret',
            fallbackRetryTimeout: 100,
          ),
          httpClient: mockHttp,
        );

        // Request 1+2: primary fails → fallback succeeds → cached
        await client.time();
        final fallbackHost = hosts[1];
        expect(fallbackHost, isNot(equals('main.realtime.ably.net')));

        // Request 3: goes to cached fallback, hold the response
        final requestFuture = client.time();

        // Advance past fallbackRetryTimeout so cache expires
        await Future<void>.delayed(const Duration(milliseconds: 150));

        // Request 4: cache expired → primary again
        await client.time();
        expect(hosts[3], equals('main.realtime.ably.net'));

        // Complete the held request
        expect(heldRequest, isNotNull);
        heldRequest!.respondWith(200, [1000]);
        await requestFuture;

        // Request 5: late success must NOT re-pin fallback
        await client.time();

        expect(hosts, hasLength(5));
        expect(hosts[0], equals('main.realtime.ably.net'));
        expect(hosts[1], equals(fallbackHost));
        expect(hosts[2], equals(fallbackHost));
        expect(hosts[3], equals('main.realtime.ably.net'));
        expect(hosts[4], equals('main.realtime.ably.net'));
      });
    });
  });
}
