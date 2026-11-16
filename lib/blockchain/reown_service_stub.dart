import 'package:flutter/material.dart';
import 'package:web3dart/web3dart.dart';

/// Stub implementation of ReownService for non-IO platforms (Flutter Web).
/// Does NOT import `reown_appkit` so Web builds never face unsupported platform issues.
class ReownService with ChangeNotifier {
  static final ReownService _instance = ReownService._internal();
  factory ReownService() => _instance;
  ReownService._internal();

  bool get isConnected => false;
  String? get walletAddress => null;
  int get currentChainId => 11155111;
  bool get isSepoliaNetwork => true;

  Future<void> init(BuildContext context) async {}

  Future<void> openModal(BuildContext context) async {}

  Future<void> disconnect() async {}

  Future<String> sendContractTransaction({
    required DeployedContract contract,
    required String functionName,
    required List<dynamic> parameters,
  }) async {
    throw UnsupportedError(
      'Reown AppKit hanya didukung pada platform native (Android / iOS).',
    );
  }
}

