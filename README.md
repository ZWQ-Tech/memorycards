# 学习记忆卡片制作台（ArkTS · HarmonyOS PC 端 / 2in1）

参考 PC 端应用风格打造：**左侧深绿导航栏 + 右侧分模块内容区**，简洁校园风。
核心代码全部在 `entry/src/main/ets/pages/Index.ets` 一个文件中，无任何第三方依赖。

> 已按课程要求配置：Compatible SDK **6.1.1(24)**，设备类型 **2in1**（鸿蒙 PC），可直接用 2in1 模拟器运行。

## 🔗 在线预览（免安装，浏览器直接打开）

- **Demo 入口页**：https://zwq-tech.github.io/memorycards/
- **制作台完整版**：https://zwq-tech.github.io/memorycards/demo/memorycards-studio-demo.html
- **轻量演示版**：https://zwq-tech.github.io/memorycards/demo/memorycards-demo.html

> 由 GitHub Pages 托管，`main` 分支根目录即站点根目录；网页版与 ArkTS 工程为同一套交互逻辑的两种实现。

## 功能一览

### 📝 录入台（左录入 / 右预览 双栏布局）
- **批量录入**：左侧大文本框，每行一张卡片，格式：`题干 | 答案 #标签1 #标签2`
  - 支持全角 `｜` 分隔；`#标签` 可写多个、可省略
  - 缺少题干或答案的行**自动跳过**并提示跳过数量
- **实时预览**：右侧面板随输入实时渲染卡片（题目 / 答案 / 标签胶囊 / 可导入标记）
- **一键导入**：自动查重（题干重复的跳过），导入后 Toast 汇报"成功 X 张、跳过重复 Y 张"
- **🧪 示例 / 🧹 清空**：一键填入示例文本快速体验

### 🗂 卡片库
- 展示全部卡片：题目、答案预览、标签胶囊、掌握度徽章（⚪ 陌生 / 🟡 模糊 / 🟢 已掌握）
- **搜索**：关键词同时匹配题干 / 答案 / 标签
- **标签筛选**：横向滚动标签栏，点标签过滤，再点取消
- **行内编辑**：点「编辑」原位展开编辑器，改题目 / 答案 / 标签后保存
- 点 ✕ 删除卡片

### 🔄 复习
- 3D 翻卡动画：正面黑板绿显**题目**（含标签），背面便利贴黄显**答案**
- **上一张 / 下一张**循环切换，切卡自动回到题目面
- **掌握度三档标记**：😅 陌生 / 🤔 模糊 / 😄 已掌握 —— 标记后自动跳下一张，并同步到侧边栏统计和卡片库徽章
- **筛选复习**：全部 / 待巩固 / 已掌握
- **🔀 洗牌乱序**：Fisher-Yates 随机打乱复习顺序

### 📊 其他
- 侧边栏底部**学习概览**：卡片总数 / 标签数 / 已掌握数 实时统计
- 数据通过 Preferences **本地持久化**，重启应用不丢失（预览器环境自动降级为内存模式）
- 首次启动预置 5 张示例卡片（含标签、不同掌握度）

## 按老师步骤运行（DevEco Studio 6.1.1 + 2in1 模拟器）

### 第一步：新建工程
1. 打开 DevEco Studio，欢迎页点 **新建项目**
2. 模板选 **Application > Empty Ability** → 下一步
3. 配置项目：
   - 项目名称：`MemoryCards`（可自定义）
   - Compatible SDK：选 **6.1.1(24)**
   - 设备类型：**只勾 2in1** ✅
   - 模块名称：`entry`（默认）
4. 点 **完成**，等待 Sync / Ohpm Install 完成（底部进度条走完）

### 第二步：放入代码（二选一）
- **方式 A（推荐）**：在项目中打开 `entry/src/main/ets/pages/Index.ets`，**全选删除**，粘贴本仓库 `MemoryCards/entry/src/main/ets/pages/Index.ets` 的全部内容，保存
- **方式 B**：**File > Open** 直接打开本 `MemoryCards` 文件夹，等待 Sync；若提示 hvigor / SDK 版本差异，按提示升级修复即可

### 第三步：创建并启动 2in1 模拟器
1. 右上角设备下拉框 → **设备管理器**（或菜单 Tools > Device Manager）
2. 左侧选 **本地模拟器 > 2in1** → **新建模拟器**
3. 选择 `MateBook Pro`（HarmonyOS 6.1.1(24)）→ 完成创建
4. 在列表中点该模拟器右侧的 **▶ 启动**

### 第四步：运行
1. 右上角设备下拉框选中刚启动的 **2in1 模拟器**
2. 点 **Run ▶**，等待编译安装，模拟器中即可看到「记忆卡片制作台」

> 也可以先用右上角 **Previewer（预览器）** 快速查看界面，无需启动模拟器。

## 提交到自己的 GitHub（已完成）

仓库地址：**https://github.com/ZWQ-Tech/memorycards**

本文件夹已初始化 Git 仓库并完成首次提交（含 HarmonyOS 工程 `.gitignore`），后续如需重新推送到别的仓库：

1. 登录 [github.com](https://github.com) → 右上角 **+** → **New repository**
   - 仓库名如 `memorycards`，选 Public，**不要**勾选 "Add a README"（避免冲突）
2. 在项目根目录（`MemoryCards/`）打开终端执行（把 `<你的用户名>` 换成自己的 GitHub 用户名）：

   ```bash
   git remote add origin https://github.com/<你的用户名>/memorycards.git
   git branch -M main
   git push -u origin main
   ```

3. 刷新 GitHub 页面确认代码已上传，把仓库链接发给老师即可

> 后续修改代码后再次提交：`git add . && git commit -m "更新说明" && git push`
>
> 也可以在 DevEco Studio 中用菜单 **Git** 直接操作（左上角分支图标也可发起 commit / push）。
> 若 push 提示 403/无权限，先在 GitHub 生成 Personal Access Token（Settings > Developer settings > Tokens），push 时密码处填 Token。

## 快速上手（给老师/同学演示）
1. 「📝 录入台」→ 点「🧪 示例」→ 右侧实时预览 → 「🚀 一键导入」
2. 「🗂 卡片库」→ 搜索 / 标签筛选 / 编辑 / 删除
3. 「🔄 复习」→ 点卡片翻面背题 → 标记掌握程度 → 试试「🔀 洗牌」和「待巩固」筛选
4. 左侧边栏底部随时查看学习概览统计

## 环境要求
- DevEco Studio 6.1.1（或 5.0+，SDK 不匹配时按 IDE 提示修复）
- 无第三方依赖
