class TugasModel {
  final int id;
  final String judul;
  final bool selesai;
  final int dibuat;
  final String pembuat;
  final bool aktif;

  TugasModel({
    required this.id,
    required this.judul,
    required this.selesai,
    required this.dibuat,
    required this.pembuat,
    this.aktif = true,
  });

  DateTime get tanggalDibuat =>
      DateTime.fromMillisecondsSinceEpoch(dibuat * 1000);

  String get formattedDate {
    final dt = tanggalDibuat.toLocal();
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  String get shortPembuat {
    if (pembuat.length <= 12) return pembuat;
    return '${pembuat.substring(0, 6)}...${pembuat.substring(pembuat.length - 4)}';
  }

  bool isOwner(String currentAddress) {
    if (currentAddress.isEmpty) return false;
    return pembuat.toLowerCase() == currentAddress.toLowerCase();
  }
}
