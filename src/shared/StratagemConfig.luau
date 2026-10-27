--!strict
-- Daftar sinyal bantuan. Dipakai client (UI + pencocokan kombinasi) dan server (validasi).
-- Arah: "U" atas, "D" bawah, "L" kiri, "R" kanan.

export type Stratagem = {
	id: string,
	name: string,
	code: { string },
	cooldown: number, -- detik, mulai dihitung saat penanda dilempar
	callDelay: number, -- detik dari penanda mendarat sampai bantuan tiba
	color: Color3,
}

local Config = {}

-- Jarak maksimal lempar dari karakter (stud). Server menolak yang lebih jauh.
Config.MAX_THROW_DISTANCE = 120

Config.Stratagems = {
	{
		id = "airstrike",
		name = "Serangan Orbital",
		code = { "U", "R", "R", "D" },
		cooldown = 25,
		callDelay = 3,
		color = Color3.fromRGB(255, 90, 60),
	},
	{
		id = "ammo",
		name = "Paket Logistik",
		code = { "D", "L", "D", "U" },
		cooldown = 12,
		callDelay = 2,
		color = Color3.fromRGB(90, 200, 255),
	},
	{
		id = "reinforce",
		name = "Penerjunan Pasukan",
		code = { "L", "U", "D", "R", "U" },
		cooldown = 40,
		callDelay = 4,
		color = Color3.fromRGB(120, 255, 120),
	},
} :: { Stratagem }

Config.ById = {} :: { [string]: Stratagem }
for _, def in Config.Stratagems do
	Config.ById[def.id] = def
end

-- Kombinasi tidak boleh jadi awalan kombinasi lain, kalau tidak, yang panjang tidak pernah bisa dimasukkan.
for _, a in Config.Stratagems do
	for _, b in Config.Stratagems do
		if a ~= b and #a.code <= #b.code then
			local isPrefix = true
			for i, dir in a.code do
				if b.code[i] ~= dir then
					isPrefix = false
					break
				end
			end
			assert(not isPrefix, `Kode {a.id} adalah awalan kode {b.id}`)
		end
	end
end

Config.ARROW_GLYPH = { U = "↑", D = "↓", L = "←", R = "→" } :: { [string]: string }

return Config
