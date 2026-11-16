import 'package:flutter/material.dart';

import '../blockchain/blockchain_service.dart';
import '../blockchain/contract_config.dart';
import '../widgets/transaction_status.dart';

class AddTaskPage extends StatefulWidget {
  final String? currentWalletAddress;

  const AddTaskPage({
    super.key,
    this.currentWalletAddress,
  });

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  final _formKey = GlobalKey<FormState>();
  final _judulController = TextEditingController();
  final BlockchainService _service = BlockchainService();

  bool _isSubmitting = false;
  String? _txHash;

  @override
  void dispose() {
    _judulController.dispose();
    super.dispose();
  }

  Future<void> _submitTugas() async {
    if (!_formKey.currentState!.validate()) return;

    final judul = _judulController.text.trim();
    final isConnected = _service.isWalletConnected;
    final pKey = await _service.getSavedPrivateKey();

    if (!mounted) return;

    if (!isConnected && (pKey == null || pKey.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Belum terhubung ke MetaMask! Silakan hubungkan dompet terlebih dahulu.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    TransactionStatusDialog.showProcessing(
      context,
      title: isConnected ? 'Menyiapkan ke MetaMask...' : 'Menambahkan Tugas ke Blockchain...',
    );

    try {
      final tx = await _service.tambahTugas(judul);

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Tutup loading

      if (tx == 'METAMASK_APPROVAL_REQUESTED' || tx == 'WC_PENDING_CONFIRMATION') {
        TransactionStatusDialog.showWalletConnectPrompt(
          context,
          functionName: 'tambahTugas("$judul")',
          onConfirmDone: () {
            if (mounted) {
              Navigator.of(context).pop(true); // Kembali ke halaman utama dengan tanda refresh
            }
          },
        );
      } else {
        setState(() {
          _txHash = tx;
        });

        TransactionStatusDialog.showSuccess(
          context,
          txHash: tx,
          title: 'Tugas Berhasil Ditambahkan!',
          onDismiss: () {
            if (mounted) {
              Navigator.of(context).pop(true);
            }
          },
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Tutup loading

      TransactionStatusDialog.showError(
        context,
        error: e.toString(),
        title: 'Gagal Menambah Tugas',
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _service.isWalletConnected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Tugas Baru'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isConnected ? Colors.green.shade50 : Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isConnected ? Colors.green.shade300 : Colors.indigo.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isConnected ? Icons.shield : Icons.hub,
                          color: isConnected ? Colors.green.shade800 : Colors.indigo.shade800,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isConnected
                                ? 'Metode: MetaMask Approval (Reown/WalletConnect)'
                                : 'Mencatat ke Smart Contract',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isConnected ? Colors.green.shade900 : Colors.indigo.shade900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isConnected
                          ? 'Private key TIDAK PERNAH berada di aplikasi. Transaksi akan dibuka dan dikonfirmasi langsung di dompet MetaMask Anda.'
                          : 'Tugas akan dicatat langsung di Sepolia Testnet. Data disimpan permanen di blockchain dan memerlukan gas fee Sepolia ETH.',
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Wallet Pengirim:',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        Text(
                          widget.currentWalletAddress != null
                              ? ContractConfig.getShortAddress(widget.currentWalletAddress!)
                              : 'Belum terhubung',
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Form Input Judul
              const Text(
                'Judul Tugas (string judul)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _judulController,
                maxLength: 100,
                decoration: InputDecoration(
                  hintText: 'Contoh: Selesaikan modul Praktikum Blockchain',
                  prefixIcon: const Icon(Icons.assignment),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Judul tidak boleh kosong (sesuai smart contract)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Info Transaksi jika sudah ada TX Hash
              if (_txHash != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Transaksi Terakhir:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _txHash!,
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Tombol Submit
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF6851B), // Warna MetaMask
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _isSubmitting
                        ? 'Memproses...'
                        : (isConnected ? 'Kirim via MetaMask Approval' : 'Kirim Transaksi (tambahTugas)'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _isSubmitting ? null : _submitTugas,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
