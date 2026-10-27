# Hell Diver (Roblox)

Game co-op 4 pemain bertema sci-fi militer serius: terjun ke planet musuh, selesaikan misi, kabur ke titik evakuasi.

## Status

- [x] 1. Sistem input sinyal bantuan (Ctrl + kombinasi panah + lempar penanda)
- [ ] 2. Serangan udara dan kotak amunisi
- [ ] 3. Musuh gerombolan
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

Nama folder dan script harus sama persis, karena script saling `require` lewat path itu.

## Cara main

1. Tahan **Ctrl kiri**. Panel sinyal muncul, WASD tidak menggerakkan karakter selama Ctrl ditahan.
2. Ketik kombinasi dengan panah atau WASD. Langkah yang benar menyala kuning; salah satu langkah berarti mulai ulang.
3. Setelah kombinasi lengkap, sinyal siap. Klik kiri untuk melempar penanda ke tanah (X atau Esc membatalkan).
4. Beberapa detik kemudian bantuan tiba. Sementara ini berupa tiang cahaya placeholder.

| Sinyal | Kombinasi |
| --- | --- |
| Serangan Orbital | ↑ → → ↓ |
| Paket Logistik | ↓ ← ↓ ↑ |
| Penerjunan Pasukan | ← ↑ ↓ → ↑ |

Semua nama, kombinasi, kooldaun, dan warna ada di `src/shared/StratagemConfig.luau`.

## Catatan teknis

- Server tidak mempercayai client: ia memeriksa id sinyal, kooldaun, jarak lempar (`MAX_THROW_DISTANCE`), dan apakah pemain masih hidup.
- Baru mendukung keyboard + mouse. Mobile dan gamepad belum.
