import 'package:flutter/material.dart';

import 'api_error.dart';

void handleApiErrorWithSnack(BuildContext context, ApiError error) {
  final message = switch (error.code) {
    ApiErrorCode.BAD_REQUEST => 'Gecersiz istek.',
    ApiErrorCode.UNAUTHORIZED => 'Giris gerekli.',
    ApiErrorCode.QUOTA_EXCEEDED => 'Gunluk limit doldu.',
    ApiErrorCode.PAYLOAD_TOO_LARGE => 'PDF cok buyuk.',
    ApiErrorCode.RATE_LIMITED => 'Cok hizli denedin. 1 dakika sonra tekrar dene.',
    ApiErrorCode.SERVER_ERROR => 'Sunucu hatasi. Tekrar dene.',
  };
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
