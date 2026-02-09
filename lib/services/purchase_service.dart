import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:joinme2/services/database_service.dart';

const String _weekSubscriptionId = 'tydzien_premium';
const String _lifetimeProductId = 'dozywotnie_premium';

class PurchaseService {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final DatabaseService _databaseService = DatabaseService();
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  final _productIds = <String>{_weekSubscriptionId, _lifetimeProductId};
  List<ProductDetails> _products = [];

  void init(String userId) {
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList, userId);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      // handle error here.
    });
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(_productIds);
    if (response.notFoundIDs.isNotEmpty) {
      // Handle error
    }
    _products = response.productDetails;
  }

  Future<void> buySubscription(ProductDetails productDetails) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList, String userId) {
    purchaseDetailsList.forEach((PurchaseDetails purchaseDetails) async {
      if (purchaseDetails.status == PurchaseStatus.purchased) {
        // Grant premium access
        bool valid = await _verifyPurchase(purchaseDetails);
        if (valid) {
           // Update database
          _databaseService.updatePremiumStatus(userId, true);
          // complete purchase
          if (purchaseDetails.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchaseDetails);
          }
        }
      } 
      if (purchaseDetails.status == PurchaseStatus.restored) {
        // Restore premium access
         _databaseService.updatePremiumStatus(userId, true);
         if (purchaseDetails.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchaseDetails);
          }
      }
      if (purchaseDetails.status == PurchaseStatus.error) {
        // Handle error
      }
    });
  }

    Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) {
    // This is a basic verification. For a production app, you should implement server-side verification.
    return Future.value(true);
  }

    List<ProductDetails> get products => _products;
}
