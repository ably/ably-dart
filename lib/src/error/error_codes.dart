/// Ably error codes.
///
/// See: https://ably.com/docs/api/realtime-sdk/types#error-info
abstract class ErrorCodes {
  ErrorCodes._();

  // 400xx - Bad Request errors
  static const int badRequest = 40000;
  static const int invalidRequestBody = 40001;
  static const int invalidParameterName = 40002;
  static const int invalidParameterValue = 40003;

  // 401xx - Unauthorized errors
  static const int unauthorized = 40100;
  static const int invalidCredentials = 40101;
  static const int incompatibleCredentials = 40102;
  static const int invalidUseOfBasicAuthOverNonTls = 40103;
  static const int timestampNotCurrent = 40104;
  static const int nonceValueReplayed = 40105;
  static const int noMeansProvidedToRenewToken = 40106;

  // 403xx - Forbidden errors
  static const int forbidden = 40300;
  static const int accountDisabled = 40301;
  static const int operationNotPermitted = 40302;
  static const int applicationDisabled = 40303;

  // 404xx - Not Found errors
  static const int notFound = 40400;

  // 405xx - Method Not Allowed
  static const int methodNotAllowed = 40500;

  // 500xx - Server errors
  static const int internalError = 50000;

  // Client-specific error codes
  static const int clientConfiguredWithoutApiKey = 40106;
}
