import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:wallet/wallet.dart';
import 'package:web3dart/web3dart.dart';

import '../models/tugas_model.dart';
import 'contract_config.dart';
import 'metamask_service.dart';
import 'reown_service.dart';
import 'wallet_service.dart';

class BlockchainService {
  static final BlockchainService _instance = BlockchainService._internal();
  factory BlockchainService() => _instance;
  BlockchainService._internal();

  late Web3Client _client;
  http.Client? _httpClient;
  DeployedContract? _contract;
  bool _initialized = false;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final WalletService _walletService = WalletService();
  final MetaMaskService _metaMaskService = MetaMaskService();

  static const String _storageKeyPrivateKey = 'chain_todo_private_key';

  bool get isInitialized => _initialized;
  WalletService get walletService => _walletService;
  MetaMaskService get metaMaskService => _metaMaskService;

  Future<void> init() async {
    _httpClient = http.Client();
    _client = Web3Client(ContractConfig.rpcUrl, _httpClient!);

    await _walletService.init();

    // Muat ABI dari file asset
    String abiString;
    try {
      abiString = await rootBundle.loadString('lib/blockchain/abi/chain_todo.json');
    } catch (_) {
      abiString = _fallbackAbi;
    }

    final abi = ContractAbi.fromJson(abiString, 'ChainTodo');
    _contract = DeployedContract(
      abi,
      EthereumAddress.fromHex(ContractConfig.contractAddress),
    );
    _initialized = true;
  }

  // --- Wallet & Key Management ---

  bool get isWalletConnected => _walletService.isConnected;

  Future<String?> getSavedPrivateKey() async {
    final saved = await _secureStorage.read(key: _storageKeyPrivateKey);
    if (saved != null && saved.trim().isNotEmpty) {
      return saved.trim();
    }
    if (ContractConfig.defaultPrivateKey.isNotEmpty) {
      return ContractConfig.defaultPrivateKey;
    }
    return null;
  }

  Future<void> savePrivateKey(String privateKey) async {
    String cleanKey = privateKey.trim();
    if (cleanKey.startsWith('0x')) {
      cleanKey = cleanKey.substring(2);
    }
    await _secureStorage.write(key: _storageKeyPrivateKey, value: cleanKey);
    await _walletService.disconnect();
  }

  Future<void> removeSavedPrivateKey() async {
    await _secureStorage.delete(key: _storageKeyPrivateKey);
  }

  EthPrivateKey? getCredentialsFromKey(String privateKeyHex) {
    try {
      String cleanKey = privateKeyHex.trim();
      if (cleanKey.startsWith('0x')) {
        cleanKey = cleanKey.substring(2);
      }
      return EthPrivateKey.fromHex(cleanKey);
    } catch (_) {
      return null;
    }
  }

  Future<String?> getCurrentWalletAddress() async {
    // 1. Prioritaskan dompet MetaMask jika terhubung
    if (_walletService.isConnected) {
      return _walletService.walletAddress;
    }

    // 2. Fallback jika ada private key lokal
    final pKey = await getSavedPrivateKey();
    if (pKey == null) return null;
    final creds = getCredentialsFromKey(pKey);
    return creds?.address.eip55With0x;
  }

  Future<double> getWalletBalance(String addressHex) async {
    try {
      final address = EthereumAddress.fromHex(addressHex);
      final balance = await _client.getBalance(address);
      return balance.getValueInUnit(EtherUnit.ether);
    } catch (_) {
      return 0.0;
    }
  }

  // --- Smart Contract Read Operations (Web3dart + Alchemy RPC) ---

  Future<int> getJumlahTugas() async {
    if (!_initialized || _contract == null) await init();
    final function = _contract!.function('jumlahTugas');
    final result = await _client.call(
      contract: _contract!,
      function: function,
      params: [],
    );
    final count = result.first as BigInt;
    return count.toInt();
  }

  Future<TugasModel> getTugas(int id) async {
    if (!_initialized || _contract == null) await init();
    final function = _contract!.function('ambilTugas');
    final result = await _client.call(
      contract: _contract!,
      function: function,
      params: [BigInt.from(id)],
    );

    final pembuatAddress = result[3];
    String pembuatHex = '';
    if (pembuatAddress is EthereumAddress) {
      pembuatHex = pembuatAddress.eip55With0x;
    } else {
      pembuatHex = pembuatAddress.toString();
    }

    final bool aktif = result.length > 4 ? (result[4] as bool) : true;

    return TugasModel(
      id: id,
      judul: result[0] as String,
      selesai: result[1] as bool,
      dibuat: (result[2] as BigInt).toInt(),
      pembuat: pembuatHex,
      aktif: aktif,
    );
  }

  Future<List<TugasModel>> getAllTugas() async {
    final total = await getJumlahTugas();
    final List<TugasModel> list = [];

    for (int i = 0; i < total; i++) {
      try {
        final item = await getTugas(i);
        // Hanya tampilkan tugas yang masih aktif (belum dihapus oleh pembuat)
        if (item.aktif) {
          list.add(item);
        }
      } catch (_) {
        // Lanjutkan pembacaan
      }
    }
    return list.reversed.toList();
  }

  // --- Smart Contract Write Operations (MetaMask EIP-1193 / Direct) ---

  String encodeCallData(String functionName, List<dynamic> params) {
    if (_contract == null) throw Exception('Kontrak belum dimuat');
    final function = _contract!.function(functionName);
    final bytes = function.encodeCall(params);
    final hexString = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '0x$hexString';
  }

  Future<String> tambahTugas(String judul, {String? privateKey}) async {
    if (!_initialized || _contract == null) await init();

    final userAddress = _walletService.walletAddress;

    // 1. Eksekusi via MetaMask Extension di Flutter Web (EIP-1193)
    if (kIsWeb && _metaMaskService.isMetaMaskAvailable() && userAddress != null) {
      final callData = encodeCallData('tambahTugas', [judul]);
      // Membuka popup konfirmasi MetaMask asli di Chrome
      final txHash = await _metaMaskService.sendTransaction(
        from: userAddress,
        to: ContractConfig.contractAddress,
        dataHex: callData,
      );
      return txHash;
    }

    // 2. Eksekusi via Reown AppKit di Android Mobile (MetaMask Mobile via WalletConnect)
    if (!kIsWeb && ReownService().isConnected) {
      final txHash = await ReownService().sendContractTransaction(
        contract: _contract!,
        functionName: 'tambahTugas',
        parameters: [judul],
      );
      await waitForReceipt(txHash);
      return txHash;
    }

    // Fallback jika mode pairing URI lama
    if (_walletService.isConnected) {
      final callData = encodeCallData('tambahTugas', [judul]);
      await _walletService.requestTransactionApproval(
        contractAddress: ContractConfig.contractAddress,
        dataHex: callData,
      );
      return 'METAMASK_APPROVAL_REQUESTED';
    }

    // 3. Fallback jika mode Private Key lokal
    final keyToUse = privateKey ?? await getSavedPrivateKey();
    if (keyToUse == null || keyToUse.isEmpty) {
      throw Exception('Wallet belum terhubung! Silakan klik tombol "Connect Wallet" MetaMask.');
    }

    final credentials = getCredentialsFromKey(keyToUse);
    if (credentials == null) throw Exception('Private key tidak valid.');

    final function = _contract!.function('tambahTugas');
    final txHash = await _client.sendTransaction(
      credentials,
      Transaction.callContract(
        contract: _contract!,
        function: function,
        parameters: [judul],
      ),
      chainId: ContractConfig.chainId,
    );
    return txHash;
  }

  Future<String> tandaiSelesai(int id, {String? privateKey}) async {
    if (!_initialized || _contract == null) await init();

    final userAddress = _walletService.walletAddress;

    // 1. Eksekusi via MetaMask Extension di Flutter Web (EIP-1193)
    if (kIsWeb && _metaMaskService.isMetaMaskAvailable() && userAddress != null) {
      final callData = encodeCallData('tandaiSelesai', [BigInt.from(id)]);
      // Membuka popup konfirmasi MetaMask asli di Chrome
      final txHash = await _metaMaskService.sendTransaction(
        from: userAddress,
        to: ContractConfig.contractAddress,
        dataHex: callData,
      );
      return txHash;
    }

    // 2. Eksekusi via Reown AppKit di Android Mobile (MetaMask Mobile via WalletConnect)
    if (!kIsWeb && ReownService().isConnected) {
      final txHash = await ReownService().sendContractTransaction(
        contract: _contract!,
        functionName: 'tandaiSelesai',
        parameters: [BigInt.from(id)],
      );
      await waitForReceipt(txHash);
      return txHash;
    }

    // Fallback jika mode pairing URI lama
    if (_walletService.isConnected) {
      final callData = encodeCallData('tandaiSelesai', [BigInt.from(id)]);
      await _walletService.requestTransactionApproval(
        contractAddress: ContractConfig.contractAddress,
        dataHex: callData,
      );
      return 'METAMASK_APPROVAL_REQUESTED';
    }

    // 3. Fallback jika mode Private Key lokal
    final keyToUse = privateKey ?? await getSavedPrivateKey();
    if (keyToUse == null || keyToUse.isEmpty) {
      throw Exception('Wallet belum terhubung! Silakan klik tombol "Connect Wallet" MetaMask.');
    }

    final credentials = getCredentialsFromKey(keyToUse);
    if (credentials == null) throw Exception('Private key tidak valid.');

    final function = _contract!.function('tandaiSelesai');
    final txHash = await _client.sendTransaction(
      credentials,
      Transaction.callContract(
        contract: _contract!,
        function: function,
        parameters: [BigInt.from(id)],
      ),
      chainId: ContractConfig.chainId,
    );
    return txHash;
  }

  // --- Fitur Bonus 2: Edit & Hapus Tugas oleh Pembuat ---

  Future<String> editTugas(int id, String judulBaru, {String? privateKey}) async {
    if (!_initialized || _contract == null) await init();

    final userAddress = _walletService.walletAddress;

    // 1. Eksekusi via MetaMask Extension di Flutter Web (EIP-1193)
    if (kIsWeb && _metaMaskService.isMetaMaskAvailable() && userAddress != null) {
      final callData = encodeCallData('editTugas', [BigInt.from(id), judulBaru]);
      final txHash = await _metaMaskService.sendTransaction(
        from: userAddress,
        to: ContractConfig.contractAddress,
        dataHex: callData,
      );
      return txHash;
    }

    // 2. Eksekusi via Reown AppKit di Android Mobile (MetaMask Mobile via WalletConnect)
    if (!kIsWeb && ReownService().isConnected) {
      final txHash = await ReownService().sendContractTransaction(
        contract: _contract!,
        functionName: 'editTugas',
        parameters: [BigInt.from(id), judulBaru],
      );
      await waitForReceipt(txHash);
      return txHash;
    }

    // Fallback jika mode pairing URI lama
    if (_walletService.isConnected) {
      final callData = encodeCallData('editTugas', [BigInt.from(id), judulBaru]);
      await _walletService.requestTransactionApproval(
        contractAddress: ContractConfig.contractAddress,
        dataHex: callData,
      );
      return 'METAMASK_APPROVAL_REQUESTED';
    }

    // 3. Fallback jika mode Private Key lokal
    final keyToUse = privateKey ?? await getSavedPrivateKey();
    if (keyToUse == null || keyToUse.isEmpty) {
      throw Exception('Wallet belum terhubung! Silakan klik tombol "Connect Wallet" MetaMask.');
    }

    final credentials = getCredentialsFromKey(keyToUse);
    if (credentials == null) throw Exception('Private key tidak valid.');

    final function = _contract!.function('editTugas');
    final txHash = await _client.sendTransaction(
      credentials,
      Transaction.callContract(
        contract: _contract!,
        function: function,
        parameters: [BigInt.from(id), judulBaru],
      ),
      chainId: ContractConfig.chainId,
    );
    return txHash;
  }

  Future<String> hapusTugas(int id, {String? privateKey}) async {
    if (!_initialized || _contract == null) await init();

    final userAddress = _walletService.walletAddress;

    // 1. Eksekusi via MetaMask Extension di Flutter Web (EIP-1193)
    if (kIsWeb && _metaMaskService.isMetaMaskAvailable() && userAddress != null) {
      final callData = encodeCallData('hapusTugas', [BigInt.from(id)]);
      final txHash = await _metaMaskService.sendTransaction(
        from: userAddress,
        to: ContractConfig.contractAddress,
        dataHex: callData,
      );
      return txHash;
    }

    // 2. Eksekusi via Reown AppKit di Android Mobile (MetaMask Mobile via WalletConnect)
    if (!kIsWeb && ReownService().isConnected) {
      final txHash = await ReownService().sendContractTransaction(
        contract: _contract!,
        functionName: 'hapusTugas',
        parameters: [BigInt.from(id)],
      );
      await waitForReceipt(txHash);
      return txHash;
    }

    // Fallback jika mode pairing URI lama
    if (_walletService.isConnected) {
      final callData = encodeCallData('hapusTugas', [BigInt.from(id)]);
      await _walletService.requestTransactionApproval(
        contractAddress: ContractConfig.contractAddress,
        dataHex: callData,
      );
      return 'METAMASK_APPROVAL_REQUESTED';
    }

    // 3. Fallback jika mode Private Key lokal
    final keyToUse = privateKey ?? await getSavedPrivateKey();
    if (keyToUse == null || keyToUse.isEmpty) {
      throw Exception('Wallet belum terhubung! Silakan klik tombol "Connect Wallet" MetaMask.');
    }

    final credentials = getCredentialsFromKey(keyToUse);
    if (credentials == null) throw Exception('Private key tidak valid.');

    final function = _contract!.function('hapusTugas');
    final txHash = await _client.sendTransaction(
      credentials,
      Transaction.callContract(
        contract: _contract!,
        function: function,
        parameters: [BigInt.from(id)],
      ),
      chainId: ContractConfig.chainId,
    );
    return txHash;
  }

  Future<TransactionReceipt?> waitForReceipt(String txHash, {int maxTries = 15}) async {
    for (int i = 0; i < maxTries; i++) {
      final receipt = await _client.getTransactionReceipt(txHash);
      if (receipt != null) return receipt;
      await Future.delayed(const Duration(seconds: 2));
    }
    return null;
  }

  String getTxExplorerUrl(String txHash) {
    final base = ContractConfig.explorerUrl.replaceAll(RegExp(r'/$'), '');
    return '$base/tx/$txHash';
  }

  String getAddressExplorerUrl(String address) {
    final base = ContractConfig.explorerUrl.replaceAll(RegExp(r'/$'), '');
    return '$base/address/$address';
  }

  // --- Event Listening (Fitur Bonus 1) ---

  /// Stream mendengarkan event TugasBaru dari Smart Contract
  Stream<FilterEvent>? dengarkanTugasBaru() {
    if (!_initialized || _contract == null) return null;
    try {
      final event = _contract!.event('TugasBaru');
      return _client.events(FilterOptions.events(
        contract: _contract!,
        event: event,
      ));
    } catch (e) {
      debugPrint("Gagal menginisialisasi listener TugasBaru: $e");
      return null;
    }
  }

  /// Stream mendengarkan event TugasSelesai dari Smart Contract
  Stream<FilterEvent>? dengarkanTugasSelesai() {
    if (!_initialized || _contract == null) return null;
    try {
      final event = _contract!.event('TugasSelesai');
      return _client.events(FilterOptions.events(
        contract: _contract!,
        event: event,
      ));
    } catch (e) {
      debugPrint("Gagal menginisialisasi listener TugasSelesai: $e");
      return null;
    }
  }

  /// Stream mendengarkan event TugasDiedit dari Smart Contract
  Stream<FilterEvent>? dengarkanTugasDiedit() {
    if (!_initialized || _contract == null) return null;
    try {
      final event = _contract!.event('TugasDiedit');
      return _client.events(FilterOptions.events(
        contract: _contract!,
        event: event,
      ));
    } catch (e) {
      debugPrint("Gagal menginisialisasi listener TugasDiedit: $e");
      return null;
    }
  }

  /// Stream mendengarkan event TugasDihapus dari Smart Contract
  Stream<FilterEvent>? dengarkanTugasDihapus() {
    if (!_initialized || _contract == null) return null;
    try {
      final event = _contract!.event('TugasDihapus');
      return _client.events(FilterOptions.events(
        contract: _contract!,
        event: event,
      ));
    } catch (e) {
      debugPrint("Gagal menginisialisasi listener TugasDihapus: $e");
      return null;
    }
  }

  Future<void> dispose() async {
    await _client.dispose();
    _httpClient?.close();
  }

  static const String _fallbackAbi = '''[
    {"inputs":[{"internalType":"string","name":"_judul","type":"string"}],"name":"tambahTugas","outputs":[],"stateMutability":"nonpayable","type":"function"},
    {"inputs":[{"internalType":"uint256","name":"_id","type":"uint256"}],"name":"tandaiSelesai","outputs":[],"stateMutability":"nonpayable","type":"function"},
    {"inputs":[{"internalType":"uint256","name":"_id","type":"uint256"},{"internalType":"string","name":"_judulBaru","type":"string"}],"name":"editTugas","outputs":[],"stateMutability":"nonpayable","type":"function"},
    {"inputs":[{"internalType":"uint256","name":"_id","type":"uint256"}],"name":"hapusTugas","outputs":[],"stateMutability":"nonpayable","type":"function"},
    {"anonymous":false,"inputs":[{"indexed":true,"internalType":"uint256","name":"id","type":"uint256"},{"indexed":false,"internalType":"string","name":"judul","type":"string"},{"indexed":true,"internalType":"address","name":"pembuat","type":"address"}],"name":"TugasBaru","type":"event"},
    {"anonymous":false,"inputs":[{"indexed":true,"internalType":"uint256","name":"id","type":"uint256"}],"name":"TugasSelesai","type":"event"},
    {"anonymous":false,"inputs":[{"indexed":true,"internalType":"uint256","name":"id","type":"uint256"},{"indexed":false,"internalType":"string","name":"judulBaru","type":"string"}],"name":"TugasDiedit","type":"event"},
    {"anonymous":false,"inputs":[{"indexed":true,"internalType":"uint256","name":"id","type":"uint256"}],"name":"TugasDihapus","type":"event"},
    {"inputs":[{"internalType":"uint256","name":"_id","type":"uint256"}],"name":"ambilTugas","outputs":[{"internalType":"string","name":"judul","type":"string"},{"internalType":"bool","name":"selesai","type":"bool"},{"internalType":"uint256","name":"waktuDibuat","type":"uint256"},{"internalType":"address","name":"pembuat","type":"address"},{"internalType":"bool","name":"aktif","type":"bool"}],"stateMutability":"view","type":"function"},
    {"inputs":[],"name":"jumlahTugas","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"}
  ]''';
}
