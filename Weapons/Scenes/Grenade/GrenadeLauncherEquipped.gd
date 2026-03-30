# grenade_launcher_view.gd
extends WeaponEquipped

var last_fire_time: float = 0.0

func attack() -> void:
	if not weapon_data:
		return
		
	# Check fire rate / recovery delay
	var current_ticks = Time.get_ticks_msec() / 1000.0
	if current_ticks - last_fire_time < weapon_data.recovery_delay:
		return
	last_fire_time = current_ticks
	
	print("Grenade Launcher: THUMP!")
	
	# Tell the base script to perform the projectile launch logic.
	fire_projectile()
	
	# Recoil is already handled inside fire_projectile(), so we don't need to call it again.
