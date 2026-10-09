东西都在策划案里，可以直接照着做，保证代码可读性和工程规范性即可，能顺手de个bug就最好了

素材和ui都不用管现在，随便搓点占位符出来就行，asset文件夹下面有一些免费素材可以直接用，都是临时用来占位的，后面再讨论世界观画风的问题。

下面的都是gpt写的，你们做了新东西可以更新这个readme，防止别人做重了

**大方用天才程序员就好**









## 当前这一小步

一个母核、前线与后方两个菌结、三条连接，以及攻击、回收、消化三个器官，
验证「杀敌 → 回收 → 消化 → 供养」的完整资源循环。
运行后 3 秒开始一轮六个敌人的防守，敌人从两个出生点交替进入，每隔 3 秒出现一个。
器官自动射击，低库存时自动补给；本轮全部击败后显示防守成功。
母核被摧毁时停止战斗与自动供养，按 R 可以重开。
防守成功后回收与消化继续运行，尾批尸体需要再等几秒才能全部转化为营养。

| 操作 | 效果 |
| --- | --- |
| 左键点击菌结或器官 | 选择所属菌结，显示武器射程 |
| 右键或 Esc | 取消选择 |
| N | 从母核发送 1 点营养 |
| E | 模拟器官消耗 1 点营养 |
| H | 母核受到 30 点测试伤害 |
| R | 重新开始当前关卡 |

母核初始营养为 72；器官初始库存为 4，容量为 6。
取消运输会释放器官预留，并将营养退回原母核；同一笔运输只结算一次。
库存加在途供养低于 3 时，每隔 0.35 秒自动尝试补给 1 点。
手动补给可以补满容量。发送时扣除母核余额，到达时才加入器官库存。
目前供养只支持母核与器官所属菌结之间的一条直连菌丝。

## 回收与消化

敌人死亡后在落点留下尸体，默认每具含 4 点营养。前线回收器官每隔 0.6 秒
尝试领取半径 320 内最近的未领取尸体，后方必须有空余容量。
回收包先把尸体移动到前线菌结，再沿前线到后方的直连菌丝运输。
金色小点代表营养供养，紫色包代表尸体回收。

消化器官容量为 4 具，排队中的尸体和在途预留共同占用容量。
到达只加入待消化队列，每具消化 1.5 秒后才向母核收入营养。
消化器官与母核之间的连接断开时保留队列，接通后继续处理。
回收运输中断则释放预留，将尸体放回包最后到达的位置，线路接通后可以再领取。

六个敌人全部回收可收入 24 点营养，默认十二发射击消耗 12 点，获得用于后续成长的净收益。
回收半径目前是器官参数，菌域与自动扩张将在后续步骤加入。

| 设置 | 默认值 | 在编辑器哪里修改 |
| --- | --- | --- |
| 尸体价值 | 4 点营养 | basic_enemy.tscn → Remains Nutrition |
| 回收半径 | 320 | recovery_organ.tscn 根节点 |
| 回收尝试间隔 | 0.6 秒 | recycling_system.tscn → DispatchTimer |
| 尸体运输速度 | 140 | remains_packet.tscn 根节点 |
| 消化容量 / 时间 | 4 具 / 1.5 秒 | digestive_organ.tscn 根节点 / DigestTimer |
| 前线和后方线路 | 显式引用一条连接 | level_01.tscn → RecyclingSystem / RecoveryEdge |

消化器官下方的「排队 (+在途)/容量」显示预留状态，上方进度条显示消化过程。
底部界面显示回收在途、已送达、消化队列和累计收入。

## 战斗参数

| 设置 | 默认值 | 在编辑器哪里修改 |
| --- | --- | --- |
| 武器射程 / 伤害 | 300 / 12 | 菌结下的 SporeWeapon 检查器 |
| 射击间隔 | 0.8 秒 | spore_weapon.tscn → FireTimer |
| 射击营养消耗 | 每发 1 点本地库存 | scripts/spore_weapon.gd 中的 SHOT_NUTRITION |
| 敌人生命 / 移速 / 伤害 | 24 / 52 / 12 | basic_enemy.tscn 根节点检查器 |
| 敌人攻击间隔 | 1 秒 | basic_enemy.tscn → AttackTimer |
| 弹丸速度 / 寿命 | 360 / 4 秒 | spore_projectile.tscn 根节点 / LifetimeTimer |
| 本轮敌人数量 | 6 | 关卡中的 EnemySpawner 检查器 |
| 开始延迟 / 出生间隔 | 3 秒 / 3 秒 | enemy_spawner.tscn → 两个 Timer |
| 出生位置 | 左右两个位置 | level_01.tscn → World/SpawnPoints |

武器选择射程内最近的存活敌人。距离按双方的地面落点计算，弹丸从菌盖附近发射，
追踪发射时选定的目标，命中后才造成伤害。空库存时停火，有补给后自动恢复。
目标消失时弹丸消散，已经发射的营养消耗不会退回。
敌人接近母核后停下，按攻击间隔持续造成伤害；死亡后立即停止攻击并播放淡出。

## 从哪里读起

1. scenes/levels/level_01.tscn：查看编辑器中摆放好的初始结构和供养系统引用。
2. scripts/level_01.gd：输入处理、选择以及各模块的信号连接。
3. scenes/colony/attack_organ.tscn：器官外观、点击区域和六个库存格。
4. scenes/combat/spore_weapon.tscn：同一菌结上的武器，查看射程线和射击计时器。
5. scripts/spore_weapon.gd → spore_projectile.gd → basic_enemy.gd：一次射击从选敌到受伤。
6. scripts/supply_system.gd：完整的一次供养，从预留到最终结算。
7. scripts/remains_spawner.gd → recycling_system.gd → digestive_organ.gd：死亡后生成尸体、运输与消化入账。

| 模块 | 场景 | 脚本职责 |
| --- | --- | --- |
| 母核 | scenes/colony/mother_core.tscn | 生命值、可用营养、扣款与收入 |
| 菌结 | scenes/colony/hypha_node.tscn | 点击和选中反馈 |
| 菌丝 | scenes/colony/hypha_edge.tscn | 两个端点、连接线和路径位置 |
| 攻击器官 | scenes/colony/attack_organ.tscn | 本地库存、在途预留和消耗 |
| 孢子武器 | scenes/combat/spore_weapon.tscn | 选择目标、申请库存消耗、发射与射程显示 |
| 孢子弹丸 | scenes/combat/spore_projectile.tscn | 移动、命中伤害、消散与寿命清理 |
| 普通敌人 | scenes/enemies/basic_enemy.tscn | 移动、攻击母核、受伤与死亡反馈 |
| 刷怪器 | scenes/systems/enemy_spawner.tscn | 有限数量的出生、存活统计与本轮结束信号 |
| 尸体 | scenes/recycling/enemy_remains.tscn | 保存资源价值、领取与放回地面 |
| 尸体生成器 | scenes/systems/remains_spawner.tscn | 监听死亡通知，在死亡落点实例化尸体 |
| 前线回收器官 | scenes/colony/recovery_organ.tscn | 回收范围、选择与收取反馈 |
| 尸体回收包 | scenes/recycling/remains_packet.tscn | 收至前线菌结，再沿连接运输 |
| 回收系统 | scenes/systems/recycling_system.tscn | 领取、后方容量预留和一次性运输结算 |
| 后方消化器官 | scenes/colony/digestive_organ.tscn | 消化队列、在途预留和营养收入 |
| 营养包 | scenes/colony/nutrient_packet.tscn | 沿菌丝移动、到达或中断通知 |
| 供养系统 | scenes/systems/supply_system.tscn | 自动调度和一次性资源结算 |
| 界面 | scenes/ui/colony_hud.tscn | 显示库存、选中状态和运输反馈 |

## 工程约定

- 初始关卡、界面、外观和计时器放在场景中，运行时通过 PackedScene 实例化运输包、敌人、弹丸和尸体。
- 库存与武器分开；二者在同一菌结下，通过检查器引用关联。
- 参数优先通过导出属性在检查器中修改；不要在多个脚本里重复维护同一余额。
- 模型通过信号通知界面，界面只负责显示。
- 母核、菌结和敌人以落地点作为原点，用 Y 排序保持斜俯视遮挡关系；武器发射点使用局部偏移表现高度。
- 按键在 Project Settings → Input Map 中定义，测试按键暂时保留。
- GDScript 使用制表符缩进、明确类型和短函数；注释说明职责和容易误解的规则。

## 验证

资源结算测试位于 tests/supply_test.gd，可使用 Godot 执行：

覆盖连续发送的容量限制、到达前不入库、自动补给、余额不足、断线取消、
重复退款防护、目标移除、配置变更、选择操作和运输途中重开。

```text
godot --headless --path <本工程目录> --script res://tests/supply_test.gd
godot --headless --path <本工程目录> --script res://tests/combat_test.gd
godot --headless --path <本工程目录> --script res://tests/recycling_test.gd
```

战斗测试覆盖射程、命中前不扣血、一次命中、空库存停火、目标消失、弹丸寿命、
敌人接触攻击、死亡后停攻、失败后停止运行、重开，以及默认参数下完整的一轮防守。
完整防守会检查母核余额、本地库存、在途营养和已发射次数之和，
等于初始营养加已消化收入，确保回收、战斗消耗与供养结算一致。
供养测试关闭自动刷怪来单独检查物流，战斗测试中的完整防守保留默认参数。

回收测试覆盖一次死亡只生成一具尸体、重复领取、到达前不入库、消化前不收入、
容量与在途预留、断线放回、取消与删除运输包、后方连接恢复、目标移除、重开和默认参数下完整资源循环。

下一步接入菌域与引导扩张，之后增加多路径运输和分化，逐步形成完整第一关。
