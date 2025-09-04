extends Node2D

# divide by CELL_SIZE  to generate grid size
const CELL_SIZE: int = 32   
#speed of snake    
var step_time: float = 0.5      
		  

# --- Runtime state ---
var grid_size: Vector2i
var snake: Array[Vector2i] = []
var dir: Vector2i = Vector2i.RIGHT
var next_dir: Vector2i = Vector2i.RIGHT
var food: Vector2i
var alive: bool = true
var paused: bool = false
var wrap: bool = true    
var score: int = 0
var accumulator: float = 0.0

var rng := RandomNumberGenerator.new()


const SAVE_PATH := "user://high_score.tres"
var high_score: HighScore

func _ready() -> void:
	rng.randomize()
	_update_grid_from_viewport()
	_load_high_score()
	_reset()
	set_process(true)
	get_viewport().size_changed.connect(_on_viewport_resized)

func _on_viewport_resized() -> void:
	_update_grid_from_viewport()
	queue_redraw()

func _update_grid_from_viewport() -> void:
	var px_size: Vector2 = get_viewport_rect().size
	grid_size = Vector2i(
		int(floor(px_size.x / float(CELL_SIZE))),
		int(floor(px_size.y / float(CELL_SIZE)))
	)
	print(px_size)
	print(grid_size)
	print(CELL_SIZE)

func _reset() -> void:
	alive = true
	paused = false
	score = 0
	dir = Vector2i.RIGHT
	next_dir = dir
	var cx: int = grid_size.x / 2
	var cy: int = grid_size.y / 2
	snake = [
		Vector2i(cx, cy),
		Vector2i(cx - 1, cy),
		Vector2i(cx - 2, cy)
	]
	_spawn_food()
	accumulator = 0.0
	queue_redraw()

func _spawn_food() -> void:
	var free: Array[Vector2i] = []
	for y in grid_size.y:
		for x in grid_size.x:
			var p := Vector2i(x, y)
			if p not in snake:
				free.append(p)
	if free.is_empty():
		alive = false
		return
	food = free[rng.randi_range(0, free.size() - 1)]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up") and dir != Vector2i.DOWN and not paused:
		next_dir = Vector2i.UP
	elif event.is_action_pressed("ui_down") and dir != Vector2i.UP and not paused:
		next_dir = Vector2i.DOWN
	elif event.is_action_pressed("ui_left") and dir != Vector2i.RIGHT and not paused:
		next_dir = Vector2i.LEFT
	elif event.is_action_pressed("ui_right") and dir != Vector2i.LEFT and not paused:
		next_dir =  Vector2i.RIGHT
	elif event.is_action_pressed("ui_accept"): 
		if not alive:
			_reset()
		else:
			paused = !paused
			queue_redraw()
	elif event.is_action_pressed("ui_restart"): 
		if paused or not alive:
			_reset()
			paused = false
	elif event.is_action_pressed("ui_clear_high_score"): 
		high_score.best_score = 0
		_save_high_score()
		queue_redraw()

func _process(delta: float) -> void:
	if not alive or paused:
		return
	accumulator += delta
	while accumulator >= step_time:
		accumulator -= step_time
		dir = next_dir
		_step()

func _step() -> void:
	var head: Vector2i = snake[0]
	var new_head := head + dir

	if wrap:
		new_head.x = (new_head.x + grid_size.x) % grid_size.x
		new_head.y = (new_head.y + grid_size.y) % grid_size.y
	else:
		if new_head.x < 0 or new_head.y < 0 \
		or new_head.x >= grid_size.x or new_head.y >= grid_size.y:
			_die()
			return

	if new_head in snake:
		_die()
		return

	snake.insert(0, new_head)
	if new_head == food:
		score += 1
		if score > high_score.best_score:
			high_score.best_score = score
			_save_high_score()
		if score % 2 == 0:
			step_time = max(0.10, step_time - 0.05)
			print(step_time)
		_spawn_food()
	else:
		snake.pop_back()

	queue_redraw()

func _die() -> void:
	alive = false
	queue_redraw()

func _draw() -> void:
	var board_px := Vector2(grid_size) * float(CELL_SIZE)
	draw_rect(Rect2(Vector2.ZERO, board_px), Color(1, 1, 1), true)

	# grid lines
	for x in grid_size.x + 1:
		var xx := float(x * CELL_SIZE)
		draw_line(Vector2(xx, 0), Vector2(xx, board_px.y), Color(0, 0, 0.9, 0.15), 1.0)
	for y in grid_size.y + 1:
		var yy := float(y * CELL_SIZE)
		draw_line(Vector2(0, yy), Vector2(board_px.x, yy), Color(0, 0, 0.9, 0.15), 1.0)

	# food
	var food_rect := Rect2(Vector2(food) * float(CELL_SIZE), Vector2(CELL_SIZE, CELL_SIZE)).grow(-2)
	draw_rect(food_rect, Color(1.0, 0.35, 0.35), true)

	# snake
	for i in snake.size():
		var p: Vector2i = snake[i]
		var r := Rect2(Vector2(p) * float(CELL_SIZE), Vector2(CELL_SIZE, CELL_SIZE)).grow(-2)
		var c := Color(0, 0, 0) if i == 0 else Color(0, 0, 0, 0.5)
		draw_rect(r, c, true)

	# HUD
	var font: Font = ThemeDB.fallback_font
	var size: int = 20
	var margin := 8.0

	draw_string(
		font,
		Vector2(margin, size + margin),
		"Score: %d (Best: %d)" % [score, high_score.best_score],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		size,
		Color.BLACK
	)

	# Game Over menu
	if not alive:
		var big := int(round(size * 1.3))
		var msg := "Game Over\nPress Space to Restart\nPress H to Reset High Score"
		draw_rect(Rect2(Vector2.ZERO, board_px), Color(1, 1, 1, 0.8), true)
		_draw_multiline_centered(font, msg, big, board_px)

	# Pause menu
	if paused and alive:
		var big := int(round(size * 1.5))
		var msg := "Paused\nPress Space to Continue\nPress R to Restart\nPress H to Reset High Score"
		draw_rect(Rect2(Vector2.ZERO, board_px), Color(1, 1, 1, 0.8), true)
		_draw_multiline_centered(font, msg, big, board_px)

# Multiple line text logic 
func _draw_multiline_centered(font: Font, text: String, size: int, area: Vector2) -> void:
	var lines := text.split("\n")
	var total_height := lines.size() * size * 1.2
	var start_y := (area.y - total_height) * 0.5
	for i in lines.size():
		var line := lines[i]
		var text_size := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size)
		var pos := Vector2(
			(area.x - text_size.x) * 0.5,
			start_y + i * size * 1.2
		)
		draw_string(font, pos, line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, Color(0,0,0,0.9))

# Saving Logic 
func _load_high_score() -> void:
	if ResourceLoader.exists(SAVE_PATH):
		high_score = ResourceLoader.load(SAVE_PATH) as HighScore
	else:
		high_score = HighScore.new()
		_save_high_score()

func _save_high_score() -> void:
	ResourceSaver.save(high_score, SAVE_PATH)
