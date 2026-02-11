import 'dart:math';

import 'package:test/test.dart';
import 'package:ably_dart/ably_dart.dart';

import '../../helpers/jwt_helper.dart';
import '../../helpers/test_app_helper.dart';

/// Integration tests for Auth#revokeTokens (RSA17).
///
/// These tests run against the Ably Sandbox environment and verify
/// that token revocation actually prevents subsequent use of the
/// revoked token.
///
/// Uses ably-common test-app-setup.json:
///   keys[0] — full access (default capability)
///   keys[4] — revocableTokens: true
///
/// Spec: uts/test/rest/integration/revoke_tokens.md
void main() {
  late TestApp testApp;
  late String revocableKey;

  setUpAll(() async {
    testApp = await TestApp.provision();
    revocableKey = testApp.keys[4].keyStr;
    print('Provisioned test app: ${testApp.appId}');
  });

  tearDownAll(() async {
    await testApp.delete();
    print('Deleted test app: ${testApp.appId}');
  });

  group(
    'RSA17g, RSA17b, RSA17c, TRS2 - Token revocation prevents subsequent use',
    () {
      test('revoked JWT is rejected with error 40141', () async {
        final channelName = _uniqueName('revoke-test');
        final clientId = _uniqueName('revoke-client');

        // Generate a JWT with the revocable key, bound to a clientId
        final jwt = JwtHelper.generateToken(
          apiKey: revocableKey,
          clientId: clientId,
        );

        final tokenClient = Rest(
          options: ClientOptions(
            token: jwt,
            environment: 'sandbox',
            useBinaryProtocol: false,
          ),
        );

        final keyClient = Rest(
          options: ClientOptions(
            key: revocableKey,
            environment: 'sandbox',
            useBinaryProtocol: false,
          ),
        );

        try {
          // Step 1: Verify the JWT works
          final resultBefore =
              await tokenClient.request('GET', '/channels/$channelName');
          expect(resultBefore.statusCode, greaterThanOrEqualTo(200));
          expect(resultBefore.statusCode, lessThan(300));

          // Step 2: Revoke the token by clientId
          final revokeResult = await keyClient.auth.revokeTokens([
            TokenRevocationTargetSpecifier(type: 'clientId', value: clientId),
          ]);

          // Step 3: Verify the revokeTokens response structure
          expect(revokeResult.successCount, equals(1));
          expect(revokeResult.failureCount, equals(0));
          expect(revokeResult.results.length, equals(1));

          final success = revokeResult.results[0];
          expect(success, isA<TokenRevocationSuccessResult>());
          final successResult = success as TokenRevocationSuccessResult;
          expect(successResult.target, equals('clientId:$clientId'));
          expect(successResult.issuedBefore, isA<int>());
          expect(successResult.appliesAt, isA<int>());

          // Step 4: Wait for revocation to take effect
          final now = DateTime.now().millisecondsSinceEpoch;
          final waitMs = successResult.appliesAt - now;
          if (waitMs > 0) {
            await Future<void>.delayed(
              Duration(milliseconds: waitMs + 1000),
            );
          }

          // Step 5: Verify the JWT is now rejected
          await expectLater(
            () => tokenClient.request('GET', '/channels/$channelName'),
            throwsA(
              isA<AblyException>().having(
                (e) => e.errorInfo?.code,
                'error code',
                equals(40141),
              ),
            ),
          );
        } finally {
          await tokenClient.close();
          await keyClient.close();
        }
      });
    },
  );

  group('RSA17d - Token auth client rejected', () {
    test('revokeTokens from token-auth client fails with 40162', () async {
      final jwt = JwtHelper.generateToken(apiKey: revocableKey);

      final tokenClient = Rest(
        options: ClientOptions(
          token: jwt,
          environment: 'sandbox',
          useBinaryProtocol: false,
        ),
      );

      try {
        await expectLater(
          () => tokenClient.auth.revokeTokens([
            TokenRevocationTargetSpecifier(
              type: 'clientId',
              value: 'anyone',
            ),
          ]),
          throwsA(
            isA<AblyException>()
                .having(
                  (e) => e.errorInfo?.code,
                  'error code',
                  equals(40162),
                )
                .having(
                  (e) => e.errorInfo?.statusCode,
                  'status code',
                  equals(401),
                ),
          ),
        );
      } finally {
        await tokenClient.close();
      }
    });
  });

  group('RSA17e, RSA17f - issuedBefore and allowReauthMargin', () {
    test(
      'revocation with allowReauthMargin delays appliesAt and revokes token',
      () async {
        final channelName = _uniqueName('revoke-margin');
        final clientId = _uniqueName('revoke-margin-client');

        final jwt = JwtHelper.generateToken(
          apiKey: revocableKey,
          clientId: clientId,
        );

        final tokenClient = Rest(
          options: ClientOptions(
            token: jwt,
            environment: 'sandbox',
            useBinaryProtocol: false,
          ),
        );

        final keyClient = Rest(
          options: ClientOptions(
            key: revocableKey,
            environment: 'sandbox',
            useBinaryProtocol: false,
          ),
        );

        try {
          // Step 1: Verify the JWT works
          final resultBefore =
              await tokenClient.request('GET', '/channels/$channelName');
          expect(resultBefore.statusCode, greaterThanOrEqualTo(200));
          expect(resultBefore.statusCode, lessThan(300));

          // Step 2: Revoke with issuedBefore and allowReauthMargin
          final serverTime = await keyClient.time();
          final serverTimeMs = serverTime.millisecondsSinceEpoch;

          final revokeResult = await keyClient.auth.revokeTokens(
            [
              TokenRevocationTargetSpecifier(
                type: 'clientId',
                value: clientId,
              ),
            ],
            options: RevokeTokensOptions(
              issuedBefore: serverTimeMs,
              allowReauthMargin: true,
            ),
          );

          expect(revokeResult.successCount, equals(1));
          expect(revokeResult.results.length, equals(1));

          final success =
              revokeResult.results[0] as TokenRevocationSuccessResult;

          // RSA17e: issuedBefore should reflect what we sent
          expect(success.issuedBefore, equals(serverTimeMs));

          // RSA17f: allowReauthMargin delays appliesAt by ~30 seconds
          final thirtySecondsAfter = serverTimeMs + (30 * 1000);
          expect(success.appliesAt, greaterThan(thirtySecondsAfter));

          // Step 3: Wait for revocation to take effect
          final now = DateTime.now().millisecondsSinceEpoch;
          final waitMs = success.appliesAt - now;
          if (waitMs > 0) {
            await Future<void>.delayed(
              Duration(milliseconds: waitMs + 1000),
            );
          }

          // Step 4: Verify the JWT is now rejected
          await expectLater(
            () => tokenClient.request('GET', '/channels/$channelName'),
            throwsA(
              isA<AblyException>().having(
                (e) => e.errorInfo?.code,
                'error code',
                equals(40141),
              ),
            ),
          );
        } finally {
          await tokenClient.close();
          await keyClient.close();
        }
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });

  group('RSA17c, TRF2 - Mixed success and failure', () {
    test(
      'valid specifier revokes token, invalid specifier returns error',
      () async {
        final channelName = _uniqueName('revoke-mixed');
        final clientId = _uniqueName('revoke-mixed-client');

        final jwt = JwtHelper.generateToken(
          apiKey: revocableKey,
          clientId: clientId,
        );

        final tokenClient = Rest(
          options: ClientOptions(
            token: jwt,
            environment: 'sandbox',
            useBinaryProtocol: false,
          ),
        );

        final keyClient = Rest(
          options: ClientOptions(
            key: revocableKey,
            environment: 'sandbox',
            useBinaryProtocol: false,
          ),
        );

        try {
          // Step 1: Verify the JWT works
          final resultBefore =
              await tokenClient.request('GET', '/channels/$channelName');
          expect(resultBefore.statusCode, greaterThanOrEqualTo(200));
          expect(resultBefore.statusCode, lessThan(300));

          // Step 2: Revoke with one valid and one invalid specifier
          final revokeResult = await keyClient.auth.revokeTokens([
            TokenRevocationTargetSpecifier(type: 'clientId', value: clientId),
            TokenRevocationTargetSpecifier(
              type: 'invalidType',
              value: 'abc',
            ),
          ]);

          // Step 3: Verify the response contains both success and failure
          expect(revokeResult.successCount, equals(1));
          expect(revokeResult.failureCount, equals(1));
          expect(revokeResult.results.length, equals(2));

          // Valid specifier succeeds
          final success = revokeResult.results[0];
          expect(success, isA<TokenRevocationSuccessResult>());
          final successResult = success as TokenRevocationSuccessResult;
          expect(successResult.target, equals('clientId:$clientId'));
          expect(successResult.issuedBefore, isA<int>());
          expect(successResult.appliesAt, isA<int>());

          // Invalid specifier fails
          final failure = revokeResult.results[1];
          expect(failure, isA<TokenRevocationFailureResult>());
          final failureResult = failure as TokenRevocationFailureResult;
          expect(failureResult.target, equals('invalidType:abc'));
          expect(failureResult.error, isA<ErrorInfo>());
          expect(failureResult.error.statusCode, equals(400));

          // Step 4: Wait for revocation to take effect
          final now = DateTime.now().millisecondsSinceEpoch;
          final waitMs = successResult.appliesAt - now;
          if (waitMs > 0) {
            await Future<void>.delayed(
              Duration(milliseconds: waitMs + 1000),
            );
          }

          // Step 5: Verify the JWT is now rejected
          await expectLater(
            () => tokenClient.request('GET', '/channels/$channelName'),
            throwsA(
              isA<AblyException>().having(
                (e) => e.errorInfo?.code,
                'error code',
                equals(40141),
              ),
            ),
          );
        } finally {
          await tokenClient.close();
          await keyClient.close();
        }
      },
    );
  });
}

/// Generates a unique name for test isolation.
String _uniqueName(String prefix) {
  final random = Random().nextInt(999999).toString().padLeft(6, '0');
  return '$prefix-$random';
}
