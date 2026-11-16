import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:wallet/wallet.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;

import '../blockchain/contract_config.dart';
import '../blockchain/metamask_service.dart';
import '../blockchain/reown_service.dart';
import '../blockchain/wallet_service.dart';

class WalletController extends ChangeNotifier {
  static final WalletController _instance = WalletController._internal();
  factory WalletController() => _instance;
  WalletController._internal();

  final WalletService _walletService = WalletService();
  final MetaMaskService _metaMaskService = MetaMaskService();
  late Web3Client _web3Client;
  http.Client? _httpClient;

  bool _isLoading = false;
  double _balance = 0.0;
  String? _errorMessage;
  bool _isMetaMaskExtension = false;
  bool _listenersRegistered = false;

  bool get isLoading => _isLoading;
  double get balance => _balance;
  String? get errorMessage => _errorMessage;
  bool get isMetaMaskExtension => _isMetaMaskExtension;

  String? get walletAddress => _walletService.walletAddress;
  String get shortAddress => _walletService.shortAddress;
  bool get isConnected => _walletService.isConnected;
  bool get isSepoliaNetwork => _walletService.isSepoliaNetwork;
  int get currentChainId => _walletService.currentChainId;
  String? get pairingUri => _walletService.pairingUri;
  WalletService get service => _walletService;
  MetaMaskService get metaMaskService => _metaMaskService;

  bool get isMetaMaskInstalled => kIsWeb && _metaMaskService.isMetaMaskAvailable();

  Future<void> init() async {
    _httpClient = http.Client();
    _web3Client = Web3Client(ContractConfig.rpcUrl, _httpClient!);

    await _walletService.init();

    if (kIsWeb && _metaMaskService.isMetaMaskAvailable()) {
      _isMetaMaskExtension = true;
      _registerMetaMaskListeners();

      // Periksa chain ID aktif dari MetaMask
      final chainHex = await _metaMaskService.getChainId();
      if (chainHex != null) {
        _updateChainFromHex(chainHex);
      }
    }

    if (isConnected) {
      await refreshBalance();
    }
    notifyListeners();
  }

  /// [Fungsi Utama]: Menghubungkan langsung ke MetaMask Extension di Chrome via EIP-1193
  Future<void> connectMetaMaskExtension() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (!isMetaMaskInstalled) {
        throw Exception(
          'MetaMask Extension tidak terdeteksi. Silakan aktifkan MetaMask pada Google Chrome.',
        );
      }

      // 1. Memanggil eth_requestAccounts (Memunculkan popup MetaMask)
      final accounts = await _metaMaskService.requestAccounts();
      if (accounts.isEmpty) {
        throw Exception('Tidak ada akun yang dipilih di MetaMask.');
      }

      final primaryAddress = accounts.first;
      _isMetaMaskExtension = true;
      _registerMetaMaskListeners();

      // 2. Periksa Chain ID
      final chainHex = await _metaMaskService.getChainId();
      int chainId = ContractConfig.chainId;
      if (chainHex != null) {
        chainId = _parseChainId(chainHex);
      }

      // 3. Simpan state sesi
      await _walletService.connect(primaryAddress, chainId: chainId);

      // 4. Jika jaringan bukan Sepolia, otomatis tawarkan switch ke Sepolia
      if (chainId != ContractConfig.chainId) {
        try {
          await _metaMaskService.switchChainToSepolia();
          await _walletService.setChainId(ContractConfig.chainId);
        } catch (_) {}
      }

      await refreshBalance();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Pasang listener EIP-1193 (accountsChanged dan chainChanged)
  void _registerMetaMaskListeners() {
    if (_listenersRegistered || !kIsWeb) return;
    _listenersRegistered = true;

    _metaMaskService.onAccountsChanged((accounts) async {
      if (accounts.isEmpty) {
        // Pengguna disconnect akun dari MetaMask
        await disconnect();
      } else {
        // Pengguna berganti akun di MetaMask
        final newAddress = accounts.first;
        await _walletService.connect(newAddress, chainId: currentChainId);
        await refreshBalance();
        notifyListeners();
      }
    });

    _metaMaskService.onChainChanged((chainHex) async {
      _updateChainFromHex(chainHex);
      await refreshBalance();
      notifyListeners();
    });
  }

  int _parseChainId(String chainHex) {
    String clean = chainHex.trim();
    if (clean.startsWith('0x') || clean.startsWith('0X')) {
      return int.tryParse(clean.substring(2), radix: 16) ?? 0;
    }
    return int.tryParse(clean) ?? 0;
  }

  void _updateChainFromHex(String chainHex) {
    final parsed = _parseChainId(chainHex);
    _walletService.setChainId(parsed);
  }

  Future<void> connect(String address, {int? chainId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _walletService.connect(address, chainId: chainId);
      await refreshBalance();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> initReown(BuildContext context) async {
    if (!kIsWeb) {
      await ReownService().init(context);
      ReownService().addListener(() async {
        if (ReownService().isConnected && ReownService().walletAddress != null) {
          final addr = ReownService().walletAddress!;
          await _walletService.connect(addr, chainId: ReownService().currentChainId);
          await refreshBalance();
          notifyListeners();
        } else if (!ReownService().isConnected && isConnected && !_isMetaMaskExtension) {
          await _walletService.disconnect();
          await refreshBalance();
          notifyListeners();
        }
      });

      // Sinkronkan jika sesi sudah terhubung sebelumnya dari cache
      if (ReownService().isConnected && ReownService().walletAddress != null) {
        final addr = ReownService().walletAddress!;
        await _walletService.connect(addr, chainId: ReownService().currentChainId);
        await refreshBalance();
        notifyListeners();
      }
    }
  }

  Future<void> disconnect() async {
    _isLoading = true;
    notifyListeners();

    if (!kIsWeb) {
      await ReownService().disconnect();
    }
    await _walletService.disconnect();
    _balance = 0.0;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshBalance() async {
    if (!isConnected || walletAddress == null) {
      _balance = 0.0;
      notifyListeners();
      return;
    }

    try {
      final ethAddress = EthereumAddress.fromHex(walletAddress!);
      final etherAmount = await _web3Client.getBalance(ethAddress);
      _balance = etherAmount.getValueInUnit(EtherUnit.ether);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> switchNetworkToSepolia() async {
    if (kIsWeb && _metaMaskService.isMetaMaskAvailable()) {
      await _metaMaskService.switchChainToSepolia();
      final chainHex = await _metaMaskService.getChainId();
      if (chainHex != null) {
        _updateChainFromHex(chainHex);
      } else {
        await _walletService.setChainId(ContractConfig.chainId);
      }
    } else {
      await _walletService.setChainId(ContractConfig.chainId);
    }
    await refreshBalance();
    notifyListeners();
  }

  void openMetaMaskApp() {
    _walletService.launchMetaMaskApp();
  }

  void openMetaMaskWeb() {
    _walletService.openMetaMaskWeb();
  }

  @override
  void dispose() {
    _web3Client.dispose();
    _httpClient?.close();
    super.dispose();
  }
}
