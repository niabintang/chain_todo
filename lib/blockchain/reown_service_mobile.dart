import 'dart:async';
import 'package:flutter/material.dart';
import 'package:reown_appkit/reown_appkit.dart';

import 'contract_config.dart';

/// Implementasi Reown AppKit / WalletConnect khusus platform native (Android / iOS).
/// Terhubung langsung dengan MetaMask Mobile via deep-link `chaintodo://` dan `io.metamask`.
class ReownService with ChangeNotifier {
  static final ReownService _instance = ReownService._internal();
  factory ReownService() => _instance;
  ReownService._internal();

  ReownAppKitModal? _appKitModal;
  bool _initialized = false;
  bool _initializing = false;

  ReownAppKitModal? get appKitModal => _appKitModal;
  bool get isInitialized => _initialized;
  bool get isConnected => _appKitModal?.isConnected ?? false;

  String? get walletAddress {
    if (!isConnected || _appKitModal?.session == null) return null;
    return _appKitModal!.session!.getAddress('eip155');
  }

  int get currentChainId {
    final chainIdStr = _appKitModal?.selectedChain?.chainId;
    if (chainIdStr != null) {
      final parsed = int.tryParse(chainIdStr.replaceAll('eip155:', ''));
      if (parsed != null) return parsed;
    }
    return ContractConfig.chainId;
  }

  bool get isSepoliaNetwork => currentChainId == ContractConfig.chainId;

  Future<void> init(BuildContext context) async {
    if (_initialized || _initializing) return;
    _initializing = true;

    try {
      final projectId = ContractConfig.reownProjectId;
      if (projectId.isEmpty) {
        debugPrint('[ReownService] Warning: REOWN_PROJECT_ID belum dikonfigurasi di .env atau --dart-define.');
        return;
      }

      // Pastikan Sepolia terdaftar dalam network yang didukung
      ReownAppKitModalNetworks.addSupportedNetworks('eip155', [
        ReownAppKitModalNetworkInfo(
          name: 'Sepolia',
          chainId: '11155111',
          currency: 'SEP',
          rpcUrl: ContractConfig.rpcUrl.isNotEmpty
              ? ContractConfig.rpcUrl
              : 'https://rpc.walletconnect.org/v1',
          explorerUrl: ContractConfig.explorerUrl,
          isTestNetwork: true,
        ),
      ]);

      _appKitModal = ReownAppKitModal(
        context: context,
        projectId: ContractConfig.reownProjectId,
        metadata: PairingMetadata(
          name: 'ChainTodo',
          description: 'Aplikasi Todo List Blockchain Ethereum Sepolia',
          url: 'https://chaintodo.app',
          icons: const [
            'https://raw.githubusercontent.com/reown-com/reown_flutter/refs/heads/develop/assets/appkit_logo.png',
          ],
          redirect: Redirect(
            native: 'chaintodo://',
            universal: 'https://chaintodo.app',
          ),
        ),
        featuredWalletIds: {
          // ID resmi MetaMask pada WalletConnect Explorer
          'c57ca95b47569778a828d19178114f4db188b89b763c899ba0be274e97267d96',
        },
        optionalNamespaces: {
          'eip155': RequiredNamespace(
            chains: ['eip155:11155111'],
            methods: [
              'eth_sendTransaction',
              'personal_sign',
              'eth_signTypedData',
              'eth_accounts',
              'eth_requestAccounts',
            ],
            events: ['chainChanged', 'accountsChanged'],
          ),
        },
      );

      await _appKitModal!.init();

      // Dengarkan event koneksi, disconnect, dan perpindahan jaringan
      _appKitModal!.onModalConnect.subscribe((event) {
        notifyListeners();
      });

      _appKitModal!.onModalDisconnect.subscribe((event) {
        notifyListeners();
      });

      _appKitModal!.onModalUpdate.subscribe((event) {
        notifyListeners();
      });

      _appKitModal!.onModalNetworkChange.subscribe((event) {
        notifyListeners();
      });

      _initialized = true;
    } catch (e) {
      debugPrint('[ReownService] Error inisialisasi AppKit: $e');
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> openModal(BuildContext context) async {
    if (!_initialized || _appKitModal == null) {
      await init(context);
    }
    if (_appKitModal != null) {
      await _appKitModal!.openModalView();
    }
  }

  Future<void> disconnect() async {
    if (_appKitModal != null) {
      await _appKitModal!.disconnect();
      notifyListeners();
    }
  }

  /// Mengirim transaksi ke smart contract melalui sesi MetaMask Mobile yang aktif
  Future<String> sendContractTransaction({
    required DeployedContract contract,
    required String functionName,
    required List<dynamic> parameters,
  }) async {
    if (!isConnected || _appKitModal == null || _appKitModal!.session == null) {
      throw Exception(
        'Wallet MetaMask belum terhubung! Silakan hubungkan dompet terlebih dahulu.',
      );
    }

    final senderAddress = walletAddress;
    if (senderAddress == null) {
      throw Exception(
        'Alamat wallet pengguna tidak ditemukan pada sesi Reown AppKit.',
      );
    }

    final topic = _appKitModal!.session!.topic;

    final response = await _appKitModal!.requestWriteContract(
      topic: topic,
      chainId: 'eip155:11155111',
      deployedContract: contract,
      functionName: functionName,
      transaction: Transaction(
        from: EthereumAddress.fromHex(senderAddress),
      ),
      parameters: parameters,
    );

    if (response == null) {
      throw Exception(
        'Permintaan transaksi dibatalkan atau tidak menerima respons dari MetaMask.',
      );
    }

    return response.toString();
  }
}

