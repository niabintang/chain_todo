# ChainTodo - Aplikasi Flutter Terhubung Smart Contract Blockchain

Tugas Proyek Mata Kuliah **Pemrograman Mobile 2**  
Program Studi D4 Teknologi Rekayasa Komputer, Jurusan TIK, Politeknik Negeri Samarinda.

Aplikasi to-do list terdesentralisasi (dApp) berbasis blockchain yang membaca dan mencatat data langsung ke smart contract di jaringan **Ethereum Sepolia Testnet** tanpa perantara database server terpusat. Mendukung arsitektur **Dual-Platform**:
1. **Flutter Web (PC/Laptop)**: Terhubung ke **MetaMask Browser Extension** melalui standar EIP-1193 (`window.ethereum`).
2. **Flutter Android (APK Mobile)**: Terhubung ke aplikasi **MetaMask Mobile** via **Reown AppKit / WalletConnect v2** dengan deep-link return (`chaintodo://`).

---

## 1. Alamat Kontrak & Tautan Etherscan

- **Nama Smart Contract**: `ChainTodoV2`
- **Jaringan**: Ethereum Sepolia Testnet (Chain ID: `11155111` / `0xaa36a7`)
- **Alamat Kontrak V2**: [`0x5eEd686C9F3DefC12bB5EE5dfd0f47e039EF61EE`](https://sepolia.etherscan.io/address/0x5eEd686C9F3DefC12bB5EE5dfd0f47e039EF61EE)
- **Tautan Etherscan**: [https://sepolia.etherscan.io/address/0x5eEd686C9F3DefC12bB5EE5dfd0f47e039EF61EE](https://sepolia.etherscan.io/address/0x5eEd686C9F3DefC12bB5EE5dfd0f47e039EF61EE)
- **Struktur Data Tugas (Struct)**:
  - `judul` (`string`): Judul tugas.
  - `selesai` (`bool`): Status penyelesaian tugas.
  - `waktuDibuat` (`uint256`): Unix timestamp waktu tugas dicatat ke block.
  - `pembuat` (`address`): Alamat wallet pemilik tugas.
  - `aktif` (`bool`): Status aktif tugas (mendukung *soft-delete* on-chain).
- **Fungsi Smart Contract**:
  - `tambahTugas(string calldata _judul)` — Menulis tugas baru ke blockchain.
  - `tandaiSelesai(uint256 _id)` — Mengubah status tugas menjadi selesai (khusus pemilik tugas).
  - `editTugas(uint256 _id, string calldata _judulBaru)` — Mengubah judul tugas (khusus pemilik tugas). *(Fitur Bonus 2)*
  - `hapusTugas(uint256 _id)` — Menonaktifkan tugas dari smart contract (khusus pemilik tugas). *(Fitur Bonus 2)*
  - `jumlahTugas()` — Membaca total jumlah tugas (*view function*).
  - `ambilTugas(uint256 _id)` — Membaca data detail struct tugas beserta status `aktif` (*view function*).

---

## 2. Fitur Unggulan & Fitur Bonus Terimplementasi

- ✅ **Dual-Platform Wallet Integration**:
  - **Web**: Menggunakan `window.ethereum` (EIP-1193) langsung memunculkan popup konfirmasi MetaMask Extension di Google Chrome.
  - **Android**: Menggunakan Reown AppKit dengan WalletConnect v2. Menargetkan langsung aplikasi MetaMask Mobile (`io.metamask`), dan otomatis kembali ke ChainTodo setelah disetujui via deep link `chaintodo://`.
- ✅ **Pemisahan Platform Aman (Conditional Compilation)**:
  - Kode native Reown dipisahkan menggunakan *conditional export* (`reown_service_stub.dart` dan `reown_service_mobile.dart`) sehingga tidak merusak atau menyebabkan error kompilasi pada target Flutter Web.
- ✅ **Zero Private Key Exposure**:
  - Tidak ada *private key* atau *seed phrase* yang ditanam di dalam kode aplikasi. Seluruh transaksi on-chain ditandatangani secara aman langsung di dalam dompet MetaMask pengguna.
- ✅ **Real-Time Event Listener (Fitur Bonus 1)**:
  - Mendengarkan event blockchain `TugasBaru`, `TugasSelesai`, `TugasDiedit`, dan `TugasDihapus` secara asinkronus menggunakan `web3dart` Event Filter Stream. Setiap kali terjadi perubahan di Sepolia, aplikasi otomatis menyegarkan tampilan tanpa perlu me-reload halaman.
- ✅ **Auto-Sync Fallback (Fitur Bonus 1)**:
  - Dilengkapi *periodic background sync* (setiap 30 detik) untuk menjaga keandalan data tugas tetap sinkron dengan node RPC Sepolia.
- ✅ **Edit Judul Tugas On-Chain (Fitur Bonus 2)**:
  - Pembuat tugas dapat memperbarui judul tugas langsung di smart contract. Dilindungi validasi kepemilikan (`require(msg.sender == pembuat)`).
- ✅ **Hapus Tugas On-Chain (Fitur Bonus 2)**:
  - Pembuat tugas dapat menghapus tugas secara aman (*soft delete* on-chain). Tugas yang sudah dihapus tidak akan ditampilkan kembali di daftar.
- ✅ **Filter Tugas Interaktif**:
  - Filter cepat untuk memilah tugas: *Semua*, *Belum Selesai*, *Selesai*, dan *Milik Saya*.

---

## 3. Versi Paket (Dependencies)

| Nama Paket | Versi | Fungsi / Peran dalam Aplikasi |
|---|:---:|---|
| **`web3dart`** | `^3.0.3` | Library inti Dart untuk komunikasi RPC ke node Ethereum dan encoding/decoding transaksi smart contract. |
| **`reown_appkit`** | `^1.9.0` | SDK WalletConnect v2 & Reown AppKit untuk koneksi modal dompet di Android native (MetaMask Mobile). |
| **`http`** | `^1.6.0` | HTTP client untuk request JSON-RPC ke endpoint Alchemy Sepolia. |
| **`wallet`** | `^0.0.18` | Parser alamat dompet Ethereum (checksum EIP-55) dan utilitas konversi satuan Ether/Wei. |
| **`flutter_dotenv`** | `^6.0.1` | Pengelola berkas konfigurasi lingkungan (`.env`) agar RPC URL dan Project ID aman. |
| **`flutter_secure_storage`** | `^10.3.4` | Penyimpanan lokal terenkripsi di perangkat untuk menjaga sesi dompet tetap aman. |
| **`url_launcher`** | `^6.3.1` | Membuka tautan eksternal ke Sepolia Etherscan dan *fallback deep link* MetaMask. |
| **`qr_flutter`** | `^4.1.0` | Menampilkan QR Code pairing dompet. |
| **`cupertino_icons`** | `^1.0.8` | Ikon visual antarmuka Flutter. |

---

## 4. Konfigurasi Lingkungan (`.env`) & Android

### Berkas `.env`
Buat berkas `.env` di direktori *root* proyek (salin dari `.env.example`):
```env
CHAIN_ID=11155111
NETWORK_NAME=Sepolia
RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_ALCHEMY_API_KEY
CONTRACT_ADDRESS=0x5eEd686C9F3DefC12bB5EE5dfd0f47e039EF61EE
EXPLORER_URL=https://sepolia.etherscan.io
REOWN_PROJECT_ID=YOUR_REOWN_PROJECT_ID
```
> **Keterangan:**
> - `RPC_URL`: Endpoint RPC Sepolia (dapat dibuat gratis di [alchemy.com](https://www.alchemy.com/)).
> - `REOWN_PROJECT_ID`: Project ID Reown / WalletConnect (dapat dibuat gratis di [cloud.reown.com](https://cloud.reown.com/)).

### Konfigurasi Android (`AndroidManifest.xml`)
- **Permissions**: `INTERNET`, `ACCESS_NETWORK_STATE`.
- **Deep Link Intent Filter**: Schema `chaintodo://` pada `MainActivity` untuk menangani redirect balik setelah persetujuan MetaMask Mobile.
- **Package Visibility (`<queries>`)**: Mendaftarkan `io.metamask` serta skema `metamask` dan `wc`.
- **Minimum SDK**: `minSdk = 23` pada `android/app/build.gradle.kts`.

---

## 5. Cara Menjalankan & Membangun (Build)

### A. Jika Mengambil Proyek dari GitHub (Clone Repo)
1. **Clone Repositori**:
   ```bash
   git clone <URL_REPOSITORI_GITHUB>
   cd chain_todo
   ```
2. **Pasang Dependensi**:
   ```bash
   flutter pub get
   ```
3. **Konfigurasi Berkas `.env`**:
   - Di Windows (PowerShell / CMD):
     ```powershell
     copy .env.example .env
     ```
   - Di Linux / macOS:
     ```bash
     cp .env.example .env
     ```
   - Buka berkas `.env` lalu sesuaikan `RPC_URL` dan `REOWN_PROJECT_ID` milik Anda.

---

### B. Menjalankan Aplikasi
#### 1. Flutter Web (Google Chrome)
Pastikan Google Chrome memiliki **MetaMask Browser Extension** yang aktif di jaringan Sepolia:
```bash
flutter run -d chrome
```

#### 2. Android (HP Fisik / Emulator)
Pastikan perangkat Android terpasang aplikasi **MetaMask Mobile**:
```bash
flutter run --dart-define=PROJECT_ID=YOUR_REOWN_PROJECT_ID
```

---

### C. Membangun Rilis (Build)
#### 1. Build Web Release
```bash
flutter build web --release
```
*Hasil:* `build/web/`

#### 2. Build Android Release APK
```bash
flutter build apk --release --dart-define=PROJECT_ID=YOUR_REOWN_PROJECT_ID
```
*Hasil berkas APK:* `build/app/outputs/flutter-apk/app-release.apk`

---

## 6. Verifikasi & Pengujian Kualitas Kode

Proyek ini telah lulus verifikasi analisis kode statis dan pengujian unit/widget:

```bash
# Pemeriksaan kualitas dan kompatibilitas sintaks
flutter analyze
# Output: No issues found!

# Pengujian unit & widget testing
flutter test
# Output: All tests passed!
```

---

## 7. Sumber Kode yang Diadaptasi & Referensi

1. **Panduan Resmi Reown AppKit Flutter**:
   - Dokumentasi Reown AppKit: [docs.reown.com/appkit/flutter/core/installation](https://docs.reown.com/appkit/flutter/core/installation)
   - Repository Resmi: [github.com/reown-com/reown_flutter](https://github.com/reown-com/reown_flutter)
2. **Spesifikasi Ethereum Provider API (EIP-1193)**:
   - Dokumentasi MetaMask Developer: [docs.metamask.io](https://docs.metamask.io/wallet/reference/provider-api/)
   - Diadaptasi untuk deteksi `window.ethereum`, `eth_requestAccounts`, `eth_chainId`, dan pengalihan rantai otomatis ke Sepolia (`wallet_switchEthereumChain`).
3. **Panduan Resmi Pengembang Ethereum untuk Dart**:
   - Dokumentasi Ethereum: [ethereum.org/en/developers/docs/programming-languages/dart/](https://ethereum.org/en/developers/docs/programming-languages/dart/)
   - Digunakan sebagai rujukan pemanggilan fungsi `call` (*read*) dan `sendTransaction` (*write*) menggunakan `web3dart`.
4. **Kerangka Smart Contract Modul Praktikum**:
   - Dokumen modul praktikum Pemrograman Mobile 2 (Politeknik Negeri Samarinda).
5. **Bantuan Kecerdasan Buatan (AI)**:
   - Penggunaan asisten AI (Google Gemini) dimanfaatkan untuk arsitektur *dual-platform conditional import*, integrasi Reown AppKit modal, responsivitas UI, dan pengujian build.
