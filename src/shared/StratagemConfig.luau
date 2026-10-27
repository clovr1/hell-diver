--!strict
-- Daftar sinyal bantuan. Dipakai client (menu radio + bidikan) dan server (validasi).

export type Stratagem = {
	id: string,
	name: string,
	cooldown: number, -- detik, mulai dihitung saat panggilan dikonfirmasi
	callDelay: number, -- detik dari panggilan sampai bantuan tiba
	color: Color3,
	radius: number?, -- radius area efek (stud); kalau ada, ditampilkan sebagai lingkaran di tanah
	callLine: string, -- ucapan di radio saat dipanggil
}

local Config = {}

-- Jarak maksimal sasaran dari karakter (stud). Client membatasi bidikan, server menolak yang lebih jauh.
Config.MAX_THROW_DISTANCE = 120

-- Isi penuh amunisi (attribute "Ammo" pada Player, dipakai sistem senjata).
Config.MAX_AMMO = 300

Config.Stratagems = {
	{
		id = "airstrike",
		name = "Serangan Orbital",
		cooldown = 25,
		callDelay = 3,
		color = Color3.fromRGB(255, 90, 60),
		radius = 18,
		callLine = "Markas, minta serangan orbital di titik ini. Semua unit menjauh!",
	},
	{
		id = "ammo",
		name = "Paket Logistik",
		cooldown = 12,
		callDelay = 2,
		color = Color3.fromRGB(90, 200, 255),
		callLine = "Markas, kirim paket logistik ke titik ini.",
	},
	{
		id = "reinforce",
		name = "Penerjunan Pasukan",
		cooldown = 40,
		callDelay = 4,
		color = Color3.fromRGB(120, 255, 120),
		callLine = "Markas, kirim bala bantuan ke titik ini.",
	},
} :: { Stratagem }

Config.ById = {} :: { [string]: Stratagem }
for _, def in Config.Stratagems do
	Config.ById[def.id] = def
end

return Config
