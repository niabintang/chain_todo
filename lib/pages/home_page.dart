import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web3dart/web3dart.dart';

import '../blockchain/blockchain_service.dart';
import '../blockchain/contract_config.dart';
import '../blockchain/reown_service.dart';
import '../controllers/wallet_controller.dart';
import '../models/tugas_model.dart';
import '../widgets/task_card.dart';
import '../widgets/transaction_status.dart';
import '../widgets/wallet_connect_dialog.dart';
import 'add_task_page.dart';
import 'detail_tugas.dart';

enum TaskFilter { semua, belumSelesai, selesai, milikSaya }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final BlockchainService _service = BlockchainService();
  final WalletController _walletController = WalletController();

  List<TugasModel> _daftarTugas = [];
  bool _isLoading = true;
  String? _errorMessage;
  int? _markingTaskId;

  TaskFilter _selectedFilter = TaskFilter.semua;

  // Stream subscription untuk Fitur Bonus: Event Listener Smart Contract
  StreamSubscription<FilterEvent>? _subTugasBaru;
  StreamSubscription<FilterEvent>? _subTugasSelesai;
  StreamSubscription<FilterEvent>? _subTugasDiedit;
  StreamSubscription<FilterEvent>? _subTugasDihapus;
  Timer? _periodicRefreshTimer;

  @override
  void initState() {
    super.initState();
    _walletController.addListener(_onWalletChanged);
    _initAndLoad();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!kIsWeb) {
      _walletController.initReown(context);
    }
  }

  @override
  void dispose() {
    _subTugasBaru?.cancel();
    _subTugasSelesai?.cancel();
    _subTugasDiedit?.cancel();
    _subTugasDihapus?.cancel();
    _periodicRefreshTimer?.cancel();
    _walletController.removeListener(_onWalletChanged);
    super.dispose();
  }

  void _onWalletChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initAndLoad() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _walletController.init();
      await _service.init();
      await _fetchTugas();

      // Mulai mendengarkan event blockchain & auto-refresh (Fitur Bonus)
      _startEventListener();
      _startPeriodicRefresh();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Fitur Bonus 1: Mendengarkan Event TugasBaru & TugasSelesai secara Real-time
  void _startEventListener() {
    _subTugasBaru?.cancel();
    _subTugasSelesai?.cancel();

    // 1. Dengarkan event TugasBaru
    final streamTugasBaru = _service.dengarkanTugasBaru();
    if (streamTugasBaru != null) {
      _subTugasBaru = streamTugasBaru.listen(
        (filterEvent) {
          debugPrint('🔔 [Event Blockchain] Terdeteksi TugasBaru!');
          if (mounted) {
            _showEventNotification(
              'Tugas baru ditambahkan ke smart contract! Memperbarui...',
              Icons.playlist_add_check_circle,
              Colors.greenAccent,
            );
            _fetchTugas(silent: true);
          }
        },
        onError: (err) {
          debugPrint('Info event listener TugasBaru: $err');
        },
      );
    }

    // 2. Dengarkan event TugasSelesai
    final streamTugasSelesai = _service.dengarkanTugasSelesai();
    if (streamTugasSelesai != null) {
      _subTugasSelesai = streamTugasSelesai.listen(
        (filterEvent) {
          debugPrint('🔔 [Event Blockchain] Terdeteksi TugasSelesai!');
          if (mounted) {
            _showEventNotification(
              'Status tugas diselesaikan di blockchain! Memperbarui...',
              Icons.check_circle_outline,
              Colors.lightBlueAccent,
            );
            _fetchTugas(silent: true);
          }
        },
        onError: (err) {
          debugPrint('Info event listener TugasSelesai: $err');
        },
      );
    }

    // 3. Dengarkan event TugasDiedit (Fitur Bonus 2)
    final streamTugasDiedit = _service.dengarkanTugasDiedit();
    if (streamTugasDiedit != null) {
      _subTugasDiedit = streamTugasDiedit.listen(
        (filterEvent) {
          debugPrint('🔔 [Event Blockchain] Terdeteksi TugasDiedit!');
          if (mounted) {
            _showEventNotification(
              'Judul tugas diperbarui di blockchain! Memperbarui...',
              Icons.edit_note,
              Colors.amberAccent,
            );
            _fetchTugas(silent: true);
          }
        },
        onError: (err) {
          debugPrint('Info event listener TugasDiedit: $err');
        },
      );
    }

    // 4. Dengarkan event TugasDihapus (Fitur Bonus 2)
    final streamTugasDihapus = _service.dengarkanTugasDihapus();
    if (streamTugasDihapus != null) {
      _subTugasDihapus = streamTugasDihapus.listen(
        (filterEvent) {
          debugPrint('🔔 [Event Blockchain] Terdeteksi TugasDihapus!');
          if (mounted) {
            _showEventNotification(
              'Tugas telah dinonaktifkan di blockchain! Memperbarui...',
              Icons.delete_sweep_outlined,
              Colors.redAccent,
            );
            _fetchTugas(silent: true);
          }
        },
        onError: (err) {
          debugPrint('Info event listener TugasDihapus: $err');
        },
      );
    }
  }

  /// Auto refresh berkala setiap 30 detik sebagai pelengkap keandalan sinkronisasi
  void _startPeriodicRefresh() {
    _periodicRefreshTimer?.cancel();
    _periodicRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !_isLoading) {
        _fetchTugas(silent: true);
      }
    });
  }

  void _showEventNotification(String pesan, IconData icon, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                pesan,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _fetchTugas({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final tasks = await _service.getAllTugas();
      if (mounted) {
        setState(() {
          _daftarTugas = tasks;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Tombol Connect Wallet utama: langsung memicu popup MetaMask Extension di Flutter Web
  Future<void> _handleConnectWallet() async {
    if (kIsWeb) {
      // 1. Cek apakah extension MetaMask terdeteksi di Google Chrome
      if (!_walletController.isMetaMaskInstalled) {
        _showMetaMaskNotDetectedDialog();
        return;
      }

      // 2. Langsung panggil MetaMask extension (EIP-1193 eth_requestAccounts)
      try {
        await _walletController.connectMetaMaskExtension();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Wallet Connected! Berhasil terhubung ke MetaMask Extension.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          _fetchTugas();
        }
      } catch (e) {
        if (!mounted) return;
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } else {
      // Di platform Android: buka modal Reown AppKit resmi yang menargetkan MetaMask Mobile
      try {
        await ReownService().openModal(context);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka modal wallet: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _showMetaMaskNotDetectedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text('MetaMask Tidak Terdeteksi'),
          ],
        ),
        content: const Text(
          'MetaMask Extension tidak terdeteksi. Silakan aktifkan MetaMask pada Google Chrome, lalu refresh halaman ini.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF6851B), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _walletController.openMetaMaskWeb();
            },
            child: const Text('Buka Web MetaMask'),
          ),
        ],
      ),
    );
  }

  Future<void> _tandaiSelesai(TugasModel tugas) async {
    final currentWallet = _walletController.walletAddress;

    // Cek apakah wallet sudah terhubung
    if (!_walletController.isConnected || currentWallet == null) {
      _showConnectPrompt();
      return;
    }

    // Cek apakah jaringan benar di Sepolia
    if (!_walletController.isSepoliaNetwork) {
      _showNetworkMismatchDialog();
      return;
    }

    // Validasi apakah user adalah pembuat tugas
    if (!tugas.isOwner(currentWallet)) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Bukan Pembuat Tugas'),
          content: Text(
            'Smart contract menolak transaksi jika bukan pembuat tugas yang memanggil tandaiSelesai.\n\n'
            'Pembuat: ${tugas.pembuat}\n'
            'Wallet Anda: $currentWallet',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _markingTaskId = tugas.id);
    TransactionStatusDialog.showProcessing(
      context,
      title: 'Menandai Tugas #${tugas.id} Selesai...',
    );

    try {
      final txHash = await _service.tandaiSelesai(tugas.id);

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Tutup dialog processing

      if (txHash == 'METAMASK_APPROVAL_REQUESTED' || txHash == 'WC_PENDING_CONFIRMATION') {
        TransactionStatusDialog.showWalletConnectPrompt(
          context,
          functionName: 'tandaiSelesai(#${tugas.id})',
          onConfirmDone: () {
            _fetchTugas();
            _walletController.refreshBalance();
          },
        );
      } else {
        TransactionStatusDialog.showSuccess(
          context,
          txHash: txHash,
          title: 'Tugas #${tugas.id} Ditandai Selesai!',
          onDismiss: () {
            _fetchTugas();
            _walletController.refreshBalance();
          },
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Tutup dialog processing

      TransactionStatusDialog.showError(
        context,
        error: e.toString(),
        title: 'Gagal Menandai Selesai',
      );
    } finally {
      if (mounted) {
        setState(() => _markingTaskId = null);
      }
    }
  }

  // --- Fitur Bonus 2: Edit & Hapus Tugas di Smart Contract ---

  Future<void> _handleEditTugas(TugasModel tugas) async {
    final currentWallet = _walletController.walletAddress;

    if (!_walletController.isConnected || currentWallet == null) {
      _showConnectPrompt();
      return;
    }
    if (!_walletController.isSepoliaNetwork) {
      _showNetworkMismatchDialog();
      return;
    }
    if (!tugas.isOwner(currentWallet)) {
      _showNotOwnerDialog(tugas, 'mengedit');
      return;
    }

    final controller = TextEditingController(text: tugas.judul);
    final formKey = GlobalKey<FormState>();

    final String? newTitle = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit_note, color: Colors.blue),
            SizedBox(width: 8),
            Text('Edit Judul Tugas'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Perubahan judul tugas #${tugas.id} akan disimpan ke smart contract di Ethereum Sepolia melalui MetaMask.',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Judul Baru',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Judul tidak boleh kosong';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(dialogCtx, controller.text.trim());
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (newTitle == null || newTitle == tugas.judul) return;

    if (!mounted) return;
    TransactionStatusDialog.showProcessing(
      context,
      title: 'Menyimpan Perubahan Judul di Blockchain...',
    );

    try {
      final txHash = await _service.editTugas(tugas.id, newTitle);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      TransactionStatusDialog.showSuccess(
        context,
        txHash: txHash,
        title: 'Judul Tugas #${tugas.id} Berhasil Diperbarui!',
        onDismiss: () {
          _fetchTugas();
          _walletController.refreshBalance();
        },
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      TransactionStatusDialog.showError(
        context,
        error: e.toString(),
        title: 'Gagal Mengubah Judul',
      );
    }
  }

  Future<void> _handleHapusTugas(TugasModel tugas) async {
    final currentWallet = _walletController.walletAddress;

    if (!_walletController.isConnected || currentWallet == null) {
      _showConnectPrompt();
      return;
    }
    if (!_walletController.isSepoliaNetwork) {
      _showNetworkMismatchDialog();
      return;
    }
    if (!tugas.isOwner(currentWallet)) {
      _showNotOwnerDialog(tugas, 'menghapus');
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Hapus Tugas On-Chain?'),
          ],
        ),
        content: Text(
          'Tugas #${tugas.id} ("${tugas.judul}") akan dinonaktifkan dari smart contract di Sepolia Testnet.\n\n'
          'Tindakan ini memerlukan tanda tangan transaksi melalui MetaMask.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Ya, Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    TransactionStatusDialog.showProcessing(
      context,
      title: 'Menghapus Tugas #${tugas.id} dari Blockchain...',
    );

    try {
      final txHash = await _service.hapusTugas(tugas.id);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      TransactionStatusDialog.showSuccess(
        context,
        txHash: txHash,
        title: 'Tugas #${tugas.id} Berhasil Dihapus!',
        onDismiss: () {
          _fetchTugas();
          _walletController.refreshBalance();
        },
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      TransactionStatusDialog.showError(
        context,
        error: e.toString(),
        title: 'Gagal Menghapus Tugas',
      );
    }
  }

  void _showNotOwnerDialog(TugasModel tugas, String aksi) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Bukan Pembuat Tugas'),
        content: Text(
          'Smart contract hanya mengizinkan pembuat tugas yang dapat $aksi tugas ini (require: msg.sender == pembuat).\n\n'
          'Pembuat: ${tugas.pembuat}\n'
          'Wallet Anda: ${_walletController.walletAddress}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _showConnectPrompt() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Silakan hubungkan dompet MetaMask terlebih dahulu!'),
        backgroundColor: Colors.orange.shade800,
        action: SnackBarAction(
          label: 'Connect',
          textColor: Colors.white,
          onPressed: _handleConnectWallet,
        ),
      ),
    );
  }

  void _showNetworkMismatchDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Jaringan Salah'),
          ],
        ),
        content: const Text(
          'Aplikasi ChainTodo berjalan di jaringan Ethereum Sepolia Testnet (Chain ID: 11155111).\n\n'
          'Harap alihkan jaringan MetaMask Anda ke Sepolia untuk melakukan transaksi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await _walletController.switchNetworkToSepolia();
            },
            child: const Text('Pindah ke Sepolia'),
          ),
        ],
      ),
    );
  }

  List<TugasModel> get _filteredTugas {
    final currentAddress = _walletController.walletAddress;
    switch (_selectedFilter) {
      case TaskFilter.belumSelesai:
        return _daftarTugas.where((t) => !t.selesai).toList();
      case TaskFilter.selesai:
        return _daftarTugas.where((t) => t.selesai).toList();
      case TaskFilter.milikSaya:
        if (currentAddress == null) return [];
        return _daftarTugas.where((t) => t.isOwner(currentAddress)).toList();
      case TaskFilter.semua:
        return _daftarTugas;
    }
  }

  void _showWalletDialog() {
    WalletConnectDialog.show(
      context,
      onWalletUpdated: () {
        _initAndLoad();
      },
    );
  }

  void _showContractInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.description, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Info Kontrak On-Chain', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Network', '${ContractConfig.networkName} (Chain ID: ${ContractConfig.chainId})'),
            const SizedBox(height: 8),
            _buildInfoRow('Alamat Kontrak', ContractConfig.contractAddress),
            const SizedBox(height: 8),
            _buildInfoRow('RPC Endpoint', ContractConfig.maskedRpcUrl),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Buka Kontrak di Etherscan'),
              onPressed: () async {
                final url = _service.getAddressExplorerUrl(ContractConfig.contractAddress);
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  Clipboard.setData(ClipboardData(text: url));
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Link Etherscan disalin:\n$url')),
                    );
                  }
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
        SelectableText(value, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTugas;
    final totalCount = _daftarTugas.length;
    final selesaiCount = _daftarTugas.where((t) => t.selesai).length;
    final isConnected = _walletController.isConnected;
    final isSepolia = _walletController.isSepoliaNetwork;
    final isConnecting = _walletController.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ChainTodo',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isSepolia ? Colors.greenAccent : Colors.amberAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isSepolia ? 'Sepolia Testnet (11155111)' : 'Jaringan Salah',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Informasi Kontrak',
            icon: const Icon(Icons.info_outline),
            onPressed: _showContractInfoDialog,
          ),
          IconButton(
            tooltip: 'Muat Ulang Data (Refresh)',
            icon: const Icon(Icons.refresh),
            onPressed: _initAndLoad,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchTugas,
        child: Column(
          children: [
            // Status Bar Wallet Modern (Connected / Not Connected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: isConnected ? Colors.green.shade50 : Colors.indigo.shade50,
              child: Row(
                children: [
                  // Logo/Ikon MetaMask
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isConnected ? const Color(0xFFF6851B).withValues(alpha: 0.15) : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isConnected ? const Color(0xFFF6851B) : Colors.grey.shade300,
                      ),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet,
                      size: 20,
                      color: Color(0xFFF6851B), // Warna MetaMask
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Keterangan Status Wallet
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              isConnected ? 'Wallet Connected' : 'Wallet Not Connected',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isConnected ? Colors.green.shade900 : Colors.indigo.shade900,
                              ),
                            ),
                            if (isConnected && isSepolia) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Sepolia',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isConnected
                              ? '${_walletController.shortAddress} (${_walletController.balance.toStringAsFixed(3)} ETH)'
                              : (kIsWeb
                                  ? 'Koneksikan MetaMask Browser Extension untuk transaksi'
                                  : 'Koneksikan MetaMask Mobile via AppKit untuk transaksi'),
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: isConnected ? 'monospace' : null,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tombol Aksi (Connect / Disconnect)
                  if (!isConnected)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF6851B), // Warna resmi MetaMask
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 1,
                      ),
                      icon: isConnecting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.link, size: 16),
                      label: Text(
                        isConnecting ? 'Menghubungkan...' : 'Connect Wallet',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: isConnecting ? null : _handleConnectWallet,
                    )
                  else
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Opsi Koneksi Lanjutan',
                          icon: const Icon(Icons.settings, size: 18, color: Colors.indigo),
                          onPressed: _showWalletDialog,
                        ),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          onPressed: () async {
                            await _walletController.disconnect();
                            _initAndLoad();
                          },
                          child: const Text('Disconnect', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Peringatan jika terhubung tapi bukan di jaringan Sepolia
            if (isConnected && !isSepolia)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.amber.shade100,
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.amber, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Jaringan bukan Sepolia! Klik untuk beralih.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: _showNetworkMismatchDialog,
                      child: const Text('Pindah ke Sepolia', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

            // Filter Chips (Bonus: Filter semua, belum selesai, selesai, milik saya)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildFilterChip('Semua ($totalCount)', TaskFilter.semua),
                  const SizedBox(width: 8),
                  _buildFilterChip('Belum Selesai (${totalCount - selesaiCount})', TaskFilter.belumSelesai),
                  const SizedBox(width: 8),
                  _buildFilterChip('Selesai ($selesaiCount)', TaskFilter.selesai),
                  const SizedBox(width: 8),
                  _buildFilterChip('Milik Saya', TaskFilter.milikSaya),
                ],
              ),
            ),

            const Divider(height: 1),

            // Content List Tugas On-Chain
            Expanded(
              child: _buildBody(filtered),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Tugas'),
        onPressed: () async {
          if (!isConnected) {
            _showConnectPrompt();
            return;
          }
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddTaskPage(
                currentWalletAddress: _walletController.walletAddress,
              ),
            ),
          );
          if (result == true) {
            _fetchTugas();
            _walletController.refreshBalance();
          }
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, TaskFilter filter) {
    final isSelected = _selectedFilter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedFilter = filter);
        }
      },
      selectedColor: Colors.indigo.shade100,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.indigo.shade900 : Colors.black87,
      ),
    );
  }

  Widget _buildBody(List<TugasModel> filtered) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text(
              'Membaca data dari smart contract di Sepolia...',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              const Text(
                'Gagal Mengambil Data Smart Contract',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
                onPressed: _initAndLoad,
              ),
            ],
          ),
        ),
      );
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              _daftarTugas.isEmpty
                  ? 'Belum ada tugas di smart contract.'
                  : 'Tidak ada tugas yang sesuai filter.',
              style: const TextStyle(fontSize: 15, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            if (_daftarTugas.isEmpty)
              const Text(
                'Klik tombol "+ Tambah Tugas" untuk mencatat tugas baru ke Sepolia.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final tugas = filtered[index];
        return TaskCard(
          tugas: tugas,
          currentWalletAddress: _walletController.walletAddress,
          isMarking: _markingTaskId == tugas.id,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DetailTugasPage(
                  tugas: tugas,
                  currentWalletAddress: _walletController.walletAddress,
                ),
              ),
            ).then((_) {
              _fetchTugas();
              _walletController.refreshBalance();
            });
          },
          onTandaiSelesai: () => _tandaiSelesai(tugas),
          onEdit: () => _handleEditTugas(tugas),
          onHapus: () => _handleHapusTugas(tugas),
        );
      },
    );
  }
}
