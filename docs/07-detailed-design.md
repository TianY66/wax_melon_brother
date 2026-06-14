# 冬瓜兄弟：详细设计

## 1. 设计目标

本文档定义当前版本关键模块的结构、字段、流程与规则，重点覆盖双角色、材料经济、6 段波次和商店逻辑。

## 2. 角色配置设计

### 2.1 CharacterConfig 结构

```json
{
  "id": "winter_melon_brother_2",
  "name": "冬瓜二哥",
  "description": "机动暴击流，走位更快更狠。",
  "texture_path": "res://imgs/01_角色/角色_冬瓜二哥.png",
  "visual_scale": [0.083, 0.083],
  "visual_offset": [0, -12],
  "base_move_speed": 250,
  "max_hp": 82,
  "pickup_radius": 62,
  "damage_bonus_pct": 0.05,
  "cooldown_reduction_pct": 0.0,
  "crit_rate": 0.1,
  "starting_weapon_id": "knife_disc"
}
```

### 2.2 当前角色原型

| 角色 | max_hp | move_speed | pickup_radius | crit_rate | damage_bonus_pct | starting_weapon_id |
|---|---:|---:|---:|---:|---:|---|
| 冬瓜大哥 | 110 | 215 | 78 | 0.00 | 0.00 | winter_seed_burst |
| 冬瓜二哥 | 82 | 250 | 62 | 0.10 | 0.05 | knife_disc |

## 3. Player 运行时设计

### 3.1 核心字段

| 字段 | 类型 | 说明 |
|---|---|---|
| character_id | String | 当前角色 ID |
| current_hp | int | 当前生命 |
| max_hp | int | 最大生命 |
| base_move_speed | float | 基础移速 |
| pickup_radius | float | 拾取半径 |
| damage_bonus_pct | float | 全局增伤 |
| cooldown_reduction_pct | float | 冷却缩减 |
| crit_rate | float | 暴击率 |
| exp | int | 当前经验槽 |
| level | int | 当前等级 |
| pending_level_ups | int | 待处理升级次数 |
| materials | int | 当前材料余额 |
| starting_weapon_id | String | 初始武器 |

### 3.2 升级处理规则

1. `add_exp` 累加经验
2. 若超过阈值，循环结算多个等级
3. 每升 1 级，`pending_level_ups += 1`
4. 升级面板每选 1 次，`pending_level_ups -= 1`
5. 若仍有待处理升级，则继续弹出升级面板

## 4. WeaponController 设计

### 4.1 初始化规则

- `WeaponController.setup(player, starting_weapon_id)`
- 若传入角色初始武器，则使用角色武器开局
- 不再写死默认武器

### 4.2 升级候选类型

- `unlock_weapon`
- `weapon_upgrade`
- `global`

## 5. 敌人与材料设计

### 5.1 敌人配置扩展

每个敌人新增：

```json
"drop_materials": 2
```

### 5.2 当前材料掉落

| 敌人 | drop_materials |
|---|---:|
| knife_mite | 1 |
| fork_hound | 1 |
| pressure_tank | 2 |
| oil_cannon_ball | 1 |
| self_destruct_cleaner | 1 |
| elite_cold_box | 4 |
| elite_stir_drone | 5 |
| boss_control_core | 0 |

### 5.3 结算规则

- 经验：继续以地面掉落物存在
- 材料：击杀时直接入账

## 6. 波次设计

### 6.1 6 段波次

| Wave | 时间区间 | 刷怪池概览 |
|---|---|---|
| 1 | `0-90` | knife_mite |
| 2 | `90-180` | knife_mite, fork_hound |
| 3 | `180-270` | knife_mite, fork_hound |
| 4 | `270-360` | + pressure_tank |
| 5 | `360-450` | + oil_cannon_ball |
| 6 | `450-600` | + self_destruct_cleaner |

### 6.2 波间规则

- Wave 1~5 结束进入商店
- Wave 6 不再进入商店

### 6.3 Boss 节奏

- `540s`：发出预警
- `570s`：刷新 Boss
- `600s`：结算

## 7. 商店设计

### 7.1 商店状态

- `GameState.State.SHOP`

### 7.2 商品来源

- 候选池复用升级池合法性规则
- 仅从当前玩家可获得的项中生成

### 7.3 价格规则

| 分类 | 规则 | 价格 |
|---|---|---:|
| 解锁武器 | tier1 | 36 |
| 解锁武器 | tier2 | 52 |
| 武器升级 | tier1 | 32 |
| 武器升级 | tier2 | 48 |
| 全局强化 | tier1 | 26-30 |
| 全局强化 | tier2 | 44 |
| 刷新 | 每店 1 次 | 20 |

### 7.4 交互规则

- 每店 3 个商品
- 可购买多个商品
- 已购商品显示“已售出”
- 买不起则按钮禁用
- 每个商店只能刷新 1 次

### 7.5 刷新规则

优先避开当前商店已有商品；若候选不足，则允许回退到完整候选池补足。

## 8. 升级与商店先后规则

### 8.1 波末处理顺序

1. 记录待进入商店的波次
2. 自动收集场上经验掉落
3. 若触发升级，则先走升级流程
4. 所有待升级项处理完成后，再进入商店

### 8.2 战斗冻结规则

- 升级面板：`LEVEL_UP` + 暂停树
- 商店面板：`SHOP` + 暂停树

## 9. HUD 设计

### 9.1 当前显示信息

- `HP`
- `EXP`
- `Lv`
- `Wave X/6`
- `Time mm:ss`
- `Kills`
- `Mat`

## 10. ConfigRepo 接口设计

新增接口：

- `character_db`
- `get_character_config(id)`
- `get_character_list()`
- `get_wave_index(time_seconds)`
- `get_total_wave_count()`
- `get_shop_options(player, weapon_controller, exclude_keys)`

## 11. 重开与返回菜单规则

- 重开：沿用当前角色、重置材料和战斗进度
- 返回主菜单：退出当前局并回到默认选角态
