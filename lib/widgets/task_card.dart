import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../blockchain/contract_config.dart';
import '../models/tugas_model.dart';

class TaskCard extends StatelessWidget {
  final TugasModel tugas;
  final String? currentWalletAddress;
  final VoidCallback? onTandaiSelesai;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onHapus;
  final bool isMarking;

  const TaskCard({
    super.key,
    required this.tugas,
    this.currentWalletAddress,
    this.onTandaiSelesai,
    this.onTap,
    this.onEdit,
    this.onHapus,
    this.isMarking = false,
  });

  @override
  Widget build(BuildContext context) {
    final isOwner = currentWalletAddress != null && tugas.isOwner(currentWalletAddress!);

    return Card(
      elevation: tugas.selesai ? 1 : 2.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: tugas.selesai
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.indigo.withValues(alpha: 0.15),
          width: 1.2,
        ),
      ),
      color: tugas.selesai ? Colors.grey.shade50 : Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card: Badge ID, Status & Badge Kepemilikan
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.indigo.shade200),
                        ),
                        child: Text(
                          '#${tugas.id}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: tugas.selesai ? Colors.green.shade50 : Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: tugas.selesai ? Colors.green.shade300 : Colors.amber.shade400,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              tugas.selesai ? Icons.check_circle : Icons.schedule,
                              size: 14,
                              color: tugas.selesai ? Colors.green.shade700 : Colors.amber.shade800,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              tugas.selesai ? 'Selesai' : 'Belum Selesai',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: tugas.selesai ? Colors.green.shade800 : Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (isOwner)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.purple.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person, size: 12, color: Colors.purple.shade700),
                              const SizedBox(width: 3),
                              Text(
                                'Milik Saya',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (onEdit != null) ...[
                          const SizedBox(width: 4),
                          Tooltip(
                            message: 'Edit Judul Tugas',
                            child: InkWell(
                              onTap: onEdit,
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.all(3.0),
                                child: Icon(Icons.edit_note, size: 20, color: Colors.blue.shade700),
                              ),
                            ),
                          ),
                        ],
                        if (onHapus != null) ...[
                          const SizedBox(width: 2),
                          Tooltip(
                            message: 'Hapus Tugas (On-Chain)',
                            child: InkWell(
                              onTap: onHapus,
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.all(3.0),
                                child: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade600),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Judul Tugas
              Text(
                tugas.judul,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  decoration: tugas.selesai ? TextDecoration.lineThrough : null,
                  color: tugas.selesai ? Colors.grey.shade600 : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              const Divider(height: 1),
              const SizedBox(height: 10),

              // Metadata footer: Waktu & Pembuat
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    tugas.formattedDate,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: tugas.pembuat));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Alamat pembuat disalin: ${tugas.pembuat}'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        children: [
                          Icon(Icons.wallet, size: 13, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            ContractConfig.getShortAddress(tugas.pembuat),
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.copy, size: 11, color: Colors.grey.shade400),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Tombol Tandai Selesai jika belum selesai
              if (!tugas.selesai) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: isMarking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(
                      isMarking ? 'Memproses Transaksi...' : 'Tandai Selesai On-Chain',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    onPressed: isMarking ? null : onTandaiSelesai,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
