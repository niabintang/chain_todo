import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../blockchain/blockchain_service.dart';
import '../models/tugas_model.dart';
import '../widgets/transaction_status.dart';

class DetailTugasPage extends StatefulWidget {
  final TugasModel tugas;
  final String? currentWalletAddress;

  const DetailTugasPage({
    super.key,
    required this.tugas,
    this.currentWalletAddress,
  });

  @override
  State<DetailTugasPage> createState() => _DetailTugasPageState();
}

class _DetailTugasPageState extends State<DetailTugasPage> {
  final BlockchainService _service = BlockchainService();
  bool _isProcessing = false;
  late TugasModel _currentTugas;

  @override
  void initState() {
    super.initState();
    _currentTugas = widget.tugas;
  }

  Future<void> _editTugas() async {
    final controller = TextEditingController(text: _currentTugas.judul);
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
              const Text(
                'Perubahan judul akan disimpan ke smart contract di Ethereum Sepolia melalui konfirmasi MetaMask.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
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

    if (newTitle == null || newTitle == _currentTugas.judul) return;

    setState(() => _isProcessing = true);
    if (!mounted) return;
    TransactionStatusDialog.showProcessing(context, title: 'Menyimpan Perubahan Judul...');

    try {
      final txHash = await _service.editTugas(_currentTugas.id, newTitle);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Tutup dialog loading

      TransactionStatusDialog.showSuccess(
        context,
        txHash: txHash,
        title: 'Judul Berhasil Diperbarui!',
      );

      setState(() {
        _currentTugas = TugasModel(
          id: _currentTugas.id,
          judul: newTitle,
          selesai: _currentTugas.selesai,
          dibuat: _currentTugas.dibuat,
          pembuat: _currentTugas.pembuat,
          aktif: _currentTugas.aktif,
        );
      });
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      TransactionStatusDialog.showError(
        context,
        error: e.toString(),
        title: 'Gagal Mengubah Judul',
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _hapusTugas() async {
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
        content: const Text(
          'Tindakan ini akan menonaktifkan tugas dari smart contract di Sepolia. Hanya pembuat tugas yang dapat menghapus.\n\n'
          'Apakah Anda yakin ingin melanjutkan transaksi via MetaMask?',
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

    setState(() => _isProcessing = true);
    if (!mounted) return;
    TransactionStatusDialog.showProcessing(context, title: 'Menghapus Tugas di Blockchain...');

    try {
      final txHash = await _service.hapusTugas(_currentTugas.id);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Tutup dialog loading

      TransactionStatusDialog.showSuccess(
        context,
        txHash: txHash,
        title: 'Tugas Berhasil Dihapus!',
        onDismiss: () {
          if (mounted) {
            Navigator.pop(context, true); // Kembali ke HomePage
          }
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
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _tandaiSelesai() async {
    final isOwner = widget.currentWalletAddress != null &&
        _currentTugas.isOwner(widget.currentWalletAddress!);

    if (!isOwner) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Peringatan Smart Contract'),
          content: const Text(
            'Smart contract ChainTodo hanya mengizinkan pembuat tugas yang dapat menandai tugas selesai '
            '(require: msg.sender == pembuat).\n\n'
            'Pastikan wallet aktif Anda sama dengan alamat pembuat tugas.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    TransactionStatusDialog.showProcessing(context, title: 'Menandai Tugas Selesai...');

    try {
      final txHash = await _service.tandaiSelesai(_currentTugas.id);
      
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Tutup loading

      if (txHash == 'METAMASK_APPROVAL_REQUESTED' || txHash == 'WC_PENDING_CONFIRMATION') {
        TransactionStatusDialog.showWalletConnectPrompt(
          context,
          functionName: 'tandaiSelesai(#${_currentTugas.id})',
          onConfirmDone: () {
            setState(() {
              _currentTugas = TugasModel(
                id: _currentTugas.id,
                judul: _currentTugas.judul,
                selesai: true,
                dibuat: _currentTugas.dibuat,
                pembuat: _currentTugas.pembuat,
                aktif: _currentTugas.aktif,
              );
            });
          },
        );
      } else {
        TransactionStatusDialog.showSuccess(
          context,
          txHash: txHash,
          title: 'Tugas Berhasil Diselesaikan!',
        );

        setState(() {
          _currentTugas = TugasModel(
            id: _currentTugas.id,
            judul: _currentTugas.judul,
            selesai: true,
            dibuat: _currentTugas.dibuat,
            pembuat: _currentTugas.pembuat,
            aktif: _currentTugas.aktif,
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Tutup loading
      TransactionStatusDialog.showError(
        context,
        error: e.toString(),
        title: 'Gagal Menyelesaikan Tugas',
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = widget.currentWalletAddress != null &&
        _currentTugas.isOwner(widget.currentWalletAddress!);

    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Tugas #${_currentTugas.id}'),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          if (isOwner) ...[
            IconButton(
              icon: const Icon(Icons.edit_note),
              tooltip: 'Edit Judul Tugas',
              onPressed: _isProcessing ? null : _editTugas,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Hapus Tugas',
              onPressed: _isProcessing ? null : _hapusTugas,
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _currentTugas.selesai
                    ? Colors.green.shade50
                    : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _currentTugas.selesai
                      ? Colors.green.shade300
                      : Colors.amber.shade400,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _currentTugas.selesai ? Icons.check_circle : Icons.pending_actions,
                    color: _currentTugas.selesai
                        ? Colors.green.shade700
                        : Colors.amber.shade800,
                    size: 32,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentTugas.selesai ? 'Tugas Selesai' : 'Tugas Belum Selesai',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _currentTugas.selesai
                                ? Colors.green.shade900
                                : Colors.amber.shade900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _currentTugas.selesai
                              ? 'Tercatat permanen di blockchain Sepolia'
                              : 'Menunggu konfirmasi penyelesaian oleh pembuat',
                          style: TextStyle(
                            fontSize: 12,
                            color: _currentTugas.selesai
                                ? Colors.green.shade800
                                : Colors.amber.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Judul Tugas
            const Text(
              'Judul Tugas',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 6),
            Card(
              elevation: 0,
              color: Colors.grey.shade100,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _currentTugas.judul,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    decoration: _currentTugas.selesai ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Informasi Metadata On-Chain
            const Text(
              'Informasi On-Chain (Smart Contract)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    label: 'ID Tugas',
                    value: '#${_currentTugas.id}',
                  ),
                  const Divider(height: 20),
                  _buildDetailRow(
                    label: 'Waktu Dibuat (Timestamp)',
                    value: '${_currentTugas.formattedDate} (${_currentTugas.dibuat})',
                  ),
                  const Divider(height: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Alamat Pembuat (Wallet):',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          if (isOwner)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Wallet Anda',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.purple,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        _currentTugas.pembuat,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              textStyle: const TextStyle(fontSize: 11),
                            ),
                            icon: const Icon(Icons.copy, size: 14),
                            label: const Text('Salin Address'),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _currentTugas.pembuat));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Alamat pembuat disalin')),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              textStyle: const TextStyle(fontSize: 11),
                            ),
                            icon: const Icon(Icons.open_in_new, size: 14),
                            label: const Text('Etherscan'),
                            onPressed: () async {
                              final url = _service.getAddressExplorerUrl(_currentTugas.pembuat);
                              final uri = Uri.parse(url);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else {
                                Clipboard.setData(ClipboardData(text: url));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Link profil pembuat disalin:\n$url')),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Tombol Selesaikan Tugas
            if (!_currentTugas.selesai) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle),
                  label: Text(
                    _isProcessing ? 'Mengirim Transaksi...' : 'Tandai Selesai di Blockchain',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _isProcessing ? null : _tandaiSelesai,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({required String label, required String value}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
