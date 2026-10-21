extends SceneTree
## 可控浏览器后端的显示契约；不代表真实浏览器或宿主网站验收。

class WebDisplay extends GameDisplayManager:
	var browser_mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_WINDOWED
	var requested_modes: Array[DisplayServer.WindowMode] = []
	var native_restores: int = 0

	func _is_web() -> bool:
		return true

	func _web_window_mode() -> DisplayServer.WindowMode:
		return browser_mode

	func _request_web_window_mode(mode: DisplayServer.WindowMode) -> void:
		# 浏览器可能稍后接受或拒绝请求，不能提前发布成功状态。
		requested_modes.append(mode)

	func _restore_window() -> void:
		native_restores += 1


class WebMenu extends MainMenu:
	func _is_web() -> bool:
		return true


const SAVE: String = "res://.artifact_work/web-display-contract.cfg"
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _run() -> void:
	var config := ConfigFile.new()
	config.set_value("window", "fullscreen", true)
	config.set_value("window", "size", Vector2i(1600, 900))
	config.set_value("window", "position", Vector2i(300, 200))
	_check(config.save(SAVE) == OK, "fixture writes only an isolated display record")
	var saved_text := FileAccess.get_file_as_string(SAVE)
	var display := WebDisplay.new()
	display.preferences_path = SAVE
	var original_override: String = OS.get_environment("FUNGI_DISPLAY_PREFERENCES")
	OS.set_environment("FUNGI_DISPLAY_PREFERENCES", "")
	root.add_child(display)
	OS.set_environment("FUNGI_DISPLAY_PREFERENCES", original_override)
	display.set_process(false)
	_check(display.preferences_path == SAVE, "fixture actually observes the prepared fullscreen preferences path")
	_check(display.native_restores == 0, "Web startup never restores native window geometry or preferences")
	_check(display.requested_modes.is_empty(), "saved fullscreen never requests browser fullscreen at startup")
	_check(not display.is_fullscreen() and not display._fullscreen, "startup uses actual browser windowed mode despite saved fullscreen")
	var changes := [0]
	display.display_changed.connect(func() -> void: changes[0] += 1)
	display.set_fullscreen(true)
	_check(display.requested_modes == [DisplayServer.WINDOW_MODE_FULLSCREEN], "explicit fullscreen action directly requests the browser mode")
	_check(not display.is_fullscreen() and changes[0] == 0, "unconfirmed or denied request never publishes false success")
	display.browser_mode = DisplayServer.WINDOW_MODE_FULLSCREEN
	display._process(0.016)
	_check(display.is_fullscreen() and display._fullscreen and changes[0] == 1, "observation publishes browser-confirmed fullscreen")
	display.browser_mode = DisplayServer.WINDOW_MODE_WINDOWED
	display._on_window_changed()
	_check(not display.is_fullscreen() and not display._fullscreen and changes[0] == 2, "browser Escape exit synchronizes on resize")
	display.toggle_fullscreen()
	_check(display.requested_modes.size() == 2 and display.requested_modes.back() == DisplayServer.WINDOW_MODE_FULLSCREEN, "first click after external exit requests fullscreen again")
	display.browser_mode = DisplayServer.WINDOW_MODE_FULLSCREEN
	display._on_window_changed()
	display.browser_mode = DisplayServer.WINDOW_MODE_WINDOWED
	display._process(0.016)
	_check(not display._fullscreen and changes[0] == 4, "polling catches external exit even without resize")
	display.browser_mode = DisplayServer.WINDOW_MODE_FULLSCREEN
	display._process(0.016)
	display.set_fullscreen(false)
	_check(display.requested_modes.back() == DisplayServer.WINDOW_MODE_WINDOWED and display.is_fullscreen(), "exit request also waits for actual browser confirmation")
	display.browser_mode = DisplayServer.WINDOW_MODE_WINDOWED
	display._process(0.016)
	display.save_preferences()
	_check(FileAccess.get_file_as_string(SAVE) == saved_text, "Web observation and requests preserve the native preferences file")
	display.queue_free()
	await process_frame
	var navigator := CampaignNavigator.ensure(self)
	navigator.progress_store = CampaignProgressStore.new("res://.artifact_work/web-menu-contract.cfg")
	var menu := load(CampaignNavigator.MENU_SCENE).instantiate() as MainMenu
	menu.set_script(WebMenu)
	root.add_child(menu)
	for _frame: int in range(4):
		await process_frame
	_check(not menu.quit_button.visible and menu.quit_button.disabled, "Web title hides and disables application exit")
	_check(not menu.quit_button.pressed.is_connected(navigator.request_quit), "Web title cannot terminate the engine through its quit action")
	_check(menu.start_button.visible and not menu.start_button.disabled, "Web title retains an available start action")
	menu.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("WEB_DISPLAY_CONTRACT ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
