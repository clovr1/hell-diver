--!strict
-- Misi "Menara Radio": nyalakan semua menara, lalu semua pemain kabur ke titik evakuasi.
-- Posisi default dihitung dari SpawnLocation map (bukan spawn lobby). Untuk map sendiri, buat folder "MissionPoints" di
-- Workspace berisi Part bernama Tower1, Tower2, ... dan Evac; posisi Part itu dipakai sebagai gantinya.

return {
	startDelay = 3, -- detik setelah mendarat sampai menara muncul
	towerOffsets = { -- relatif terhadap SpawnLocation (X, Z)
		Vector3.new(80, 0, -60),
		Vector3.new(-90, 0, 40),
		Vector3.new(20, 0, 110),
	},
	evacOffset = Vector3.new(-40, 0, -120),
	activationSeconds = 6, -- lama menahan E di menara
	evacRadius = 16, -- radius lingkaran evakuasi (stud)
	evacHoldSeconds = 5, -- lama semua pemain hidup harus berada di lingkaran
	resetDelay = 8, -- jeda setelah misi selesai sampai pemain kembali ke lobby
}
