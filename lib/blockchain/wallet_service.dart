import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import 'contract_config.dart';

class WalletService {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _keyWalletAddress = 'reown_wallet_address';
  static const String _keyChainId = 'reown_chain_id';
  static const String _keySessionUri = 'reown_session_uri';

  String? _walletAddress;
  int _currentChainId = ContractConfig.chainId;
  String? _pairingUri;

  String? get walletAddress => _walletAddress;
  int get currentChainId => _currentChainId;
  String? get pairingUri => _pairingUri;

  bool get isConnected => _walletAddress != null && _walletAddress!.isNotEmpty;
  bool get isSepoliaNetwork => _currentChainId == ContractConfig.chainId;

  String get shortAddress {
    if (_walletAddress == null || _walletAddress!.isEmpty) return '';
    return ContractConfig.getShortAddress(_walletAddress!);
  }

  Future<void> init() async {
    final savedAddress = await _storage.read(key: _keyWalletAddress);
    final savedChainIdStr = await _storage.read(key: _keyChainId);

    if (savedAddress != null && savedAddress.trim().isNotEmpty) {
      _walletAddress = savedAddress.trim();
    }
    if (savedChainIdStr != null) {
      _currentChainId = int.tryParse(savedChainIdStr) ?? ContractConfig.chainId;
    }
  }

  /// [Langkah 2]: Generate WalletConnect v2 / Reown URI untuk MetaMask
  /// Format: wc:(topic)@2?relay-protocol=irn&symKey=(symKey)&projectId=(projectId)
  String generatePairingUri() {
    final rand = Random.secure();
    final topic = List.generate(32, (_) => rand.nextInt(16).toRadixString(16)).join();
    final symKey = List.generate(32, (_) => rand.nextInt(16).toRadixString(16)).join();
    final projectId = ContractConfig.reownProjectId;

    _pairingUri = 'wc:$topic@2?relay-protocol=irn&symKey=$symKey&projectId=$projectId';
    return _pairingUri!;
  }

  /// [Langkah 3]: Buka aplikasi MetaMask di perangkat HP / Emulator
  Future<bool> launchMetaMaskApp({String? customUri}) async {
    final uriToUse = customUri ?? _pairingUri ?? generatePairingUri();
    final encoded = Uri.encodeComponent(uriToUse);
    final metamaskDeepLink = Uri.parse('metamask://wc?uri=$encoded');

    try {
      if (await canLaunchUrl(metamaskDeepLink)) {
        return await launchUrl(metamaskDeepLink, mode: LaunchMode.externalApplication);
      } else {
        // Fallback buka via Universal Link MetaMask
        final universalLink = Uri.parse('https://metamask.app.link/wc?uri=$encoded');
        if (await canLaunchUrl(universalLink)) {
          return await launchUrl(universalLink, mode: LaunchMode.externalApplication);
        } else {
          // Buka web MetaMask
          return await openMetaMaskWeb();
        }
      }
    } catch (_) {
      return await openMetaMaskWeb();
    }
  }

  /// Buka Web MetaMask / Portfolio
  Future<bool> openMetaMaskWeb() async {
    final webUri = Uri.parse('https://portfolio.metamask.io/');
    try {
      return await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// [Langkah 4 & 5]: Simpan sesi koneksi dompet pengguna
  Future<void> connect(String address, {int? chainId}) async {
    String cleanAddr = address.trim();
    if (!cleanAddr.startsWith('0x')) {
      cleanAddr = '0x$cleanAddr';
    }

    if (cleanAddr.length != 42) {
      throw Exception('Format alamat wallet tidak valid (harus 42 karakter dan diawali 0x).');
    }

    _walletAddress = cleanAddr;
    _currentChainId = chainId ?? ContractConfig.chainId;

    await _storage.write(key: _keyWalletAddress, value: cleanAddr);
    await _storage.write(key: _keyChainId, value: _currentChainId.toString());
    if (_pairingUri != null) {
      await _storage.write(key: _keySessionUri, value: _pairingUri);
    }
  }

  /// Ubah / set Chain ID aktif untuk validasi jaringan Sepolia
  Future<void> setChainId(int chainId) async {
    _currentChainId = chainId;
    await _storage.write(key: _keyChainId, value: chainId.toString());
  }

  /// [Langkah 7]: Disconnect Wallet
  Future<void> disconnect() async {
    _walletAddress = null;
    _currentChainId = ContractConfig.chainId;
    _pairingUri = null;

    await _storage.delete(key: _keyWalletAddress);
    await _storage.delete(key: _keyChainId);
    await _storage.delete(key: _keySessionUri);
  }

  /// Mengirim permintaan transaksi smart contract ke MetaMask (EIP-681 / EIP-1193)
  Future<bool> requestTransactionApproval({
    required String contractAddress,
    required String dataHex,
  }) async {
    final urlString = 'ethereum:$contractAddress@${ContractConfig.chainId}?data=$dataHex';
    final uri = Uri.parse(urlString);

    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        return await launchMetaMaskApp();
      }
    } catch (_) {
      return await launchMetaMaskApp();
    }
  }
}

