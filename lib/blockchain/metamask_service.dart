import 'metamask_service_stub.dart'
    if (dart.library.js_interop) 'metamask_service_web.dart';

class MetaMaskService {
  static final MetaMaskService _instance = MetaMaskService._internal();
  factory MetaMaskService() => _instance;
  MetaMaskService._internal();

  bool get isSupported => MetaMaskWebBridge.isSupported;

  bool isMetaMaskAvailable() => MetaMaskWebBridge.isMetaMaskAvailable();

  Future<List<String>> requestAccounts() => MetaMaskWebBridge.requestAccounts();

  Future<String?> getChainId() => MetaMaskWebBridge.getChainId();

  Future<bool> switchChainToSepolia() => MetaMaskWebBridge.switchChainToSepolia();

  Future<String> sendTransaction({
    required String from,
    required String to,
    required String dataHex,
  }) {
    return MetaMaskWebBridge.sendTransaction(
      from: from,
      to: to,
      dataHex: dataHex,
    );
  }

  void onAccountsChanged(void Function(List<String> accounts) callback) {
    MetaMaskWebBridge.onAccountsChanged(callback);
  }

  void onChainChanged(void Function(String chainId) callback) {
    MetaMaskWebBridge.onChainChanged(callback);
  }
}

