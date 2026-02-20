import 'api_error.dart';

ApiError mapToApiError(Exception e) {
  final text = e.toString();
  final match = RegExp(r'HTTP_(\d+):\s*(.*)', dotAll: true).firstMatch(text);
  final statusCode = int.tryParse(match?.group(1) ?? '') ?? 500;
  final message = match?.group(2) ?? text;
  final isQuotaExceeded = statusCode == 403 && message.contains('QUOTA_EXCEEDED');

  final code = switch (statusCode) {
    400 => ApiErrorCode.BAD_REQUEST,
    401 => ApiErrorCode.UNAUTHORIZED,
    402 => ApiErrorCode.QUOTA_EXCEEDED,
    403 when isQuotaExceeded => ApiErrorCode.QUOTA_EXCEEDED,
    413 => ApiErrorCode.PAYLOAD_TOO_LARGE,
    429 => ApiErrorCode.RATE_LIMITED,
    500 => ApiErrorCode.SERVER_ERROR,
    _ => ApiErrorCode.SERVER_ERROR,
  };

  return ApiError(code, message);
}
