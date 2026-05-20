extends Area2D

var exp_value := 1
var elite_drop := false
var drop_type := "exp"  # "exp", "heal", "magnet"
var attract_speed := 260.0
var target: Node = null

func setup(exp_amount: int, elite: bool, dtype: String = "exp") -> void:
	exp_value = exp_amount
	elite_drop = elite
	drop_type = dtype
	_add_visual()
	_add_collision()

func _add_visual() -> void:
	var poly := Polygon2D.new()
	match drop_type:
		"heal":
			poly.polygon = PackedVector2Array([
				Vector2(-7, -7),
				Vector2(7, -7),
				Vector2(7, 7),
				Vector2(-7, 7)
			])
			poly.color = Color(1, 0.3, 0.35, 1)
		"magnet":
			poly.polygon = PackedVector2Array([
				Vector2(-8, -8),
				Vector2(8, -8),
				Vector2(8, 8),
				Vector2(-8, 8)
			])
			poly.color = Color(0.4, 0.7, 1, 1)
		_:
			poly.polygon = PackedVector2Array([
				Vector2(-6, -6),
				Vector2(6, -6),
				Vector2(6, 6),
				Vector2(-6, 6)
			])
			poly.color = Color("#ffb36b") if elite_drop else Color("#86ff9a")
	add_child(poly)

func _add_collision() -> void:
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 8.0 if drop_type == "magnet" else (7.0 if drop_type == "heal" else 6.0)
	collision.shape = shape
	add_child(collision)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var dist := global_position.distance_to(target.global_position)
	var pickup_distance: float = target.get_pickup_radius()
	# Magnet drops increase pickup radius temporarily
	if drop_type == "magnet" and dist < pickup_distance * 2.5:
		global_position = global_position.move_toward(target.global_position, attract_speed * 1.5 * delta)
		if dist < 12.0:
			_activate_magnet()
			_despawn()
		return
	if dist <= pickup_distance:
		_apply_effect()
		_despawn()
		return
	if dist < 220.0:
		global_position = global_position.move_toward(target.global_position, attract_speed * delta)

func _apply_effect() -> void:
	if not is_instance_valid(target):
		return
	match drop_type:
		"heal":
			var heal_amount := 20
			target.current_hp = min(target.max_hp, target.current_hp + heal_amount)
			EventBus.player_healed.emit(heal_amount)
		"magnet":
			_activate_magnet()
		_:
			target.add_exp(exp_value)

func _activate_magnet() -> void:
	if not is_instance_valid(target):
		return
	# Pull all drops toward player briefly
	var root := target.get_parent()
	if root and root.has_node("DropContainer"):
		for child in root.get_node("DropContainer").get_children():
			if child == self or not is_instance_valid(child):
				continue
			if child.has_method("_force_attract"):
				child._force_attract()
	# Also instant-attract nearby drops
	for child in root.get_node("DropContainer").get_children():
		if child == self or not is_instance_valid(child):
			continue
		var d: float = target.global_position.distance_to(child.global_position)
		if d < 300.0:
			child.global_position = child.global_position.move_toward(target.global_position, 400.0 * 0.5)

func _force_attract() -> void:
	# Called by magnet to pull this drop in
	attract_speed *= 2.5

func _despawn() -> void:
	if is_queued_for_deletion():
		return
	call_deferred("queue_free")
