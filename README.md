# Hell Diver (Roblox)

Game co-op 4 pemain bertema sci-fi militer serius: terjun ke planet musuh, selesaikan misi, kabur ke titik evakuasi.

## Status

- [x] 1. Sistem sinyal bantuan lewat radio (menu + bidikan kamera atas)
- [x] 2. Serangan orbital dan paket logistik
- [x] 3. Musuh gerombolan (alien dan mesin) dan senapan dasar
- [x] 4. Misi menara radio dan titik evakuasi
- [ ] 5. Mati dan hidup kembali (bala bantuan dihapus; mekanisme respawn menyusul)

## Menjalankan

### Dengan Rojo (disarankan)

```
rojo serve
```

Buka Roblox Studio, buat place kosong (Baseplate), lalu sambungkan lewat plugin Rojo. Tekan Play.

### Tanpa Rojo (tempel manual)

| File | Jenis di Studio | Letak |
| --- | --- | --- |
| `src/shared/StratagemConfig.luau` | ModuleScript, nama `StratagemConfig` | `ReplicatedStorage` > folder `Shared` |
| `src/server/StratagemHandlers.luau` | ModuleScript, nama `StratagemHandlers` | `ServerScriptService` > folder `Server` |
| `src/server/StratagemService.server.luau` | Script, nama `StratagemService` | `ServerScriptService` > folder `Server` |
| `src/client/RadioInput.client.luau` | LocalScript, nama `RadioInput` | `StarterPlayer` > `StarterPlayerScripts` > folder `Client` |
| `src/shared/EnemyConfig.luau` | ModuleScript, nama `EnemyConfig` | `ReplicatedStorage` > `Shared` |
| `src/shared/WeaponConfig.luau` | ModuleScript, nama `WeaponConfig` | `ReplicatedStorage` > `Shared` |
| `src/server/EnemyService.luau` | ModuleScript, nama `EnemyService` | `ServerScriptService` > `Server` |
| `src/server/SwarmDirector.server.luau` | Script, nama `SwarmDirector` | `ServerScriptService` > `Server` |
| `src/server/WeaponService.server.luau` | Script, nama `WeaponService` | `ServerScriptService` > `Server` |
| `src/client/WeaponInput.client.luau` | LocalScript, nama `WeaponInput` | `StarterPlayer` > `StarterPlayerScripts` > `Client` |
| `src/shared/MissionConfig.luau` | ModuleScript, nama `MissionConfig` | `ReplicatedStorage` > `Shared` |
| `src/server/MissionService.server.luau` | Script, nama `MissionService` | `ServerScriptService` > `Server` |
| `src/client/MissionHUD.client.luau` | LocalScript, nama `MissionHUD` | `StarterPlayer` > `StarterPlayerScripts` > `Client` |

Nama folder dan script harus sama persis, karena script saling `require` lewat path itu.

## Cara main

1. Tekan **Q** (atau tombol **RADIO** di kiri bawah) untuk membuka radio. Pilih bantuan dengan klik atau tombol **1**-**3**. Bantuan yang sedang kooldaun berwarna abu-abu.
2. **Paket Logistik** dan **Pindai Musuh** langsung dipanggil di posisimu, tanpa membidik. Hanya **Serangan Orbital** yang membuat kamera naik ke tampilan atas: gerakkan kursor untuk membidik, lingkaran merah menunjukkan area efek, dan bidikan dibatasi sejauh 110 stud dari karakter.
3. Saat membidik, **klik kiri** untuk memanggil. **Klik kanan**, **Q**, atau **X** untuk membatalkan. Di perangkat sentuh, tombol **PANGGIL** dan **BATAL** muncul otomatis.
4. Bantuan tiba beberapa detik kemudian (untuk Serangan Orbital, kamera turun lagi dan penanda menyala di sasaran):
   - **Serangan Orbital**: 12 peluru jatuh dari langit satu per satu (tampak sebagai garis cahaya), tersebar merata di dalam lingkaran merah dan meledak saat mendarat. **Friendly fire aktif**, termasuk untukmu sendiri; tiap ledakan 70 damage di pusat, turun ke 15 di tepi, dan ledakan yang tumpang tindih menumpuk.
   - **Paket Logistik**: peti jatuh dari langit di dekatmu. Tahan E di dekatnya untuk mengisi amunisi (attribute `Ammo` pada Player). Tiap pemain sekali per peti, peti habis setelah 4 pengambilan atau 60 detik.
   - **Pindai Musuh**: gelombang cahaya ungu menyebar dari kakimu. Selama 15 detik, musuh dalam radius 100 stud darimu ditandai (siluet ungu, tembus dinding) dan terlihat oleh semua pemain. Pusat pindai ikut bergerak bersamamu, dan musuh yang keluar radius kehilangan tanda. Maksimal 30 musuh ditandai (yang terdekat).

Game **tidak berhenti** saat kamu membidik: karakter tetap diam di tempat dan musuh tetap menyerang. Cari tempat aman sebelum memanggil.

Nama, kooldaun, warna, dan ucapan radio ada di `src/shared/StratagemConfig.luau`.

## Misi: Menara Radio

1. Sekitar 8 detik setelah ada pemain hidup, 3 menara muncul di map (tiang dengan lampu merah). Penanda nama dan jarak tampil di atas tiap menara, tembus dinding.
2. Tahan **E** di dekat menara selama 6 detik untuk menyalakannya (lampu jadi hijau dan ada pilar cahaya). Kalau menjauh atau melepas E, tahanan batal.
3. Setelah ketiganya menyala, muncul **titik evakuasi** (lingkaran hijau). **Semua pemain yang hidup** harus berada di dalam lingkaran 5 detik berturut-turut. Kalau ada yang keluar, progres turun pelan.
4. Misi selesai. Setelah 12 detik, ronde baru dimulai dengan menara baru.

Posisi default dihitung dari `SpawnLocation`. Untuk map sendiri, buat folder `MissionPoints` di Workspace berisi Part bernama `Tower1`, `Tower2`, ... dan `Evac`; posisi Part itu dipakai (Part boleh dibuat transparan atau digeser ke bawah tanah). Angka-angkanya ada di `MissionConfig.luau`.

Belum ada: musuh yang menyerang saat menara dinyalakan atau saat evakuasi (gelombang musuh sedang dimatikan), kondisi gagal, dan hukuman kalau semua pemain mati.

## Senjata dan musuh

- **Senapan Standar**: tahan klik kiri untuk menembak ke arah kursor (25 damage per peluru, 8 tembakan per detik, 1 amunisi per peluru). Amunisi (maks. 300) tampil di pojok kanan bawah; isi ulang dengan Paket Logistik. Peluru juga melukai rekan setim.
- Selama radio terbuka atau sedang membidik, klik tidak menembak.
- **Pemburu Kawanan** (alien): cepat, 40 HP, datang berkelompok.
- **Unit Penjaga** (mesin): lambat, 120 HP, pukulan keras.
- **Gelombang musuh otomatis sedang dimatikan** (`Director.enabled = false` di `EnemyConfig.luau`); ubah ke `true` untuk menyalakan.
- Kelompok 3-5 musuh muncul tiap 25 detik di jarak 70-100 stud dari pemain, mulai 15 detik setelah game dimulai, maksimal 40 musuh hidup sekaligus. Semua angka ada di `EnemyConfig.luau` dan `WeaponConfig.luau`.
- Serangan Orbital juga melukai musuh.

## Catatan teknis

- Musuh belum punya pathfinding: mereka berjalan lurus ke pemain terdekat dan melompat kalau tersangkut. Cocok untuk map terbuka; map dengan dinding dan bangunan butuh `PathfindingService`.

- Server tidak mempercayai client: ia memeriksa id sinyal, kooldaun, jarak sasaran (`MAX_THROW_DISTANCE`), dan apakah pemain masih hidup.
- Radio sudah punya tombol layar untuk sentuhan (ketuk peta untuk membidik, lalu PANGGIL), tapi belum dites di HP. Menembak baru mendukung mouse; gamepad belum.
