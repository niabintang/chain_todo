import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../controllers/wallet_controller.dart';

class WalletConnectDialog extends StatefulWidget {
  final VoidCallback onWalletUpdated;

  const WalletConnectDialog({
    super.key,
    required this.onWalletUpdated,
  });

  static Future<void> show(BuildContext context, {required VoidCallback onWalletUpdated}) {
    return showDialog(
      context: context,
      builder: (_) => WalletConnectDialog(onWalletUpdated: onWalletUpdated),
    );
  }

  @override
  State<WalletConnectDialog> createState() => _WalletConnectDialogState();
}

class _WalletConnectDialogState extends State<WalletConnectDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final WalletController _controller = WalletController();
  final _addressInputController = TextEditingController();

  late String _wcUri;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _wcUri = _controller.service.generatePairingUri();
    if (_controller.isConnected && _controller.walletAddress != null) {
      _addressInputController.text = _controller.walletAddress!;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _addressInputController.dispose();
    super.dispose();
  }

  Future<void> _handleConnectMetaMask() async {
    final address = _addressInputController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan masukkan atau tempel Public Address Sepolia dari MetaMask Anda.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isConnecting = true);

    try {
      await _controller.connect(address);
      widget.onWalletUpdated();

      // Buka aplikasi / web MetaMask
      await _controller.service.launchMetaMaskApp();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Wallet Connected! Berhasil terhubung ke MetaMask.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  Future<void> _handleDisconnect() async {
    await _controller.disconnect();
    _addressInputController.clear();
    setState(() {
      _wcUri = _controller.service.generatePairingUri();
    });
    widget.onWalletUpdated();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Wallet Disconnected.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _controller.isConnected;
    final isSepolia = _controller.isSepoliaNetwork;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: EdgeInsets.zero,
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF6851B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.account_balance_wallet, color: Color(0xFFF6851B)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Koneksi MetaMask', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('WalletConnect / Reown v2', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.95,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status Card (Connected / Not Connected)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isConnected ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isConnected ? Colors.green.shade300 : Colors.red.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isConnected ? Icons.check_circle : Icons.cancel_outlined,
                              size: 16,
                              color: isConnected ? Colors.green.shade800 : Colors.red.shade800,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isConnected ? 'Status: Wallet Connected' : 'Status: Wallet Not Connected',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isConnected ? Colors.green.shade900 : Colors.red.shade900,
                              ),
                            ),
                          ],
                        ),
                        if (isConnected)
                          InkWell(
                            onTap: _handleDisconnect,
                            child: const Text(
                              'Disconnect',
                              style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    if (isConnected) ...[
                      const SizedBox(height: 6),
                      SelectableText(
                        _controller.walletAddress!,
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Saldo: ${_controller.balance.toStringAsFixed(4)} Sepolia ETH',
                        style: TextStyle(fontSize: 12, color: Colors.green.shade800, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      // Indikator Status Jaringan Sepolia
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSepolia ? Colors.green.shade100 : Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSepolia ? Colors.green.shade400 : Colors.amber.shade600,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSepolia ? Icons.hub : Icons.warning_amber_rounded,
                              size: 14,
                              color: isSepolia ? Colors.green.shade900 : Colors.amber.shade900,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isSepolia ? 'Jaringan: Sepolia (11155111)' : 'Jaringan Salah! Pindah ke Sepolia',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSepolia ? Colors.green.shade900 : Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Tab Switcher
              TabBar(
                controller: _tabController,
                labelColor: Colors.indigo,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.indigo,
                tabs: const [
                  Tab(icon: Icon(Icons.touch_app, size: 18), text: 'Konek MetaMask'),
                  Tab(icon: Icon(Icons.qr_code, size: 18), text: 'Scan QR / URI'),
                ],
              ),

              SizedBox(
                height: 380,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // TAB 1: KONEK VIA ADDRESS METAMASK
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.shield, color: Colors.indigo, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Private key tidak pernah diminta atau disimpan di aplikasi. Transaksi ditandatangani langsung di MetaMask.',
                                    style: TextStyle(fontSize: 11, color: Colors.indigo, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Alamat Dompet MetaMask (Public Address):',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _addressInputController,
                            decoration: InputDecoration(
                              hintText: '0x...',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.paste, size: 18),
                                onPressed: () async {
                                  final data = await Clipboard.getData('text/plain');
                                  if (data?.text != null) {
                                    setState(() {
                                      _addressInputController.text = data!.text!.trim();
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF6851B), // Warna MetaMask
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: _isConnecting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Icon(Icons.account_balance_wallet),
                              label: const Text(
                                'Connect MetaMask Wallet',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              onPressed: _isConnecting ? null : _handleConnectMetaMask,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.open_in_browser, size: 16),
                                  label: const Text('Buka Web MetaMask', style: TextStyle(fontSize: 11)),
                                  onPressed: () => _controller.openMetaMaskWeb(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.smartphone, size: 16),
                                  label: const Text('Buka App MetaMask', style: TextStyle(fontSize: 11)),
                                  onPressed: () => _controller.openMetaMaskApp(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // TAB 2: SCAN QR CODE / SALIN WALLETCONNECT URI
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: QrImageView(
                              data: _wcUri,
                              version: QrVersions.auto,
                              size: 160.0,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Scan QR dari MetaMask HP untuk pairing',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Salin Pairing URI', style: TextStyle(fontSize: 12)),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _wcUri));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('WalletConnect URI disalin ke clipboard!')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
      ],
    );
  }
}
