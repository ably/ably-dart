import 'package:ably_dart/ably_dart.dart';
import 'package:test/test.dart';

/// Error Types Tests
///
/// Spec points: TI1, TI2, TI3, TI4, TI5
void main() {
  group('ErrorInfo', () {
    group('TI1-TI5 - ErrorInfo attributes', () {
      test('TI1 - code attribute', () {
        final error = ErrorInfo(code: 40000);
        expect(error.code, equals(40000));
      });

      test('TI2 - statusCode attribute', () {
        final error = ErrorInfo(code: 40100, statusCode: 401);
        expect(error.statusCode, equals(401));
      });

      test('TI3 - message attribute', () {
        final error = ErrorInfo(
          code: 40000,
          statusCode: 400,
          message: 'Bad request: invalid parameter',
        );
        expect(error.message, equals('Bad request: invalid parameter'));
      });

      test('TI4 - href attribute (optional)', () {
        final error = ErrorInfo(
          code: 40000,
          href: 'https://help.ably.io/error/40000',
        );
        expect(error.href, equals('https://help.ably.io/error/40000'));
      });

      test('TI5 - cause attribute (optional)', () {
        final originalError = Exception('Network failure');
        final error = ErrorInfo(
          code: 50003,
          statusCode: 500,
          message: 'Timeout',
          cause: originalError,
        );
        expect(error.cause, equals(originalError));
      });
    });

    group('TI - ErrorInfo from JSON response', () {
      test('parses error from JSON response', () {
        final jsonResponse = {
          'code': 40100,
          'statusCode': 401,
          'message': 'Token expired',
          'href': 'https://help.ably.io/error/40100',
        };

        final error = ErrorInfo.fromJson(jsonResponse);

        expect(error.code, equals(40100));
        expect(error.statusCode, equals(401));
        expect(error.message, equals('Token expired'));
        expect(error.href, equals('https://help.ably.io/error/40100'));
      });
    });

    group('TI - ErrorInfo with nested error', () {
      test('parses error response with nested error structure', () {
        final jsonResponse = {
          'code': 50000,
          'statusCode': 500,
          'message': 'Internal error',
          'cause': {
            'code': 50001,
            'message': 'Database connection failed',
          },
        };

        final error = ErrorInfo.fromJson(jsonResponse);

        expect(error.code, equals(50000));
        expect(error.cause, isNotNull);
        if (error.cause is ErrorInfo) {
          final causeError = error.cause as ErrorInfo;
          expect(causeError.code, equals(50001));
          expect(causeError.message, equals('Database connection failed'));
        }
      });
    });

    group('TI - Common error codes', () {
      final testCases = [
        (code: 40000, status: 400, meaning: 'Bad request'),
        (code: 40100, status: 401, meaning: 'Unauthorized'),
        (code: 40101, status: 401, meaning: 'Invalid credentials'),
        (code: 40140, status: 401, meaning: 'Token error'),
        (code: 40142, status: 401, meaning: 'Token expired'),
        (code: 40160, status: 401, meaning: 'Invalid capability'),
        (code: 40300, status: 403, meaning: 'Forbidden'),
        (code: 40400, status: 404, meaning: 'Not found'),
        (code: 50000, status: 500, meaning: 'Internal server error'),
        (code: 50003, status: 500, meaning: 'Timeout'),
      ];

      for (final testCase in testCases) {
        test('handles error code ${testCase.code}', () {
          final error = ErrorInfo(
            code: testCase.code,
            statusCode: testCase.status,
            message: testCase.meaning,
          );

          expect(error.code, equals(testCase.code));
          expect(error.statusCode, equals(testCase.status));
        });
      }
    });

    group('TI - Error string representation', () {
      test('has useful string representation', () {
        final error = ErrorInfo(
          code: 40100,
          statusCode: 401,
          message: 'Unauthorized: token expired',
        );

        final stringRepr = error.toString();

        expect(stringRepr, contains('40100'));
        expect(stringRepr, contains('401'));
      });
    });

    group('TI - Error equality', () {
      test('errors with same content are equal', () {
        final error1 = ErrorInfo(
          code: 40000,
          statusCode: 400,
          message: 'Bad request',
        );
        final error2 = ErrorInfo(
          code: 40000,
          statusCode: 400,
          message: 'Bad request',
        );
        final error3 = ErrorInfo(
          code: 40100,
          statusCode: 401,
          message: 'Unauthorized',
        );

        expect(error1, equals(error2));
        expect(error1, isNot(equals(error3)));
      });
    });
  });

  group('AblyException', () {
    test('wraps ErrorInfo', () {
      final errorInfo = ErrorInfo(
        code: 40000,
        statusCode: 400,
        message: 'Bad request',
      );

      final exception = AblyException(errorInfo: errorInfo);

      expect(exception.code, equals(40000));
      expect(exception.statusCode, equals(400));
      expect(exception.message, equals('Bad request'));
      expect(exception.errorInfo, equals(errorInfo));
    });
  });
}
