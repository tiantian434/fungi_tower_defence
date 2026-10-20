extends SceneTree
## 独立配置验证旧版进度迁移，以及“解锁下一章”和“看过剧情”是两个状态。

const SAVE: String = "user://qa_campaign_story_progress.cfg"
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)


func _run() -> void:
	var legacy := ConfigFile.new()
	legacy.set_value("campaign", "version", 1)
	legacy.set_value("campaign", "highest_unlocked", 2)
	legacy.set_value("campaign", "continue_level", 2)
	legacy.set_value("campaign", "completed", false)
	legacy.save(SAVE)
	var store := CampaignProgressStore.new(SAVE)
	_check(store.load_progress(), "version-one save is accepted")
	_check(store.get_snapshot().highest_unlocked == 2 and store.get_snapshot().continue_level == 2,
		"legacy migration preserves unlocked chapter and continue position")
	_check(store.has_seen_story(1) and not store.has_seen_story(2), "legacy next chapter retains its unseen story")
	_check(store.record_story_seen(2), "explicit continue or skip records seen chapter")
	var fresh := CampaignProgressStore.new(SAVE)
	_check(fresh.load_progress() and fresh.has_seen_story(2), "seen story survives a new store instance")
	_check(fresh.record_victory(2) and not fresh.has_seen_story(3), "victory unlock does not silently mark following story seen")
	_check(fresh.record_story_seen(3) and fresh.record_victory(3) and fresh.record_story_seen(4), "final chapters and ending can be recorded")
	_check(fresh.start_new_game() and fresh.get_snapshot().seen_stories.is_empty(), "new game resets story state alongside chapter progress")
	_check(not fresh.record_story_seen(0) and not fresh.record_story_seen(5), "invalid story identifiers cannot enter the save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("CAMPAIGN_STORY_RESULT ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
