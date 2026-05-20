# 冬瓜兄弟：对象和行为列表

## 1. 对象列表

| 对象名称 | 类型 | 关键属性 | 核心职责 |
|---|---|---|---|
| PlayerActor | 角色对象 | hp、speed、pickup_radius、buffs | 处理输入、移动、受伤、死亡、拾取 |
| PlayerStats | 数据对象 | base_stats、runtime_modifiers | 统一计算玩家最终属性 |
| WeaponController | 控制器 | unlocked_weapons、weapon_slots | 管理玩家持有武器和释放节奏 |
| WeaponRuntime | 运行时对象 | level、cooldown_timer | 表示一把武器的当前状态 |
| WeaponConfig | 配置对象 | damage、cooldown、type | 定义武器静态规则 |
| Projectile | 战斗对象 | damage、speed、pierce | 执行飞行、命中和销毁 |
| EnemyActor | 敌人对象 | hp、ai_type、damage | 执行追击、攻击、死亡 |
| EnemyConfig | 配置对象 | hp、speed、drop_exp | 定义敌人静态规则 |
| EliteEnemy | 敌人对象 | extra_skill、reward_bonus | 表示强化敌人 |
| BossActor | 敌人对象 | phase、skill_set | 表示终局 Boss 及阶段机制 |
| SpawnManager | 系统对象 | timer、wave_index、max_alive | 按波次刷怪 |
| WaveConfig | 配置对象 | time_range、enemy_pool | 定义每个阶段刷怪规则 |
| DropItem | 资源对象 | drop_type、value | 被玩家拾取并结算收益 |
| LevelSystem | 系统对象 | current_exp、level | 管理经验、升级和选项生成 |
| UpgradeOption | 数据对象 | id、type、weight | 表示一次升级候选 |
| HUDController | UI 对象 | hp_bar、exp_bar、timer | 更新常驻战斗信息 |
| UpgradePanel | UI 对象 | option_cards | 展示三选一 |
| PauseMenu | UI 对象 | buttons | 处理暂停和设置入口 |
| ResultPanel | UI 对象 | stats、actions | 展示胜负结算 |
| GameStateManager | 系统对象 | current_state | 切换菜单、战斗、暂停、结算 |
| ConfigRepo | 服务对象 | weapon_db、enemy_db | 提供统一配置读取 |
| SaveService | 服务对象 | settings、meta_progress | 保存设置与轻量进度 |
| AudioService | 服务对象 | bgm_bus、sfx_bus | 播放音频反馈 |
| EffectPool | 服务对象 | hit_fx、death_fx | 管理特效对象池 |
| EventBus | 服务对象 | signals | 广播跨模块事件 |

## 2. 行为列表

| 行为编号 | 对象 | 行为名称 | 触发条件 | 结果 |
|---|---|---|---|---|
| BH-01 | PlayerActor | 移动 | 玩家按下方向键 | 更新位置并播放移动动画 |
| BH-02 | PlayerActor | 受伤 | 被敌人接触或技能命中 | 扣血、闪白、触发无敌时间 |
| BH-03 | PlayerActor | 死亡 | 当前生命值小于等于 0 | 广播失败事件并禁用输入 |
| BH-04 | WeaponController | 自动攻击 | 武器冷却结束 | 选择目标并创建攻击 |
| BH-05 | WeaponRuntime | 升级 | 选择相关升级项 | 提高等级并刷新数值 |
| BH-06 | Projectile | 飞行 | 投射物被创建 | 按方向移动直到命中或超时 |
| BH-07 | Projectile | 命中 | 进入敌人碰撞区域 | 结算伤害，更新穿透次数 |
| BH-08 | EnemyActor | 追击 | 玩家进入感知范围 | 朝玩家移动 |
| BH-09 | EnemyActor | 攻击 | 与玩家接触或到达技能条件 | 对玩家造成伤害 |
| BH-10 | EnemyActor | 死亡 | 生命值归零 | 播放死亡反馈并掉落资源 |
| BH-11 | SpawnManager | 刷怪 | 到达波次刷新时刻 | 在视野外生成敌人 |
| BH-12 | SpawnManager | 切波次 | 局内时间进入新区间 | 替换敌人池与刷新频率 |
| BH-13 | SpawnManager | 召唤 Boss | 到达终局时间点 | 广播预警并刷出 Boss |
| BH-14 | DropItem | 吸附 | 玩家进入拾取范围 | 向玩家移动 |
| BH-15 | DropItem | 被拾取 | 接触玩家 | 结算经验/回血/磁吸效果 |
| BH-16 | LevelSystem | 累积经验 | 玩家拾取鲜度能量 | 增加经验并判断是否升级 |
| BH-17 | LevelSystem | 生成选项 | 玩家升级 | 从合法池里抽取 3 项 |
| BH-18 | LevelSystem | 应用升级 | 玩家选择升级项 | 更新武器或全局属性 |
| BH-19 | HUDController | 刷新状态 | 玩家生命、经验、时间变化 | 更新血条、经验条和倒计时 |
| BH-20 | PauseMenu | 暂停/恢复 | 玩家按 `Esc` | 切换游戏时间流逝状态 |
| BH-21 | ResultPanel | 展示结算 | 胜利或失败事件触发 | 显示统计并提供重开入口 |
| BH-22 | AudioService | 播放音效 | 命中、升级、死亡等事件触发 | 播放对应 SFX |
| BH-23 | EffectPool | 播放特效 | 命中、爆炸、升级事件触发 | 复用特效对象进行表现 |

## 3. 关键对象状态机

### 3.1 玩家状态
| 状态 | 说明 | 可迁移状态 |
|---|---|---|
| Idle | 未输入移动 | Move、Damaged、Dead |
| Move | 正在移动 | Idle、Damaged、Dead |
| Damaged | 受伤反馈中 | Idle、Move、Dead |
| Dead | 死亡 | 无 |

### 3.2 敌人状态
| 状态 | 说明 | 可迁移状态 |
|---|---|---|
| Spawn | 刚生成 | Seek |
| Seek | 追击玩家 | Attack、Dead |
| Attack | 造成接触伤害或释放技能 | Seek、Dead |
| Special | 执行特殊行为 | Seek、Dead |
| Dead | 死亡回收 | 无 |

### 3.3 Boss 状态
| 状态 | 说明 | 可迁移状态 |
|---|---|---|
| Intro | 入场和预警 | Phase1 |
| Phase1 | 基础技能循环 | Phase2、Dead |
| Phase2 | 增强技能循环 | Enrage、Dead |
| Enrage | 狂暴阶段 | Dead |
| Dead | 死亡 | 无 |

## 4. 关系说明

- `PlayerActor` 持有 `WeaponController`
- `WeaponController` 管理多个 `WeaponRuntime`
- `WeaponRuntime` 基于 `WeaponConfig` 运行
- `EnemyActor` 和 `BossActor` 读取 `EnemyConfig`
- `SpawnManager` 基于 `WaveConfig` 刷怪
- `LevelSystem` 通过 `UpgradeOption` 生成升级卡
- `HUDController`、`PauseMenu`、`ResultPanel` 通过 `EventBus` 订阅运行时事件
