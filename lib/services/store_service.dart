import 'package:firebase_auth/firebase_auth.dart';

import '../core/api_client.dart';
import '../models/item_model.dart';

class StoreService {
  StoreService({ApiClient? api, FirebaseAuth? auth})
    : _api = api ?? ApiClient(),
      _auth = auth ?? FirebaseAuth.instance;

  final ApiClient _api;
  final FirebaseAuth _auth;

  Future<StoreCatalog> loadCatalog() async {
    await _attachToken();
    final data = await _api.get('/store/items') as Map<String, dynamic>;
    return StoreCatalog.fromJson(data);
  }

  Future<Map<String, dynamic>> loadInventory() async {
    await _attachToken();
    return await _api.get('/store/inventory') as Map<String, dynamic>;
  }

  Future<StorePurchaseResult> purchase(String itemId) async {
    await _attachToken();
    final data = await _api.post('/store/purchase', {
      'itemId': itemId,
    }) as Map<String, dynamic>;
    return StorePurchaseResult.fromJson(data);
  }

  Future<void> setEquipped(String itemId, {required bool equipped}) async {
    await _attachToken();
    await _api.post('/store/equip', {'itemId': itemId, 'equipped': equipped});
  }

  Future<void> _attachToken() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Bạn cần đăng nhập để sử dụng cửa hàng.');
    }

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Không lấy được phiên đăng nhập. Hãy đăng nhập lại.');
    }
    _api.setToken(token);
  }
}
