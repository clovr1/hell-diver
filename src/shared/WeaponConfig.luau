--!strict
-- Senapan standar (hitscan). Amunisi dibaca dari attribute "Ammo" pada Player.

return {
	name = "Senapan Standar",
	damage = 25,
	fireInterval = 0.12, -- detik antar tembakan (tahan klik untuk otomatis)
	range = 300,
	ammoPerShot = 1,
	tracerColor = Color3.fromRGB(255, 220, 120),
}
