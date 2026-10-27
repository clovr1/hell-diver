--!strict
-- Jenis musuh dan pengaturan penyebar gerombolan. Dipakai server (EnemyService, SwarmDirector).

export type EnemyDef = {
	id: string,
	name: string,
	health: number,
	speed: number, -- stud/detik
	damage: number, -- per serangan
	attackRange: number, -- jarak pusat ke pusat (stud)
	attackCooldown: number, -- detik
	size: Vector3,
	color: Color3,
	eyeColor: Color3,
	material: Enum.Material,
}

local EnemyConfig = {}

EnemyConfig.Enemies = {
	-- Makhluk alien: cepat, rapuh, datang berkelompok.
	swarmer = {
		id = "swarmer",
		name = "Pemburu Kawanan",
		health = 40,
		speed = 22,
		damage = 10,
		attackRange = 5,
		attackCooldown = 0.8,
		size = Vector3.new(2.5, 2, 3.5),
		color = Color3.fromRGB(60, 110, 85),
		eyeColor = Color3.fromRGB(190, 255, 80),
		material = Enum.Material.Slate,
	},
	-- Mesin otonom: lambat, tahan banyak tembakan, pukulan keras.
	guard = {
		id = "guard",
		name = "Unit Penjaga",
		health = 120,
		speed = 12,
		damage = 25,
		attackRange = 6,
		attackCooldown = 1.4,
		size = Vector3.new(4, 4.5, 4),
		color = Color3.fromRGB(95, 100, 110),
		eyeColor = Color3.fromRGB(255, 50, 50),
		material = Enum.Material.Metal,
	},
} :: { [string]: EnemyDef }

EnemyConfig.Director = {
	enabled = false, -- true untuk menyalakan gelombang musuh otomatis
	firstDelay = 15, -- detik sebelum gelombang pertama
	interval = 25, -- detik antar kelompok
	groupMin = 3,
	groupMax = 5,
	maxAlive = 40, -- batas musuh hidup bersamaan (menjaga performa)
	spawnDistanceMin = 70, -- dari titik tengah para pemain (stud)
	spawnDistanceMax = 100,
	groupSpread = 8, -- sebaran anggota kelompok
	weights = { swarmer = 7, guard = 3 } :: { [string]: number },
}

return EnemyConfig
