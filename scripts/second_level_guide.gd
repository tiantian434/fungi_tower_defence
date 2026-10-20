class_name SecondLevelGuide
extends FirstEventGuide

const SECOND_TEXTS: Dictionary = {
	&"opening": "先按 G 接通一侧数位板，准备回收和前沿建设。\n在终端射程旁的花朵按 C 建炮台；关闭三处评价终端，让创作空间安静下来。",
	&"remains_returned": "回收物已送到碎纸机。向前建设时，请保护回收和补给路线。",
	&"nutrition_returned": "创作能量已入账。先利用两侧数位板补充能量，再向终端推进。\n前沿花朵按 C 可建炮台，炮台会攻击射程内的目标。",
	&"facility_destroyed": "这台绘图终端已停止生成，已出现的敌人仍会行动。\n趁整备时间回收、修补花径，再推进下一处目标。",
	&"silk_gnawer": "侵蚀大脑·断线型只直接攻击花径。保护运输路线，及时修复，或连接另一条道路。",
	&"junction_gnawer": "侵蚀大脑·摧花型只直接攻击花朵。保护节点，避免节点受损影响其上的设施。",
	&"swarm": "拼贴面孔正在成群靠近。进入成形阶段后，可把铅笔炮台改装为喷漆炮台，一轮拦截多个目标。",
	&"armored": "重装绘图机的护甲会削减普通和散射伤害。进入成形阶段后，可用橡皮炮台无视护甲的攻击应对。",
}


func _event_text(event_id: StringName) -> String:
	return String(SECOND_TEXTS[event_id]) if SECOND_TEXTS.has(event_id) else super._event_text(event_id)
