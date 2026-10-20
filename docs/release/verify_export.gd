extends SceneTree
## External check for the exported PCK. This file is deliberately excluded from it.
## It checks delivery integrity, not balance or a complete player playthrough.

var checks: int = 0
var failures: Array[String] = []
var qa_directory: String = ""


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	var qa_index := arguments.find("--qa-directory")
	if qa_index >= 0 and qa_index + 1 < arguments.size():
		qa_directory = arguments[qa_index + 1]
	node_added.connect(func(node: Node) -> void:
		if node is GameAudio:
			node.preferences_path = qa_directory.path_join("audio.cfg")
			node.effects_volume = 0.0
			node.music_volume = 0.0)
	_run.call_deferred()


func _run() -> void:
	if qa_directory.is_empty():
		push_error("Pass -- --qa-directory with an isolated output directory")
		quit(1)
		return
	_check(not ResourceLoader.exists("res://tests/colony_camera_test.gd"), "test scripts excluded")
	_check(not FileAccess.file_exists("res://docs/release/verify_export.gd"), "development documentation excluded")
	for chapter: int in range(1, 5):
		var sequence := load("res://resources/story/cg%d.tres" % chapter) as StorySequence
		_check(sequence != null and sequence.get_count() > 0, "CG%d dynamically loads" % chapter)
		if sequence != null:
			for shot: StoryShot in sequence.shots:
				for texture: Texture2D in shot.layers + shot.flipbook:
					_check(texture != null and texture.get_width() > 0, "CG%d texture is readable" % chapter)
	var sounds := load("res://resources/audio/sound_bank.tres") as SoundBank
	_check(sounds != null and not sounds.cues.is_empty(), "sound bank included")
	if sounds != null:
		for cue: SoundCue in sounds.cues:
			_check(cue != null and not cue.streams.is_empty(), "sound cue included")
			if cue != null:
				for stream: AudioStream in cue.streams:
					_check(stream != null and stream.get_length() > 0.0, "sound stream decodes")
	var music := load("res://resources/audio/music_library.tres") as MusicLibrary
	for id: StringName in [&"chapter_1", &"chapter_2", &"chapter_3", &"battle"]:
		var track := music.find_track(id) if music != null else null
		_check(track != null and track.stream != null and track.stream.get_length() > 0.0, "music included: " + id)
	for path: String in ["res://assets/gameplay/fallback_enemy_sheet.png", "res://assets/ui/handdrawn/controls/窗口.png"]:
		_check(ResourceLoader.exists(path) and load(path) != null, "dynamic art included: " + path)
	var navigator := CampaignNavigator.ensure(self)
	navigator.progress_store = CampaignProgressStore.new(qa_directory.path_join("campaign.cfg"))
	for scene: String in [CampaignNavigator.MENU_SCENE] + CampaignNavigator.LEVEL_SCENES:
		paused = false
		_check(change_scene_to_file(scene) == OK, "scene loads: " + scene)
		await process_frame
		await process_frame
		_check(is_instance_valid(current_scene) and current_scene.scene_file_path == scene, "scene instantiates: " + scene)
		paused = true
	paused = false
	if is_instance_valid(current_scene):
		current_scene.queue_free()
	await process_frame
	await process_frame
	print("EXPORTED_PACKAGE_CHECK ", JSON.stringify({"checks": checks, "failures": failures,
		"version": ProjectSettings.get_setting("application/config/version", "unknown")}))
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)
