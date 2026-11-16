// Stub implementation untuk platform non-web (Android/iOS/Desktop/VM test)

class MetaMaskWebBridge {
  static bool get isSupported => false;

  static bool isMetaMaskAvailable() => false;

  static Future<List<String>> requestAccounts() async {
    throw Exception('MetaMask Extension hanya tersedia di platform Web.');
  }

  static Future<String?> getChainId() async => null;

  static Future<bool> switchChainToSepolia() async => false;

  static Future<String> sendTransaction({
    required String from,
    required String to,
    required String dataHex,
  }) async {
    throw Exception('MetaMask Extension hanya tersedia di platform Web.');
  }

  static void onAccountsChanged(void Function(List<String> accounts) callback) {}

  static void onChainChanged(void Function(String chainId) callback) {}
}

