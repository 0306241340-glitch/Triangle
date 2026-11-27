import 'package:firebase_auth/firebase_auth.dart';

import '../core/api_client.dart';
import '../models/item_model.dart';

class StoreService {
  StoreService({ApiClient? api, FirebaseAuth? auth})
    : _api = api ?? ApiClient(),
      _dangNhap = auth ?? FirebaseAuth.instance;

  final ApiClient _api;
  final FirebaseAuth _dangNhap;

  Future<StoreCatalog> loadCatalog() async {
    await _ganToken();

    final duLieu = await _api.get('/store/items') as Map<String, dynamic>;
    return StoreCatalog.fromJson(duLieu);
  }

  Future<Map<String, dynamic>> loadInventory() async {
    await _ganToken();

    return await _api.get('/store/inventory') as Map<String, dynamic>;
  }

  Future<StorePurchaseResult> purchase(String maVatPham) async {
    await _ganToken();

    final duLieu = await _api.post('/store/purchase', {
      'itemId': maVatPham,
    }) as Map<String, dynamic>;

    return StorePurchaseResult.fromJson(duLieu);
  }

  Future<void> setEquipped(
    String maVatPham, {
    required bool dangTrangBi,
  }) async {
    await _ganToken();

    await _api.post('/store/equip', {
      'itemId': maVatPham,
      'equipped': dangTrangBi,
    });
  }

  Future<void> _ganToken() async {
    final nguoiDung = _dangNhap.currentUser;

    if (nguoiDung == null) {
      throw StateError('Bạn cần đăng nhập để sử dụng cửa hàng.');
    }

    final maToken = await nguoiDung.getIdToken();

    if (maToken == null || maToken.isEmpty) {
      throw StateError('Không lấy được phiên đăng nhập. Hãy đăng nhập lại.');
    }

    _api.setToken(maToken);
  }
}
