extends Control
var game: Node3D

func _process(_delta):
	queue_redraw()

func point(pos: Vector3) -> Vector2:
	return Vector2(108 + pos.x * 3.6, 124 + pos.z * 3.6)

func _draw():
	if not is_instance_valid(game) or not game.started:
		return
	draw_style_box(panel(), Rect2(0, 0, 216, 248))
	draw_rect(Rect2(24, 23, 168, 202), Color("536479"), false, 2)
	for obstacle in game.obstacles:
		var at = point(obstacle.position)
		draw_rect(Rect2(at, Vector2(obstacle.size.x, obstacle.size.z) * 3.6), Color("697e90"))
	for enemy in game.enemies:
		draw_circle(point(enemy.node.position), 2.5, Color("ff6464"))
	for pickup in game.pickups:
		draw_circle(point(pickup.node.position), 2, Color("efcf7d"))
	draw_circle(point(game.reactor.position), 4, Color("ffd260"))
	draw_circle(point(game.ship.position), 5, Color("7bffa9"))
	draw_circle(point(game.player.position), 4, Color("6ef0ff"))

func panel() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.03, 0.05, 0.85)
	style.border_color = Color("3e6578")
	style.set_border_width_all(1)
	return style
