import 'package:in_app_purchase/in_app_purchase.dart';

// Mock Purchase Service for web testing
class PurchaseService {
  void init(String userId) {}

  List<ProductDetails> get products => [];

  Future<void> buySubscription(ProductDetails productDetails) async {
    print('Mock purchase initiated for ${productDetails.id}');
  }
}
