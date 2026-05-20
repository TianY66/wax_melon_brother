# 冬瓜兄弟：详细设计

## 1. 详细设计目标

本设计面向实际开发，定义主要模块的内部职责、关键数据结构、核心算法和事件流，确保实现时可以直接照此拆分代码与资源。

## 2. 玩家模块设计

### 2.1 主要职责
- 读取输入并移动
- 管理生命、速度、拾取范围等属性
- 接收伤害与死亡
- 接收升级后的全局加成

### 2.2 核心属性
| 字段 | 类型 | 说明 |
|---|---|---|
| current_hp | int | 当前生命值 |
| max_hp | int | 最大生命值 |
| move_speed | float | 基础移动速度 |
| pickup_radius | float | 拾取半径 |
| damage_bonus_pct | float | 攻击增伤比例 |
| cooldown_reduction_pct | float | 冷却缩减 |
| crit_rate | float | 暴击率 |
| hit_invincible_time | float | 受击无敌时间 |

### 2.3 行为流程
1. 输入系统读取方向
2. 归一化向量，乘以最终移动速度
3. 碰撞检测并更新位置
4. 检查是否进入掉落物拾取范围
5. 受击时进入短暂无敌
6. 生命归零时广播 `player_dead`

### 2.4 最终属性计算
建议统一使用最终值计算，避免多个系统到处临时修改。

```text
final_move_speed = base_move_speed * (1 + move_speed_bonus_pct)
final_damage = base_damage * (1 + damage_bonus_pct) + flat_damage_bonus
final_cooldown = max(0.2, base_cooldown * (1 - cooldown_reduction_pct))
```

## 3. 武器模块设计

## 3.1 武器基础模型
每把武器分为两层：

- `WeaponConfig`：静态配置，描述数值和行为类型
- `WeaponRuntime`：运行时实例，描述等级、冷却和当前状态

### 3.2 武器配置建议
```json
{
  "id": "winter_seed_burst",
  "name": "冬瓜籽连发",
  "type": "projectile",
  "cooldown": 1.2,
  "damage": 10,
  "projectile_count": 1,
  "speed": 700,
  "range": 420,
  "pierce": 0,
  "target_type": "nearest",
  "max_level": 5
}
```

### 3.3 武器类型
| 类型 | 示例 | 行为 |
|---|---|---|
| projectile | 冬瓜籽连发 | 索敌后发射投射物 |
| orbit | 菜刀回旋盘 | 围绕玩家旋转造成持续伤害 |
| forward_line | 热汤喷壶 | 朝移动方向或面向发射直线穿透伤害 |
| area_random | 电磁蒸笼 | 在敌人密集区域随机落点造成范围伤害 |
| beam | 保鲜膜激光 | 高伤低频，持续短时间命中 |
| companion | 小瓜无人机 | 跟随玩家并自动攻击周边敌人 |

### 3.4 攻击流程
1. 武器冷却倒计时
2. 到时后根据目标类型选择目标
3. 根据武器类型创建攻击表现
4. 命中后结算伤害、暴击、穿透或范围效果
5. 重置冷却

### 3.5 索敌策略
支持至少以下策略：

- `nearest`：最近敌人
- `forward`：前方敌人
- `densest_area`：最密集区域
- `self_orbit`：围绕自身
- `random_enemy`：随机敌人

### 3.6 升级策略
武器每次升级可改变以下维度之一：
- 伤害
- 冷却
- 投射物数量
- 穿透数
- 范围
- 特殊词条

## 4. 投射物与伤害模块设计

### 4.1 投射物属性
| 字段 | 说明 |
|---|---|
| owner_weapon_id | 来源武器 |
| damage | 伤害值 |
| speed | 飞行速度 |
| lifetime | 存活时长 |
| pierce_left | 剩余穿透次数 |
| hit_targets | 已命中目标集合 |

### 4.2 命中结算
```text
1. 判断目标是否已命中且该武器不允许重复命中
2. 计算是否暴击
3. 应用最终伤害
4. 播放命中特效
5. 若穿透次数耗尽则销毁或回收
```

### 4.3 对象池要求
- 投射物不得频繁 `new/free`
- 命中后优先回收到对象池
- 粒子和爆点特效也建议池化

## 5. 敌人模块设计

### 5.1 敌人配置建议
```json
{
  "id": "knife_mite",
  "name": "菜刀螨",
  "hp": 25,
  "move_speed": 90,
  "damage": 8,
  "contact_interval": 0.8,
  "drop_exp": 1,
  "ai_type": "chase",
  "is_elite": false
}
```

### 5.2 敌人分类
| 敌人 | 类型 | 作用 |
|---|---|---|
| 菜刀螨 | 基础近战 | 建立清怪快感 |
| 叉勺猎犬 | 高速近战 | 逼迫玩家走位 |
| 压力锅重装体 | 高血量坦克 | 测试持续输出 |
| 油烟炮台球 | 远程骚扰 | 增加位置压力 |
| 自爆清洁球 | 爆炸型 | 制造紧急转向 |
| 冷柜重装箱 | 精英 | 中局目标型敌人 |
| 搅拌无人机队长 | 精英 | 带护卫与追踪弹 |

### 5.3 敌人 AI 状态
- `spawn`
- `seek`
- `attack`
- `special`
- `dead`

### 5.4 简化 AI 策略
对多数敌人使用轻量逻辑：

```text
if distance_to_player > attack_range:
    move_to_player()
else:
    perform_attack()
```

仅少数敌人增加：
- 冲锋准备
- 远程发射
- 自爆延迟

## 6. 刷怪管理器设计

### 6.1 职责
- 维护局内时间
- 根据时间命中当前波次配置
- 控制刷怪频率和上限
- 定时触发精英与 Boss

### 6.2 波次配置示例
```json
[
  {
    "time_start": 0,
    "time_end": 120,
    "enemy_pool": ["knife_mite"],
    "spawn_rate": 1.0,
    "max_alive": 20
  },
  {
    "time_start": 120,
    "time_end": 240,
    "enemy_pool": ["knife_mite", "fork_hound"],
    "spawn_rate": 1.2,
    "max_alive": 28
  },
  {
    "time_start": 240,
    "time_end": 360,
    "enemy_pool": ["knife_mite", "fork_hound", "pressure_tank"],
    "spawn_rate": 1.4,
    "max_alive": 36
  }
]
```

### 6.3 刷怪算法
1. 根据当前时间选中当前波次
2. 判断场上敌人数是否小于 `max_alive`
3. 根据 `spawn_rate` 计算下一次刷新时间
4. 按权重随机选择敌人类型
5. 在玩家视野外安全区域生成敌人

### 6.4 终局控制
- 8 分钟后允许精英高频出现
- 9 分 30 秒开始 Boss 预警
- 10 分钟刷新 Boss

## 7. 掉落模块设计

### 7.1 掉落类型
| 掉落物 | 作用 |
|---|---|
| 鲜度能量 | 经验值 |
| 治疗包 | 恢复生命 |
| 磁吸核心 | 一段时间内自动吸取经验 |

### 7.2 掉落规则
- 普通敌人大概率掉经验
- 精英怪必掉大量经验，并概率掉治疗包
- Boss 死亡后触发胜利，不依赖普通掉落

### 7.3 吸附逻辑
- 玩家进入拾取范围后掉落物转为追踪玩家
- 磁吸核心激活时，全图经验球向玩家移动

## 8. 经验与升级模块设计

### 8.1 经验公式
为保证前期成长快、后期稍缓，建议使用非线性公式：

```text
required_exp(level) = 12 + level * 8 + level * level * 3
```

参考效果：
- Lv1 -> Lv2：23
- Lv2 -> Lv3：40
- Lv3 -> Lv4：63

### 8.2 升级选项来源
- 新武器解锁
- 已有武器升级
- 被动强化

### 8.3 升级生成规则
1. 从未满级候选池中筛选合法项
2. 若玩家武器槽未满且等级较低，优先保证至少 1 个新武器候选
3. 剔除已满级、重复无意义项
4. 按权重随机抽取 3 项且不重复

### 8.4 升级应用流程
1. 暂停游戏
2. 生成候选项并显示卡片
3. 玩家点击选择
4. 更新运行时数据
5. 广播 `upgrade_applied`
6. 恢复游戏

## 9. Boss 设计

### 9.1 Boss 名称
后厨总控机

### 9.2 设计目标
- 看起来像终局敌人
- 机制不多但辨识度强
- 让玩家感受到“最后一分钟”的压迫

### 9.3 Boss 阶段
| 阶段 | 条件 | 行为 |
|---|---|---|
| 入场阶段 | 刚登场 | 播放预警、降落、召唤护卫 |
| 阶段一 | 血量 100%~60% | 扇形弹幕、点名落区 |
| 阶段二 | 血量 60%~20% | 弹幕更密，增加冲击波 |
| 狂暴阶段 | 血量 20% 以下或倒计时将尽 | 缩短技能间隔，提高场面压力 |

## 10. UI 模块设计

### 10.1 HUD
包含：
- 生命条
- 经验条
- 当前等级
- 倒计时
- 当前 Buff 图标（可选）

### 10.2 升级面板
- 中央弹出 3 张选项卡
- 显示名称、效果说明、稀有度颜色
- 选中后关闭并恢复战斗

### 10.3 结算面板
显示：
- 胜利/失败
- 生存时间
- 玩家等级
- 击杀数
- 主要武器
- 再来一局 / 返回菜单

## 11. 存档与设置设计

### 11.1 存储内容
- 主音量
- BGM 音量
- SFX 音量
- 窗口模式
- 可选的局外解锁数据

### 11.2 存储方式
- 本地 JSON 或 Godot `ConfigFile`

## 12. 关键事件总线

建议通过事件总线统一广播：

- `player_damaged`
- `player_dead`
- `enemy_dead`
- `exp_collected`
- `level_up_ready`
- `upgrade_applied`
- `elite_spawned`
- `boss_warning`
- `boss_spawned`
- `game_victory`
- `game_defeat`

这样可以降低战斗逻辑与 UI、音频、特效之间的直接耦合。
