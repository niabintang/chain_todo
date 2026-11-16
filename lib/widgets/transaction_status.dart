import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../blockchain/blockchain_service.dart';
import '../blockchain/walletconnect_service.dart';

enum TxState { idle, processing, walletConnectPrompt, success, error }

class TransactionStatusDialog extends StatelessWidget {
  final TxState state;
  final String? txHash;
  final String? errorMessage;
  final String title;
  final VoidCallback? onDismiss;
  final VoidCallback? onRefresh;

  const TransactionStatusDialog({
    super.key,
    required this.state,
    this.txHash,
    this.errorMessage,
    this.title = 'Status Transaksi Blockchain',
    this.onDismiss,
    this.onRefresh,
  });

  static void showProcessing(BuildContext context, {String title = 'Mengirim Transaksi...'}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: TransactionStatusDialog(
          state: TxState.processing,
          title: title,
        ),
      ),
    );
  }

  static void showWalletConnectPrompt(
    BuildContext context, {
    required String functionName,
    VoidCallback? onConfirmDone,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => TransactionStatusDialog(
        state: TxState.walletConnectPrompt,
        title: 'Konfirmasi di MetaMask (Reown)',
        errorMessage: functionName,
        onDismiss: onConfirmDone,
      ),
    );
  }

  static void showSuccess(
    BuildContext context, {
    required String txHash,
    String title = 'Transaksi Berhasil!',
    VoidCallback? onDismiss,
  }) {
    showDialog(
      context: context,
      builder: (_) => TransactionStatusDialog(
        state: TxState.success,
        txHash: txHash,
        title: title,
        onDismiss: onDismiss,
      ),
    );
  }

  static void showError(
    BuildContext context, {
    required String error,
    String title = 'Transaksi Gagal',
    VoidCallback? onDismiss,
  }) {
    showDialog(
      context: context,
      builder: (_) => TransactionStatusDialog(
        state: TxState.error,
        errorMessage: error,
        title: title,
        onDismiss: onDismiss,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      title: Row(
        children: [
          _buildIcon(),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state == TxState.processing) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(),
                ),
              ),
              const Center(
                child: Text(
                  'Sedang memproses transaksi di jaringan Sepolia...\nHarap tunggu konfirmasi block.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ] else if (state == TxState.walletConnectPrompt) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.indigo.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield, color: Colors.indigo, size: 24),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Private key TIDAK PERNAH berada di aplikasi. Transaksi ditandatangani langsung di dompet MetaMask Anda.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.indigo),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Permintaan transaksi telah dikirim ke dompet MetaMask Anda. Silakan buka MetaMask untuk meninjau gas fee dan menyetujui (Approve) transaksi on-chain.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Buka Aplikasi MetaMask'),
                  onPressed: () {
                    WalletConnectService().launchMetaMaskApp();
                  },
                ),
              ),
            ] else if (state == TxState.success && txHash != null) ...[
              const Text(
                'Data berhasil dicatat ke dalam smart contract on-chain.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hash Transaksi (TX Hash):',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      txHash!,
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Salin Hash'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: txHash!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Hash transaksi disalin ke clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Etherscan'),
                      onPressed: () async {
                        final url = BlockchainService().getTxExplorerUrl(txHash!);
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          Clipboard.setData(ClipboardData(text: url));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Link Etherscan disalin:\n$url')),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ] else if (state == TxState.error) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pesan Kesalahan:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      errorMessage ?? 'Terjadi kesalahan saat memproses transaksi.',
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Pastikan:\n'
                '1. Sepolia ETH cukup untuk gas fee di dompet Anda\n'
                '2. Dompet terhubung dengan benar ke jaringan Sepolia\n'
                '3. Hanya pembuat tugas yang dapat menandai tugas selesai',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (state != TxState.processing)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (onDismiss != null) onDismiss!();
            },
            child: Text(state == TxState.walletConnectPrompt ? 'Sudah Konfirmasi (Selesai)' : 'Tutup'),
          ),
      ],
    );
  }

  Widget _buildIcon() {
    switch (state) {
      case TxState.processing:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 3),
        );
      case TxState.walletConnectPrompt:
        return const Icon(Icons.link, color: Colors.indigo, size: 28);
      case TxState.success:
        return const Icon(Icons.check_circle, color: Colors.green, size: 28);
      case TxState.error:
        return const Icon(Icons.error, color: Colors.red, size: 28);
      case TxState.idle:
        return const Icon(Icons.info_outline, color: Colors.blue, size: 28);
    }
  }
}
