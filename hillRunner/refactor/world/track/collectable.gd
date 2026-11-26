class_name Collectable
extends Area2D
## A pickup placed in a valley. Touching it with either ball refills part of
## the boost bar. Spawned by Track as part of a chunk, so it is freed with it.

const TEXTURE: Texture2D = preload("res://refactor/visuals/Collectable.svg")

@export var boost_amount := 0.25   ## share of the boost bar refilled (0..1)
@export var radius := 40.0         ## pickup size; the SVG is scaled to fit 2x this
@export var flash_time := 0.35     ## seconds the collect flash lasts

var _taken := false
var _t := 0.0
var _flash := -1.0                 ## < 0 = not collected yet, 0..1 = flash progress


func _ready() -> void:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	monitorable = false
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var bob := Vector2(0.0, sin(_t * 3.0) * 4.0)

	if _flash < 0.0:
		_draw_icon(bob, 1.0, Color.WHITE)
		return

	var fade := 1.0 - _flash
	# 1. Quick white pop at the start
	var pop := clampf(1.0 - _flash * 3.0, 0.0, 1.0)
	if pop > 0.0:
		draw_circle(bob, radius * (1.0 + _flash), Color(1, 1, 1, pop * 0.8))
	# 2. Icon grows and fades out
	_draw_icon(bob, 1.0 + _flash * 0.8, Color(1, 1, 1, fade))
	# 3. Ring expands outward
	draw_arc(bob, radius * (1.0 + _flash * 2.0), 0.0, TAU, 48, Color(1, 1, 1, fade), 1.0 + 4.0 * fade, true)


## Draws the SVG centred on `at`, fitted inside a circle of radius * scale_by,
## keeping its aspect ratio.
func _draw_icon(at: Vector2, scale_by: float, tint: Color) -> void:
	var tex_size := TEXTURE.get_size()
	var size := tex_size * (radius * 2.0 * scale_by / maxf(tex_size.x, tex_size.y))
	draw_texture_rect(TEXTURE, Rect2(at - size * 0.5, size), false, tint)


func _on_body_entered(body: Node) -> void:
	if _taken:
		return   # SoftBall has many points, so this can fire several times
	var ball := _find_ball(body)
	if ball == null:
		return
	var player := ball.get_parent() as Player
	if player == null:
		return
	_taken = true
	player.add_boost(boost_amount)
	_play_flash()


func _play_flash() -> void:
	set_deferred("monitoring", false)   # can't change this during a physics callback
	var tween := create_tween()
	tween.tween_property(self, "_flash", 1.0, flash_time).from(0.0) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(queue_free)


static func _find_ball(node: Node) -> PlayerPhysics:
	while node:
		if node is PlayerPhysics:
			return node
		node = node.get_parent()
	return null
