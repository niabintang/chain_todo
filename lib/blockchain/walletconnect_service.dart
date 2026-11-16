import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web3dart/web3dart.dart';

enum WalletConnectionMode {
  none,
  walletConnect,
  privateKey,
}

class WalletConnectService {
  static final WalletConnectService _instance = WalletConnectService._internal();
  factory WalletConnectService() => _instance;
  WalletConnectService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  static const String _keyConnectedAddress = 'wc_connected_address';
  static const String _keyConnectionMode = 'wallet_connection_mode';
  static const String _keySessionTopic = 'wc_session_topic';

  String? _connectedAddress;
  WalletConnectionMode _connectionMode = WalletConnectionMode.none;
  String? _currentWcUri;

  String? get connectedAddress => _connectedAddress;
  WalletConnectionMode get connectionMode => _connectionMode;
  String? get currentWcUri => _currentWcUri;
  bool get isWalletConnectActive => _connectionMode == WalletConnectionMode.walletConnect && _connectedAddress != null;

  Future<void> init() async {
    final modeStr = await _storage.read(key: _keyConnectionMode);
    final savedAddress = await _storage.read(key: _keyConnectedAddress);

    if (modeStr == 'walletConnect' && savedAddress != null) {
      _connectionMode = WalletConnectionMode.walletConnect;
      _connectedAddress = savedAddress;
    } else if (modeStr == 'privateKey') {
      _connectionMode = WalletConnectionMode.privateKey;
    } else {
      _connectionMode = WalletConnectionMode.none;
    }
  }

  /// [Langkah C]: Generate WalletConnect v2 / Reown pairing URI
  /// Format: wc:(topic)@2?relay-protocol=irn&symKey=(symKey)
  String generateWalletConnectUri() {
    final rand = Random.secure();
    final topic = List.generate(32, (_) => rand.nextInt(16).toRadixString(16)).join();
    final symKey = List.generate(32, (_) => rand.nextInt(16).toRadixString(16)).join();

    _currentWcUri = 'wc:$topic@2?relay-protocol=irn&symKey=$symKey';
    return _currentWcUri!;
  }

  /// Membuka Web Browser MetaMask (Portfolio / Web dApp)
  Future<bool> launchMetaMaskWeb({String? address}) async {
    Uri webUri;
    if (address != null && address.isNotEmpty) {
      webUri = Uri.parse('https://portfolio.metamask.io/?tab=tokens');
    } else {
      webUri = Uri.parse('https://metamask.io/download/');
    }

    try {
      return await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Membuka aplikasi MetaMask di HP melalui Deep Link
  Future<bool> launchMetaMaskWithUri({String? uri}) async {
    final targetUri = uri ?? _currentWcUri ?? generateWalletConnectUri();
    final encoded = Uri.encodeComponent(targetUri);
    final metamaskDeepLink = Uri.parse('metamask://wc?uri=$encoded');

    try {
      if (await canLaunchUrl(metamaskDeepLink)) {
        return await launchUrl(metamaskDeepLink, mode: LaunchMode.externalApplication);
      } else {
        // Fallback buka Web MetaMask
        return await launchMetaMaskWeb();
      }
    } catch (_) {
      return await launchMetaMaskWeb();
    }
  }

  /// Alias pembuka MetaMask
  Future<bool> launchMetaMaskApp() => launchMetaMaskWithUri();

  /// [Langkah F & G & H & I]: Simpan session terhubung dan address dompet
  Future<void> completeSession(String walletAddress) async {
    String cleanAddr = walletAddress.trim();
    if (!cleanAddr.startsWith('0x')) {
      cleanAddr = '0x$cleanAddr';
    }

    if (cleanAddr.length != 42) {
      throw Exception('Format alamat dompet tidak valid (harus 42 karakter diawali 0x).');
    }

    _connectedAddress = cleanAddr;
    _connectionMode = WalletConnectionMode.walletConnect;

    await _storage.write(key: _keyConnectedAddress, value: cleanAddr);
    await _storage.write(key: _keyConnectionMode, value: 'walletConnect');
    if (_currentWcUri != null) {
      await _storage.write(key: _keySessionTopic, value: _currentWcUri);
    }
  }

  /// Memutuskan koneksi dompet
  Future<void> disconnect() async {
    _connectedAddress = null;
    _connectionMode = WalletConnectionMode.none;
    _currentWcUri = null;
    await _storage.delete(key: _keyConnectedAddress);
    await _storage.delete(key: _keyConnectionMode);
    await _storage.delete(key: _keySessionTopic);
  }

  /// Buka MetaMask untuk konfirmasi transaksi on-chain
  Future<bool> openMetaMaskForTransaction({
    required String contractAddress,
    required String dataHex,
  }) async {
    final urlString = 'ethereum:$contractAddress@11155111?data=$dataHex';
    final uri = Uri.parse(urlString);

    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        return await launchMetaMaskWeb();
      }
    } catch (_) {
      return await launchMetaMaskWeb();
    }
  }

  /// Encode data pemanggilan smart contract function
  String encodeCallData(DeployedContract contract, String functionName, List<dynamic> params) {
    final function = contract.function(functionName);
    final encodedBytes = function.encodeCall(params);
    final hexString = encodedBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '0x$hexString';
  }
}
