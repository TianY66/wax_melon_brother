# 冬瓜兄弟设计文档索引

本文档集基于 [game.md](/E:/wax_gourd_brother/game.md) 的“两周可落地肉鸽生存类游戏”思路整理，目标是在不失控扩张的前提下，为《冬瓜兄弟》建立一套可以直接进入开发的项目资料。

## 文档列表

1. [项目简介与可行性分析](/E:/wax_gourd_brother/docs/01-project-overview-feasibility.md)
2. [产品需求文档](/E:/wax_gourd_brother/docs/02-prd.md)
3. [故事列表](/E:/wax_gourd_brother/docs/03-story-list.md)
4. [第一次迭代故事与需求说明](/E:/wax_gourd_brother/docs/04-iteration-1.md)
5. [用例图与用例说明](/E:/wax_gourd_brother/docs/05-use-cases.md)
6. [概要设计](/E:/wax_gourd_brother/docs/06-high-level-design.md)
7. [详细设计](/E:/wax_gourd_brother/docs/07-detailed-design.md)
8. [对象和行为列表](/E:/wax_gourd_brother/docs/08-object-behavior-list.md)
9. [测试文档](/E:/wax_gourd_brother/docs/09-test-plan.md)
10. [部署说明与项目总结](/E:/wax_gourd_brother/docs/10-deployment-and-summary.md)

## 统一设计前提

- 游戏类型：单人俯视角肉鸽生存类
- 游戏名称：冬瓜兄弟
- 主题风格：轻喜剧“后厨灾变”世界观
- 核心体验：移动走位、自动攻击、即时升级、局内构筑、10 分钟生存
- 目标平台：Windows PC
- 推荐引擎：Godot 4.3
- 开发目标：2 周内完成可演示 MVP
- 内容边界：1 张地图、1 名可玩角色、4~6 种武器、5 类普通敌人、2 类精英敌人、1 个 Boss

## 文档使用建议

- 立项时先看“项目简介”“PRD”“第一次迭代说明”
- 开发时重点看“概要设计”“详细设计”“对象和行为列表”
- 测试和打包阶段看“测试文档”“部署说明”
