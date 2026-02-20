import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/api_error_mapper.dart';

class MeService {
  final ApiClient _client;

  MeService(this._client);

  Future<Map<String, dynamic>> getMe() async {
    try {
      return await _client.getMe();
    } on Exception catch (e) {
      final ApiError apiError = mapToApiError(e);
      throw apiError;
    }
  }
}