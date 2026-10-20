extends SceneTree
## 跨场景的音量恢复回归：测试存档独立于玩家设置，不播放音频。

const AUDIO: PackedScene = preload("res://scenes/audio/game_audio.tscn")
const PREFS: String = "res://.artifact_work/audio-preferences-test.cfg"

var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.artifact_work"))
	_remove_preferences()
	await _test_muted_scene_replacement()
	await _test_legacy_and_invalid_settings()
	_remove_preferences()
	print("AUDIO_PREFERENCES_TEST_RESULT ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)


func _new_audio() -> GameAudio:
	var audio := AUDIO.instantiate() as GameAudio
	audio.preferences_path = PREFS
	root.add_child(audio)
	return audio


func _dispose(audio: GameAudio) -> void:
	audio.queue_free()
	await process_frame
	await process_frame


func _test_muted_scene_replacement() -> void:
	var audio := _new_audio()
	audio.set_effects_volume(0.2)
	audio.set_music_volume(0.3)
	audio.toggle_mute()
	audio.toggle_music_mute()
	_check(is_zero_approx(audio.effects_volume) and is_zero_approx(audio.music_volume),
		"Both channel mute toggles must silence their channels")
	# _exit_tree must flush the pending write even before the debounce timer fires.
	await _dispose(audio)
	var saved := ConfigFile.new()
	_check(saved.load(PREFS) == OK, "Scene disposal did not save pending audio settings")
	_check(is_equal_approx(saved.get_value("audio", "previous_effects_volume", -1.0), 0.2)
		and is_equal_approx(saved.get_value("audio", "previous_music_volume", -1.0), 0.3),
		"Muted settings lost the last audible values")
	audio = _new_audio()
	_check(is_zero_approx(audio.effects_volume) and is_zero_approx(audio.music_volume),
		"Scene replacement must retain mute until explicitly restored")
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Effects"))
		and AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")),
		"Reloaded mute must reach the independent mixer buses")
	audio.toggle_mute()
	_check(is_equal_approx(audio.effects_volume, 0.2) and is_zero_approx(audio.music_volume),
		"Unmuting effects after scene replacement must restore 20% without unmuting music")
	audio.toggle_music_mute()
	_check(is_equal_approx(audio.music_volume, 0.3), "Unmuting music must restore 30% after replacement")
	await _dispose(audio)
	audio = _new_audio()
	_check(is_equal_approx(audio.effects_volume, 0.2) and is_equal_approx(audio.music_volume, 0.3),
		"Restored values did not survive a second scene replacement")
	# Sliding to zero follows the same user-visible mute semantics.
	audio.set_effects_volume(0.45)
	audio.set_effects_volume(0.0)
	await _dispose(audio)
	audio = _new_audio()
	audio.toggle_mute()
	_check(is_equal_approx(audio.effects_volume, 0.45), "A zero slider lost the previous audible setting")
	await _dispose(audio)


func _test_legacy_and_invalid_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "effects_volume", 0.15)
	config.set_value("audio", "music_volume", 0.25)
	config.save(PREFS)
	var audio := _new_audio()
	audio.toggle_mute()
	audio.toggle_music_mute()
	audio.toggle_mute()
	audio.toggle_music_mute()
	_check(is_equal_approx(audio.effects_volume, 0.15) and is_equal_approx(audio.music_volume, 0.25),
		"Legacy nonzero preferences must migrate their own restore values")
	await _dispose(audio)
	config.clear()
	config.set_value("audio", "effects_volume", 0.0)
	config.set_value("audio", "music_volume", 0.0)
	config.set_value("audio", "previous_effects_volume", "invalid")
	config.set_value("audio", "previous_music_volume", -0.4)
	config.save(PREFS)
	audio = _new_audio()
	audio.toggle_mute()
	audio.toggle_music_mute()
	_check(is_equal_approx(audio.effects_volume, 0.7) and is_equal_approx(audio.music_volume, 0.6),
		"Missing or malformed mute recovery data must use safe defaults")
	await _dispose(audio)


func _remove_preferences() -> void:
	if FileAccess.file_exists(PREFS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PREFS))
