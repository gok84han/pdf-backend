import 'package:in_app_purchase/in_app_purchase.dart';

class ProPlanService {
  static const int proMonthlyLimit = 100;

  static const String productMonthlyId = "pdf_pro_monthly";

  static const String productYearlyId = "pdf_pro_yearly";

  final InAppPurchase _iap = InAppPurchase.instance;

  Future<ProductDetailsResponse> fetchProducts() async {
    final available = await _iap.isAvailable();
    if (!available) {
      return ProductDetailsResponse(
        productDetails: const [],
        notFoundIDs: const [productMonthlyId, productYearlyId],
        error: null,
      );
    }
    return _iap.queryProductDetails({productMonthlyId, productYearlyId});
  }

  Future<bool> isProActive() async {
    return false;
  }
}
