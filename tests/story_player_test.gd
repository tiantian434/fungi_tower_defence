extends SceneTree
var failures: int = 0
var completions: int = 0

func _initialize() -> void:
	node_added.connect(func(node: Node) -> void:
		if node is GameAudio:
			node.preferences_path = "res://.artifact_work/story-input-audio.cfg"
			node.effects_volume = 0.0
			node.music_volume = 0.0)
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	for chapter: int in range(1, 5):
		var player := StoryPlayer.open(root, chapter)
		_check(not player.sequence.title.is_empty() and not player.sequence.caption.is_empty(), "four chapters have narrative placeholders")
		player.finished.connect(func() -> void: completions += 1)
		player.advance()
		player.finish()
		await process_frame
	_check(completions == 4, "advance and skip complete each placeholder exactly once")
	var sequence := StorySequence.new()
	sequence.frames = [PlaceholderTexture2D.new(), PlaceholderTexture2D.new(), PlaceholderTexture2D.new()]
	sequence.frame_seconds = PackedFloat32Array([0.1, 0.2])
	var player := StoryPlayer.new()
	player.sequence = sequence
	root.add_child(player)
	paused = true
	player._process(0.11)
	_check(player.frame_index == 1, "configured frame durations advance while tree paused")
	player._toggle_play()
	player._process(1.0)
	_check(player.frame_index == 1, "manual pause holds image")
	player.advance()
	_check(player.frame_index == 2, "manual advance works while paused")
	player._toggle_play()
	player._process(100.0)
	_check(not player._finished, "last image waits for explicit continue")
	player.finished.connect(func() -> void: completions += 1)
	player.finish()
	player.finish()
	await process_frame
	_check(completions == 5, "skip cannot double-complete image sequence")
	paused = false
	await _check_focused_controls(sequence)
	print("STORY PLAYER failures=", failures)
	quit(0 if failures == 0 else 1)


func _check_focused_controls(sequence: StorySequence) -> void:
	var player := StoryPlayer.new()
	player.sequence = sequence
	player.playing = false
	root.add_child(player)
	player.advance()
	await process_frame
	var slider := player.find_children("*", "HSlider", true, false)[0] as HSlider
	slider.value = 50
	slider.grab_focus()
	_key(KEY_LEFT)
	await process_frame
	_check(player.frame_index == 1 and slider.value == 45, "focused volume slider uses Left without changing story frame")
	var mute_button := slider.get_parent().get_node("Toggle") as Button
	mute_button.grab_focus()
	_key(KEY_SPACE)
	await process_frame
	_check(player.frame_index == 1 and slider.value == 0, "focused mute button uses Space without skipping a frame")
	player._next.grab_focus()
	_key(KEY_SPACE)
	await process_frame
	_check(player.frame_index == 2, "focused continuation still advances with Space")
	var last_playing: bool = player.playing
	_key(KEY_P)
	_check(player.playing == last_playing, "last frame waiting state cannot be toggled by the disabled play shortcut")
	player.finish()
	await process_frame


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
