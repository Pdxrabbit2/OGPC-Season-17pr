extends CharacterBody2D


@onready var graphics_efficiency = get_parent().graphics_efficiency
@onready var player = get_parent().get_node("Player").get_node("Player")
@onready var loaded_bullet = preload("res://Objects/StaticObjects/DroneBullet.tscn")
@onready var loaded_mele = preload("res://Objects/StaticObjects/AttackMele.tscn")
@onready var loaded_drill = preload("res://Objects/StaticObjects/Drill.tscn")
@onready var loaded_bomb = preload("res://Objects/StaticObjects/Exploder.tscn")
@onready var boss_fight_intro = preload("res://Assets/Audio/Music/BossFightThemeIntro.ogg")
@onready var boss_fight_loop = preload("res://Assets/Audio/Music/BossFightThemeLoop.ogg")
@onready var boss_fight_outro = preload("res://Assets/Audio/Music/BossFightOutro.wav")
@onready var external_special_music_player = get_tree().get_root().get_node("Root").get_node("SaveLoadFramework").get_node("SpecialAudioPlayer")
@onready var save_load_framework = get_tree().get_root().get_node("Root").get_node("SaveLoadFramework")
@onready var start_pos = position 

@export var health = 100

var dropped_enemies = false
var dead = false
var bob_x = 0
var has_weapon_time = 0
var has_ability_time = 0
var finished_down = false
var finished_up = false
var can_get_hurt_by_bullets = false
var bridge_opened = false
var player_in_final_area = false
var elevator_enabled = false

func _ready():
	health = get_tree().get_root().get_node("Root").get_node("SaveLoadFramework").boss_health

func shoot_bullet(pos):
	var direction_to_player = (player.position - position + player.get_parent().position - pos).normalized()
	var bullet_to_add = loaded_bullet.instantiate()
	bullet_to_add.position = position + pos
	bullet_to_add.velocity = direction_to_player * 3
	bullet_to_add.graphics_efficiency = graphics_efficiency
	get_parent().add_child(bullet_to_add)
	
func spawn_mele(pos):
	var mele_to_add = loaded_mele.instantiate()
	mele_to_add.position = position + pos
	mele_to_add.health = 2
	get_parent().add_child(mele_to_add)
	
func spawn_drill(pos):
	var drill_to_add = loaded_drill.instantiate()
	drill_to_add.position = position + pos
	drill_to_add.disable_hitbox_when_dead = true
	get_parent().add_child(drill_to_add)
	
func spawn_bomb(pos, vel_scale):
	var bomb_to_add = loaded_bomb.instantiate()
	bomb_to_add.position = position + pos
	var direction_to_player = (player.position - position + player.get_parent().position - pos).normalized()
	bomb_to_add.velocity.x = direction_to_player.x * vel_scale
	get_parent().add_child(bomb_to_add)

func _on_new_explosion_timer_timeout():
	if player.position.distance_to(position) < 600 && (player.current_ability == "RocketBoost" || player.current_ability == "Grapple"):
		spawn_bomb($BossShootPosition3.position, 5)
		spawn_bomb($BossShootPosition4.position, -5)

func _on_new_bullet_timer_timeout():
	if player.position.distance_to(position) < 600 && (player.current_ability == "ArmGun" || health <= 0) && health > 0:
		if get_node_or_null("LeftTurret"):
			shoot_bullet($BossShootPosition.position)
		if get_node_or_null("RightTurret"):
			shoot_bullet($BossShootPosition2.position)

func _on_boss_hurtbox_area_entered(area):
	if area.name == "PlayerBulletHurter" && can_get_hurt_by_bullets:
		# First focus on taking out turrets
		health -= 2.5
		
		if health <= 0 && !dead:
			dead = true
			get_parent().points += 100
		
		player.get_parent().get_node("Camera").get_node("BossBar").value = health
		
func _process(delta):
	$BossHealth.value = health * 2
	
	player.get_parent().get_node("Camera").get_node("BossBar").value = health
	get_tree().get_root().get_node("Root").get_node("SaveLoadFramework").boss_health = health
	
	# Left turret
	if get_node_or_null("LeftTurret"):
		var direction_to_player = (player.position - position + player.get_parent().position - $LeftTurret.position).normalized()
		$LeftTurret.rotation = atan2(direction_to_player.y, direction_to_player.x) - (1.0 / 2.0) * PI
		
	if get_node_or_null("RightTurret"):
		var direction_to_player = (player.position - position + player.get_parent().position - $RightTurret.position).normalized()
		$RightTurret.rotation = atan2(direction_to_player.y, direction_to_player.x) - (1.0 / 2.0) * PI
	
	var target_pos = start_pos
	var no_bob = false
	bob_x += 0.01 * delta * 60
	
	if health <= 0 && position.y > -1250:
		save_load_framework.end_special_music()
	
	if (get_node_or_null("LeftTurret") || get_node_or_null("RightTurret")) && player.current_ability == "ArmGun":
		get_parent().get_node("Player").get_node("Camera").set_objective_text("Take out the control tower turrets")
	elif (!get_node_or_null("LeftTurret") && !get_node_or_null("RightTurret")) && player.current_ability == "ArmGun":
		get_parent().get_node("Player").get_node("Camera").set_objective_text("Crash the control tower into the roof")
		
	if can_get_hurt_by_bullets:
		get_parent().get_node("Player").get_node("Camera").set_objective_text("Follow the control tower to the next floor")
		
	if player.position.y < -450:
		get_parent().get_node("Player").get_node("Camera").set_objective_text("Shoot the damaged spot on the blast shield")
		
	if health <= 0:
		get_parent().get_node("Player").get_node("Camera").set_objective_text("Enter the control tower and unlock the elevator")
	
	if player_in_final_area && Input.is_action_just_pressed("interact"):
		get_parent().get_node("ElevatorWalkBarrier").get_node("CollisionShape2D").disabled = true
		get_parent().get_node("ElevatorPressE").visible = true
		
		elevator_enabled = true
		
	if elevator_enabled && player.position.y < -450:
		get_parent().get_node("Player").get_node("Camera").set_objective_text("Return to the elevator")
		
	elif elevator_enabled:
		get_parent().get_node("Player").get_node("Camera").set_objective_text("")
	
	if (!external_special_music_player.stream || external_special_music_player.playing == false) && health > 0:
		if save_load_framework.boss_music_ind == -1:
			save_load_framework.start_special_music()
			external_special_music_player.stream = boss_fight_intro
			external_special_music_player.play()
			save_load_framework.boss_music_ind = 0
		elif (save_load_framework.boss_music_ind == -1 || save_load_framework.boss_music_ind == 0) && health > 0:
			external_special_music_player.stream = boss_fight_loop
			external_special_music_player.play()
		else:
			external_special_music_player.stream = boss_fight_outro
			external_special_music_player.play()
			save_load_framework.boss_music_ind = 1
	
	if !player.current_ability == "Weapon":
		dropped_enemies = false
	elif !dropped_enemies:
		dropped_enemies = true
		$MeleSpawnTimer.start()
		get_parent().get_node("DoorOpenAnimation").play("Open")
		get_parent().get_node("DoorOpenAnimationTop").play("Open")
			
	if health < 50:
		get_tree().get_root().get_node("Root").get_node("SaveLoadFramework").boss_fifty_percent = true
		
	if health < 48:
		$BossHealth.visible = true
			
	if health < 50 && position.distance_to((start_pos + $FiftyPercentPos.position)) > 10 && health > 0:
		get_parent().get_node("BossHook1").get_node("Area2D").get_node("CollisionShape2D").disabled = false
		position += (start_pos + $FiftyPercentPos.position - position).normalized() * delta * 60
		no_bob = true
		
	if health < 50 && !position.distance_to((start_pos + $FiftyPercentPos.position)) > 10 && health > 0:
		target_pos = $FiftyPercentPos.position
	
	if position.distance_to((start_pos + $FiftyPercentPos.position)) < 30:
		if !get_parent().get_node("DrawbridgeAnimationPlayer").is_playing() && !finished_down:
			finished_down = true
			get_parent().get_node("DrawbridgeAnimationPlayer").play_backwards("DrawbridgeUp")
	else:
		if !get_parent().get_node("DrawbridgeAnimationPlayer").is_playing() && !finished_up:
			finished_up = true
			get_parent().get_node("DrawbridgeAnimationPlayer").play("DrawbridgeUp")
	
	if health <= 0:
		get_parent().get_node("BossHook2").get_node("Area2D").get_node("CollisionShape2D").disabled = false
		get_parent().boss = false
		
		if !bridge_opened:
			$DrawbridgeAnimationPlayer.play("OpenBridge")
			bridge_opened = true
		
	if player.current_ability == "Grapple" || player.current_ability == "RocketBoost":
		target_pos.y += has_ability_time + has_weapon_time
		has_ability_time -= 0.2 * delta * 60
		if has_weapon_time > 0:
			has_weapon_time -= 0.05 * delta * 60
	if player.current_ability == "ArmGun" || player.current_ability == "Weapon":
		target_pos.y += has_weapon_time + has_ability_time
		has_weapon_time += 0.04 * delta * 60
		if has_ability_time < 0:
			has_ability_time += 0.1 * delta * 60

	if health > 50 && !no_bob:
		position += (Vector2(target_pos.x, target_pos.y + sin(bob_x) * 10) - position) * 0.01


func _on_mele_spawn_timer_timeout():
	spawn_mele($MeleSpawn.position)
	get_parent().get_node("DoorOpenAnimation").play("Close")
	get_parent().get_node("DoorOpenAnimationTop").play("Close")

func _on_enable_elevator_area_area_entered(area):
	if area.name == "PlayerHurtbox":
		player_in_final_area = true

func _on_enable_elevator_area_area_exited(area):
	if area.name == "PlayerHurtbox":
		player_in_final_area = false
