# 冬瓜兄弟：对象和行为列表

## 1. 对象列表

| 对象名称 | 类型 | 关键属性 | 核心职责 |
|---|---|---|---|
| MainMenu | UI 对象 | selected_character_id、character_cards | 角色选择、开始游戏、设置 |
| CharacterConfig | 配置对象 | id、stats、texture、starting_weapon_id | 描述角色静态数据 |
| Player | 角色对象 | hp、speed、pickup_radius、materials、pending_level_ups | 移动、受伤、拾取、升级、材料管理 |
| MaterialWallet | 逻辑对象 | balance | 管理材料余额与消费 |
| WeaponController | 控制器 | owned_weapons、weapon_levels | 管理武器和自动攻击 |
| WeaponConfig | 配置对象 | damage、cooldown、type | 定义武器静态规则 |
| Projectile | 战斗对象 | damage、speed、pierce | 飞行、命中、销毁 |
| Enemy | 敌人对象 | hp、ai_type、damage、drop_materials | 追击、攻击、死亡、掉落 |
| WaveConfig | 配置对象 | time_start、time_end、enemy_pool | 定义每段波次规则 |
| DropItem | 资源对象 | drop_type、value | 经验/治疗/磁吸结算 |
| ShopController | 系统对象 | shop_options、reroll_used | 生成商店、处理购买与刷新 |
| UpgradeOption | 数据对象 | id、kind、target、shop_price | 表示升级或商店候选 |
| HUD | UI 对象 | hp_bar、exp_bar、info_label | 显示战斗信息 |
| LevelUpPanel | UI 对象 | options | 展示升级三选一 |
| ShopPanel | UI 对象 | options、material_label | 展示商店和购物交互 |
| ResultPanel | UI 对象 | label、stats | 展示胜负结算 |
| GameState | 系统对象 | current_state | 管理主菜单、战斗、升级、商店等状态 |
| ConfigRepo | 服务对象 | character_db、enemy_db、wave_db、upgrade_db | 提供统一配置读取与候选生成 |

## 2. 行为列表

| 行为编号 | 对象 | 行为名称 | 触发条件 | 结果 |
|---|---|---|---|---|
| BH-01 | MainMenu | 选择角色 | 玩家点击角色卡片 | 更新当前角色和摘要 |
| BH-02 | MainMenu | 开始游戏 | 玩家点击开始 | 发出 `start_game_requested(character_id)` |
| BH-03 | Player | 配置角色 | 场景生成玩家 | 注入贴图、属性、初始武器 |
| BH-04 | Player | 移动 | 玩家按方向键 | 更新位置和朝向 |
| BH-05 | Player | 受伤 | 被敌人接触或技能命中 | 扣血并进入短暂无敌 |
| BH-06 | Player | 获得经验 | 拾取经验物 | 累积经验并可能增加待升级次数 |
| BH-07 | Player | 获得材料 | 敌人死亡结算 | 材料余额增加 |
| BH-08 | Player | 消费材料 | 商店购买或刷新 | 材料余额减少 |
| BH-09 | WeaponController | 初始化武器 | 玩家创建后 `setup` | 解锁角色初始武器 |
| BH-10 | WeaponController | 自动攻击 | 武器冷却结束 | 选择目标并释放攻击 |
| BH-11 | Enemy | 追击 | 玩家进入感知范围 | 朝玩家移动 |
| BH-12 | Enemy | 攻击 | 接触或达到技能条件 | 对玩家造成伤害 |
| BH-13 | Enemy | 死亡 | 生命值归零 | 掉经验并直接发放材料 |
| BH-14 | DropItem | 被拾取 | 接触玩家 | 结算经验、回血或磁吸 |
| BH-15 | GameRoot | 切换波次 | 时间进入新区间 | 更新波次索引并决定是否进商店 |
| BH-16 | GameRoot | 进入升级 | 玩家升级 | 暂停战斗并展示升级面板 |
| BH-17 | GameRoot | 进入商店 | 前 5 波结束 | 暂停战斗并展示商店面板 |
| BH-18 | ShopController | 生成商品 | 打开商店 | 生成 3 个合法候选 |
| BH-19 | ShopController | 购买商品 | 玩家点击商品 | 扣费并应用升级 |
| BH-20 | ShopController | 刷新商店 | 玩家点击刷新 | 扣费并重置商品列表 |
| BH-21 | HUD | 刷新显示 | 时间/血量/经验/材料变化 | 更新文本与进度条 |
| BH-22 | ResultPanel | 展示结算 | 胜利或失败 | 展示统计并提供重开入口 |

## 3. 关键对象状态

### 3.1 GameState

| 状态 | 说明 |
|---|---|
| MAIN_MENU | 主菜单 |
| IN_GAME | 战斗中 |
| PAUSED | 暂停 |
| LEVEL_UP | 升级选择中 |
| SHOP | 商店中 |
| VICTORY | 胜利结算 |
| DEFEAT | 失败结算 |

### 3.2 ShopController 状态

| 状态 | 说明 |
|---|---|
| Closed | 商店未开启 |
| Open | 商店已开启，可购买 |
| Rerolled | 本店已刷新过 |
| ClosedToBattle | 玩家点击继续，返回战斗 |
