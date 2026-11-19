// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ChainTodoV2 {
    struct Tugas {
        string judul;
        bool selesai;
        uint256 waktuDibuat;
        address pembuat;
        bool aktif; // true = aktif, false = terhapus (soft delete)
    }

    Tugas[] public daftarTugas;

    event TugasBaru(uint256 indexed id, string judul, address indexed pembuat);
    event TugasSelesai(uint256 indexed id);
    event TugasDiedit(uint256 indexed id, string judulBaru);
    event TugasDihapus(uint256 indexed id);

    modifier hanyaPembuat(uint256 _id) {
        require(_id < daftarTugas.length, "ID tugas tidak ditemukan");
        require(daftarTugas[_id].aktif, "Tugas sudah dihapus");
        require(msg.sender == daftarTugas[_id].pembuat, "Akses ditolak: Hanya pembuat tugas!");
        _;
    }

    function tambahTugas(string calldata _judul) external {
        require(bytes(_judul).length > 0, "Judul tugas tidak boleh kosong");
        
        daftarTugas.push(Tugas({
            judul: _judul,
            selesai: false,
            waktuDibuat: block.timestamp,
            pembuat: msg.sender,
            aktif: true
        }));

        emit TugasBaru(daftarTugas.length - 1, _judul, msg.sender);
    }

    function tandaiSelesai(uint256 _id) external hanyaPembuat(_id) {
        require(!daftarTugas[_id].selesai, "Tugas sudah diselesaikan sebelumnya");
        daftarTugas[_id].selesai = true;
        emit TugasSelesai(_id);
    }

    // FITUR BONUS 1: EDIT JUDUL TUGAS
    function editTugas(uint256 _id, string calldata _judulBaru) external hanyaPembuat(_id) {
        require(bytes(_judulBaru).length > 0, "Judul baru tidak boleh kosong");
        daftarTugas[_id].judul = _judulBaru;
        emit TugasDiedit(_id, _judulBaru);
    }

    // FITUR BONUS 2: HAPUS TUGAS
    function hapusTugas(uint256 _id) external hanyaPembuat(_id) {
        daftarTugas[_id].aktif = false;
        emit TugasDihapus(_id);
    }

    function jumlahTugas() external view returns (uint256) {
        return daftarTugas.length;
    }

    function ambilTugas(uint256 _id) external view returns (
        string memory judul,
        bool selesai,
        uint256 waktuDibuat,
        address pembuat,
        bool aktif
    ) {
        require(_id < daftarTugas.length, "ID tugas tidak valid");
        Tugas storage t = daftarTugas[_id];
        return (t.judul, t.selesai, t.waktuDibuat, t.pembuat, t.aktif);
    }
}