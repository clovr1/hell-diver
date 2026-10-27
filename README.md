# Hell Diver (Roblox)

Game co-op 4 pemain bertema sci-fi militer serius: terjun ke planet musuh, selesaikan misi, kabur ke titik evakuasi.

## Status

- [x] 1. Sistem input sinyal bantuan (Ctrl + kombinasi panah + lempar penanda)
- [x] 2. Serangan orbital dan paket logistik
- [x] 3. Musuh gerombolan (alien dan mesin) dan senapan dasar
- [ ] 4. Misi dan evakuasi
- [ ] 5. Mati, bala bantuan, friendly fire

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
| `src/client/StratagemInput.client.luau` | LocalScript, nama `StratagemInput` | `StarterPlayer` > `StarterPlayerScripts` > folder `Client` |
| `src/shared/EnemyConfig.luau` | ModuleScript, nama `EnemyConfig` | `ReplicatedStorage` > `Shared` |
| `src/shared/WeaponConfig.luau` | ModuleScript, nama `WeaponConfig` | `ReplicatedStorage` > `Shared` |
| `src/server/EnemyService.luau` | ModuleScript, nama `EnemyService` | `ServerScriptService` > `Server` |
| `src/server/SwarmDirector.server.luau` | Script, nama `SwarmDirector` | `ServerScriptService` > `Server` |
| `src/server/WeaponService.server.luau` | Script, nama `WeaponService` | `ServerScriptService` > `Server` |
| `src/client/WeaponInput.client.luau` | LocalScript, nama `WeaponInput` | `StarterPlayer` > `StarterPlayerScripts` > `Client` |

Nama folder dan script harus sama persis, karena script saling `require` lewat path itu.

## Cara main

1. Tahan **Ctrl kiri**. Panel sinyal muncul, WASD tidak menggerakkan karakter selama Ctrl ditahan.
2. Ketik kombinasi dengan panah atau WASD. Langkah yang benar menyala kuning; salah satu langkah berarti mulai ulang.
3. Setelah kombinasi lengkap, sinyal siap. Klik kiri untuk melempar penanda ke tanah (X atau Esc membatalkan).
4. Penanda menyala di tanah. Beberapa detik kemudian bantuan tiba:
   - **Serangan Orbital**: 6 ledakan beruntun di dalam lingkaran merah. **Friendly fire aktif**, termasuk untukmu sendiri; kerusakan 120 di pusat, turun ke 20 di tepi ledakan.
   - **Paket Logistik**: peti jatuh dari langit. Tahan E di dekatnya untuk mengisi amunisi (attribute `Ammo` pada Player, terlihat di Explorer). Tiap pemain sekali per peti, peti habis setelah 4 pengambilan atau 60 detik.
   - **Penerjunan Pasukan**: masih tiang cahaya placeholder (langkah 5).

| Sinyal | Kombinasi |
| --- | --- |
| Serangan Orbital | ↑ → → ↓ |
| Paket Logistik | ↓ ← ↓ ↑ |
| Penerjunan Pasukan | ← ↑ ↓ → ↑ |

Semua nama, kombinasi, kooldaun, dan warna ada di `src/shared/StratagemConfig.luau`.

## Senjata dan musuh

- **Senapan Standar**: tahan klik kiri untuk menembak ke arah kursor (25 damage per peluru, 8 tembakan per detik, 1 amunisi per peluru). Amunisi tampil di pojok kanan bawah; isi ulang dengan Paket Logistik. Peluru juga melukai rekan setim.
- Selama Ctrl ditahan atau penanda sedang siap dilempar, klik tidak menembak.
- **Pemburu Kawanan** (alien): cepat, 40 HP, datang dalam kelompok besar.
- **Unit Penjaga** (mesin): lambat, 120 HP, pukulan keras.
- Kelompok muncul tiap 18 detik di jarak 70-100 stud dari pemain, mulai 10 detik setelah game dimulai, maksimal 40 musuh hidup sekaligus. Semua angka ada di `EnemyConfig.luau` dan `WeaponConfig.luau`.
- Serangan Orbital juga melukai musuh.

## Catatan teknis

- Musuh belum punya pathfinding: mereka berjalan lurus ke pemain terdekat dan melompat kalau tersangkut. Cocok untuk map terbuka; map dengan dinding dan bangunan butuh `PathfindingService`.

- Server tidak mempercayai client: ia memeriksa id sinyal, kooldaun, jarak lempar (`MAX_THROW_DISTANCE`), dan apakah pemain masih hidup.
- Baru mendukung keyboard + mouse. Mobile dan gamepad belum.
