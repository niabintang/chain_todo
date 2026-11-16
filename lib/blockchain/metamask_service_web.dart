import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

class MetaMaskWebBridge {
  static bool get isSupported => true;

  static JSObject? get _bridge {
    try {
      if (globalContext.has('chainTodoMetaMask')) {
        return globalContext['chainTodoMetaMask'] as JSObject?;
      }
    } catch (_) {}
    return null;
  }

  /// Memeriksa apakah MetaMask Extension terpasang di browser Chrome
  static bool isMetaMaskAvailable() {
    final bridge = _bridge;
    if (bridge == null) return false;
    try {
      final res = bridge.callMethod<JSBoolean>('isAvailable'.toJS);
      return res.toDart;
    } catch (_) {
      return false;
    }
  }

  /// Meminta koneksi akun MetaMask melalui eth_requestAccounts
  static Future<List<String>> requestAccounts() async {
    final bridge = _bridge;
    if (bridge == null || !isMetaMaskAvailable()) {
      throw Exception('MetaMask Extension tidak terdeteksi. Silakan aktifkan MetaMask pada Google Chrome.');
    }

    try {
      final promise = bridge.callMethod<JSPromise<JSArray<JSString>>>('requestAccounts'.toJS);
      final jsArray = await promise.toDart;
      final list = <String>[];
      for (int i = 0; i < jsArray.length; i++) {
        final item = jsArray[i];
        list.add(item.toDart);
      }
      return list;
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('user rejected') || errStr.contains('4001')) {
        throw Exception('Permintaan koneksi dibatalkan oleh pengguna di MetaMask.');
      }
      throw Exception('Gagal menghubungkan ke MetaMask: $e');
    }
  }

  /// Mendapatkan chain ID aktif dari MetaMask melalui eth_chainId
  static Future<String?> getChainId() async {
    final bridge = _bridge;
    if (bridge == null) return null;
    try {
      final promise = bridge.callMethod<JSPromise<JSString?>>('getChainId'.toJS);
      final res = await promise.toDart;
      return res?.toDart;
    } catch (_) {
      return null;
    }
  }

  /// Meminta MetaMask berpindah jaringan ke Sepolia Testnet (0xaa36a7)
  static Future<bool> switchChainToSepolia() async {
    final bridge = _bridge;
    if (bridge == null) return false;
    try {
      final promise = bridge.callMethod<JSPromise<JSBoolean>>('switchChainToSepolia'.toJS);
      final res = await promise.toDart;
      return res.toDart;
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('user rejected') || errStr.contains('4001')) {
        throw Exception('Pengalihan jaringan ke Sepolia dibatalkan oleh pengguna.');
      }
      throw Exception('Gagal mengalihkan jaringan ke Sepolia: $e');
    }
  }

  /// Mengirim transaksi via MetaMask extension (eth_sendTransaction)
  static Future<String> sendTransaction({
    required String from,
    required String to,
    required String dataHex,
  }) async {
    final bridge = _bridge;
    if (bridge == null || !isMetaMaskAvailable()) {
      throw Exception('MetaMask Extension tidak terdeteksi.');
    }

    try {
      final promise = bridge.callMethod<JSPromise<JSString>>(
        'sendTransaction'.toJS,
        from.toJS,
        to.toJS,
        dataHex.toJS,
      );
      final res = await promise.toDart;
      return res.toDart;
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('user rejected') || errStr.contains('4001')) {
        throw Exception('Transaksi dibatalkan oleh pengguna di MetaMask.');
      }
      throw Exception('Transaksi gagal dikonfirmasi: $e');
    }
  }

  /// Memasang listener perubahan akun di MetaMask
  static void onAccountsChanged(void Function(List<String> accounts) callback) {
    final bridge = _bridge;
    if (bridge == null) return;
    try {
      final jsCallback = (JSArray<JSString> accounts) {
        final list = <String>[];
        for (int i = 0; i < accounts.length; i++) {
          list.add(accounts[i].toDart);
        }
        callback(list);
      }.toJS;
      bridge.callMethod('onAccountsChanged'.toJS, jsCallback);
    } catch (_) {}
  }

  /// Memasang listener perubahan jaringan di MetaMask
  static void onChainChanged(void Function(String chainId) callback) {
    final bridge = _bridge;
    if (bridge == null) return;
    try {
      final jsCallback = (JSString chainId) {
        callback(chainId.toDart);
      }.toJS;
      bridge.callMethod('onChainChanged'.toJS, jsCallback);
    } catch (_) {}
  }
}

