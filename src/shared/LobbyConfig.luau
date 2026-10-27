--!strict
-- Lobby melayang (orbit) dan penerjunan ke planet. Semua dibuat dari Part saat server mulai,
-- jadi lobby bisa diganti model buatan sendiri nanti tanpa mengubah alur.

return {
	origin = Vector3.new(1500, 400, 0), -- pusat platform lobby, jauh di samping dan di atas map
	platformSize = Vector3.new(140, 2, 140),
	countdownSeconds = 8, -- jeda setelah konsol ditekan sampai dropship berangkat
	launchSeconds = 3, -- lama dropship bergetar sebelum layar memutih
	dropAltitude = 450, -- tinggi awal terjun di atas titik pendaratan (stud)
	dropSeconds = 6, -- lama terjun
	dropSpread = 8, -- jarak antar pemain di titik pendaratan (stud)
}
