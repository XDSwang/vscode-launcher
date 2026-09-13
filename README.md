# VSCode 启动器

让 VSCode 像 PyCharm 一样：默认纯净启动、按需选择扩展、自动管理运行环境、选择工作区、记忆上次选择。

## 功能

- **扩展按需加载**：列出已安装扩展（带中文说明），循环选择，每次启动只加载选中的扩展
- **运行环境管理**：支持 conda 包管理器，扫描/创建/删除环境，显示完整版本号
- **工作区选择**：扫描常用项目目录，选择后自动打开
- **记忆上次选择**：扩展、环境、工作区都记录，下次可一键继续
- **一键启动**：主脚本开头检测完整记录，显示摘要，确认后直接启动，跳过三步选择
- **启动后自动验证**：检查工作区、解释器写入、扩展启用、进程存活，异常红色列出，正常自动关闭
- **终端环境名修复**：检测 PowerShell profile 是否加载 conda 初始化（兼容 Documents 重定向到其他盘），一键修复
- **运行日志**：`last-run.log` 记录最近一次启动验证结果（覆盖式），`error.log` 记录运行异常
- **输入安全**：所有选择都有确认步骤（编号+名称+路径），无效输入重新提示，不会误操作

## 文件说明

| 文件 | 作用 |
|------|------|
| `install.ps1` | **一键安装（首次先运行它）**：检测/手动输入 VSCode 路径并保存、复制脚本、创建桌面快捷方式、配置 VSCode 全局设置 |
| `vscode-main.ps1` | 主入口：支持一键启动或完整流程（扩展 → 运行环境 → 工作区 → 启动） |
| `vscode-select-ext.ps1` | 只选扩展（不启动） |
| `vscode-select-env.ps1` | 只选运行环境：包管理器 + conda 环境（可创建/删除） |
| `vscode-select-workspace.ps1` | 只选工作区（不启动） |
| `vscode-run.ps1` | 只读记录直接启动（含启动后验证） |
| `vscode-fix-terminal.ps1` | 终端环境名修复：检测终端不显示 conda 环境名的原因，选择修复 |

## 使用流程

### 首次使用（先运行哪个）

1. **先运行 `install.ps1`**（右键 → 使用 PowerShell 运行）
   - 检测 VSCode：常见位置自动找，找不到会提示手动输入 `Code.exe` 完整路径（含文件名）
   - 安装完成：脚本复制到安装目录、创建桌面快捷方式、配置 VSCode 全局设置
2. **双击桌面 `Visual Studio Code` 快捷方式**（实际运行 `vscode-main.ps1`）
3. 依次选择：**扩展** → **运行环境** → **工作区**，选择结果自动保存
4. 自动启动 VSCode，脚本窗口显示验证结果后关闭

### 日常使用

双击桌面快捷方式：
- **一键启动**：三项记录齐全时，显示上次记录摘要（含具体插件名、环境名、工作区路径），输入 `y` 直接启动
- **逐步选择**：记录缺失时提示缺了什么，自动进入对应的选择步骤

### 单独运行（只改某一项配置）

脚本在安装目录（见下"脚本位置"），可单独运行：

| 想做什么 | 运行 |
|---------|------|
| 改扩展 | `vscode-select-ext.ps1` |
| 改运行环境 / 添加包管理器 | `vscode-select-env.ps1` |
| 改工作区 | `vscode-select-workspace.ps1` |
| 直接启动（用已有记录） | `vscode-run.ps1` |
| 修终端环境名不显示 | `vscode-fix-terminal.ps1` |
| 重新配置 VSCode 路径 | `install.ps1` |

## 手动添加扫描路径

脚本在找不到程序时会按"常见路径列表"扫描。如果你的程序装在特殊位置，可以手动在脚本里加一行路径。**只加完整文件路径（含 .exe 文件名），不是目录**，加在对应数组里，以逗号结尾：

| 脚本 | 找什么 | 位置 | 示例（加进数组） |
|------|--------|------|------------------|
| `install.ps1` | VSCode | `Find-VSCodePath` 函数里 `$candidates` 数组 | `"D:\...\Code.exe",` |
| `vscode-select-env.ps1` | conda | 第 72 行 `$guessPaths` 数组（添加包管理器时） | `"D:\...\conda.exe",` |
| `vscode-select-env.ps1` | conda | 第 262 行数组（首次自动检测时） | `"D:\...\conda.exe",` |
| `vscode-fix-terminal.ps1` | conda | `$condaCandidates` 数组 | `"D:\...\conda.exe",` |
| `vscode-select-workspace.ps1` | 项目目录 | `$projectRoots` 数组（扫描其子文件夹） | `"D:\...\projects",` |

> 说明：
> - `vscode-select-ext.ps1`、`vscode-run.ps1` **不扫描路径**，只读取 `config.json` 里保存的 VSCode 路径；VSCode 路径在 `install.ps1` 里配置一次
> - 行号可能随版本变化，以**函数名/变量名**为准（用记事本打开脚本搜索变量名即可定位）
> - 路径示例中间省略，实际填写完整的 `盘符:\...\程序名.exe`

## 脚本位置与配置文件

- **脚本位置**：`D:\vscode-launcher\VSCode启动器\`（无 D 盘时在 `%USERPROFILE%\vscode-launcher\VSCode启动器\`）
- **配置文件**：`D:\vscode-launcher\VSCodeLauncher\`（无 D 盘时在 `%USERPROFILE%\vscode-launcher\VSCodeLauncher\`）

| 文件 | 内容 |
|------|------|
| `config.json` | 全局配置（VSCode 路径） |
| `last.json` | 上次选择记录（扩展/环境/工作区） |
| `package-managers.json` | 包管理器配置（名称、类型、路径） |
| `last-run.log` | 最近一次启动验证结果（覆盖式） |
| `error.log` | 最近一次运行异常（覆盖式） |

### 字段覆盖规则

`last.json` 由三个选择脚本共同维护，每个脚本只覆盖自己管理的顶层字段，其他脚本的字段原样保留：

| 脚本 | 管理的字段 |
|------|-----------|
| `vscode-select-ext.ps1` | `Name`、`Ext` |
| `vscode-select-env.ps1` | `PMName`、`PMType`、`PMPath`、`PythonPath`、`PythonName` |
| `vscode-select-workspace.ps1` | `WorkspacePath` |
| `vscode-run.ps1` | 只读，不写入 |

保存时采用重建对象方式：读取整个文件 → 只保留非自己字段 → 写入自己的新字段 → 写回。只处理第一层级，不递归嵌套对象，从根上杜绝同级重复 key。`Time` 字段每次自动更新。

## 添加新包管理器

运行 `vscode-select-env.ps1`，在包管理器列表选"添加新包管理器"，输入名称和 `conda.exe` 完整路径即可。目前支持 conda。

## 系统要求

- Windows 10/11
- PowerShell 5.1+
- VSCode（必需）
- Anaconda/Miniconda（可选，用于运行环境管理）