enum ApiErrorCode {
  BAD_REQUEST,
  UNAUTHORIZED,
  QUOTA_EXCEEDED,
  PAYLOAD_TOO_LARGE,
  RATE_LIMITED,
  SERVER_ERROR,
}

class ApiError implements Exception {
  final ApiErrorCode code;
  final String message;

  ApiError(this.code, this.message);
}