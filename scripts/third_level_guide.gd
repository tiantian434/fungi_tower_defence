class_name ThirdLevelGuide
extends SecondLevelGuide

const THIRD_TEXTS: Dictionary = {
	&"opening": "三个角落的记忆碎片从开局可见。让与小画家连通的花海覆盖目标，累计收集5秒；顺序不限，也可双线探索。",
	&"nutrition_returned": "补给已送回小画家。公文包能支持继续生长。\n先接通沿途资源，再把花海延伸到记忆碎片。",
	&"fragment_collected": "碎片已永久保留，断路不会丢失；未完成目标失联时暂停计时，接通后继续。",
	&"armored": "重装绘图机的护甲会削减普通伤害。可先把前沿铅笔炮台改装为橡皮炮台，再继续建设；改装期间炮台停火。",
}


func _event_text(event_id: StringName) -> String:
	return String(THIRD_TEXTS[event_id]) if THIRD_TEXTS.has(event_id) else super._event_text(event_id)
