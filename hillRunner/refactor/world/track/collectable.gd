class_name Collectable
extends Area2D
## A pickup placed in a valley. Touching it with either ball refills part of
## the boost bar. Spawned by Track as part of a chunk, so it is freed with it.

@export var boost_amount := 0.25   ## share of the boost bar refilled (0..1)
@export var radius := 20.0
@export var color := Color("#FFD166")

var _taken := false
var _t := 0.0


func _ready() -> void:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	monitorable = false   # nothing needs to detect the pickup itself
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var bob := Vector2(0.0, sin(_t * 3.0) * 4.0)   # gentle bobbing
	draw_circle(bob, radius * 0.7, color)
	draw_arc(bob, radius * 0.7, 0.0, TAU, 32, Color.WHITE, 3.0, true)


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
	queue_free()


## The physics bodies sit below the ball node (RigidBall's Body, SoftBall's
## points), so walk up the tree to find the PlayerPhysics they belong to.
static func _find_ball(node: Node) -> PlayerPhysics:
	while node:
		if node is PlayerPhysics:
			return node
		node = node.get_parent()
	return null
