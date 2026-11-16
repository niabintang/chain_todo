import 'package:flutter_dotenv/flutter_dotenv.dart';

class ContractConfig {
  static const int chainId = 11155111;
  static const String networkName = 'Sepolia Testnet';

  static String get rpcUrl =>
      dotenv.isInitialized ? (dotenv.env['RPC_URL']?.trim() ?? '') : '';

  static String get contractAddress =>
      dotenv.isInitialized ? (dotenv.env['CONTRACT_ADDRESS']?.trim() ?? '') : '';

  static String get explorerUrl =>
      dotenv.isInitialized
          ? (dotenv.env['EXPLORER_URL']?.trim() ?? 'https://sepolia.etherscan.io')
          : 'https://sepolia.etherscan.io';

  /// URL RPC dengan API Key yang disensor agar aman ditampilkan di layar aplikasi
  static String get maskedRpcUrl {
    final url = rpcUrl;
    if (url.isEmpty) return 'Belum dikonfigurasi';
    try {
      final uri = Uri.parse(url);
      final host = uri.host;
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        final last = pathSegments.last;
        final maskedKey = last.length > 8
            ? '${last.substring(0, 4)}••••${last.substring(last.length - 4)}'
            : '••••••••';
        final prefixPath = pathSegments.length > 1
            ? pathSegments.sublist(0, pathSegments.length - 1).join('/')
            : '';
        final pathString = prefixPath.isNotEmpty ? '$prefixPath/$maskedKey' : maskedKey;
        return '${uri.scheme}://$host/$pathString';
      }
      return '${uri.scheme}://$host';
    } catch (_) {
      return 'https://eth-sepolia.g.alchemy.com/v2/••••••••';
    }
  }

  static String get reownProjectId {
    const fromDefine = String.fromEnvironment('PROJECT_ID');
    if (fromDefine.isNotEmpty) return fromDefine.trim();
    if (dotenv.isInitialized) {
      final fromEnv = dotenv.env['REOWN_PROJECT_ID']?.trim();
      if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    }
    return '';
  }

  static String get defaultPrivateKey =>
      dotenv.isInitialized ? (dotenv.env['PRIVATE_KEY']?.trim() ?? '') : '';

  static String? validate() {
    if (rpcUrl.isEmpty) {
      return 'RPC_URL belum dikonfigurasi di file .env';
    }

    if (contractAddress.isEmpty) {
      return 'CONTRACT_ADDRESS belum diisi di file .env';
    }

    if (!contractAddress.startsWith('0x') || contractAddress.length != 42) {
      return 'Format CONTRACT_ADDRESS tidak valid (harus 42 karakter diawali 0x)';
    }

    return null; // Valid
  }

  static String getShortAddress(String address) {
    if (address.length <= 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }
}
