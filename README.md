# VSCode 启动器

让 VSCode 像 PyCharm 一样：默认纯净启动、按需选择扩展、自动管理 conda/Python 环境、选择工作区、记忆上次选择。

## 功能

- **扩展按需加载**：自动扫描已安装扩展，带中文说明，循环选择，每次启动只加载选中的扩展
- **Python 环境管理**：自动扫描 conda 环境，支持创建/删除环境，显示完整版本号和下载进度
- **工作区选择**：扫描常用项目目录，选择后自动打开
- **记忆上次选择**：扩展、环境、工作区都记录，下次可一键继续
- **一键启动**：主脚本开头检测完整记录，显示扩展/环境/工作区摘要，确认后直接启动，跳过三步选择
- **VSCode 路径记录**：首次自动扫描或手动输入 Code.exe 路径，保存后下次直接使用，无需重复扫描
- **启动后自动验证**：启动后检查工作区、Python解释器写入、扩展启用、进程存活，异常红色列出
- **运行日志**：每次启动结果覆盖写入 `last-run.log`（只保留最近一次），运行异常写入 `error.log`
- **输入安全**：所有选择都有确认步骤，无效输入提示重新输入，不会误操作
- **进程分离**：启动 VSCode 后脚本窗口停窗显示验证结果，按回车关闭，VSCode 独立运行不受影响

## 快速安装

1. 下载本仓库所有文件
2. 右键 `install.ps1` → 使用 PowerShell 运行
3. 安装完成后双击桌面 `Visual Studio Code` 快捷方式

安装脚本会自动：
- 检测 VSCode 和 conda 路径
- 复制脚本到 `文档\VSCode启动器\`
- 创建桌面快捷方式
- 配置 VSCode 全局设置（PyCharm 风格布局、终端、conda）
- 配置 PowerShell conda 初始化

## 使用方法

双击桌面快捷方式：

**一键启动（推荐）**：如果扩展、环境、工作区三项记录都齐全，开头会显示上次记录摘要（含具体插件名），输入 `y` 直接启动，跳过所有选择步骤。记录缺失时会提示缺了什么，自动进入逐步选择。

**逐步选择**：
1. **选择扩展**：有记录问是否继续 → 循环添加未选扩展 → 每次添加确认
2. **选择 Python 环境**：选包管理器 → 选环境（可创建/删除）→ 确认
3. **选择工作区**：选项目目录 → 确认
4. **启动**：自动写入工作区设置 → 启动 VSCode → 等待3秒自动验证 → 显示结果（正常/异常）→ 按回车关闭窗口

## 单独运行

脚本都在 `文档\VSCode启动器\`，可单独运行：

| 脚本 | 功能 |
|------|------|
| `vscode-main.ps1` | 主入口，支持一键启动或四步全流程 |
| `vscode-select-ext.ps1` | 只选扩展，不启动 |
| `vscode-select-env.ps1` | 只选环境，不启动 |
| `vscode-select-workspace.ps1` | 只选工作区，不启动 |
| `vscode-run.ps1` | 只读记录直接启动（含启动验证） |

## 配置文件

- `%USERPROFILE%\.vscode-launcher\last.json`：上次选择记录（扩展/环境/工作区）
- `%USERPROFILE%\.vscode-launcher\config.json`：全局配置（VSCode 路径）
- `%USERPROFILE%\.vscode-launcher\package-managers.json`：包管理器配置
- `文档\VSCode启动器\last-run.log`：最近一次启动验证结果（覆盖式）
- `文档\VSCode启动器\error.log`：最近一次运行异常（覆盖式）

### 字段覆盖规则

`last.json` 由三个选择脚本共同维护，每个脚本只覆盖自己管理的顶层字段，其他脚本的字段原样保留：

| 脚本 | 管理的字段 |
|------|-----------|
| `vscode-select-ext.ps1` | `Name`、`Ext` |
| `vscode-select-env.ps1` | `PMName`、`PMType`、`PMPath`、`PythonPath`、`PythonName` |
| `vscode-select-workspace.ps1` | `WorkspacePath` |
| `vscode-run.ps1` | 只读，不写入 |

保存时采用重建对象方式：读取整个文件 → 只保留非自己字段 → 写入自己的新字段 → 写回。只处理第一层级，不递归嵌套对象，从根上杜绝同级重复 key。`Time` 字段每次自动更新。

## VSCode 路径管理

首次运行时如无记录，会提示：
1. **自动扫描常见位置**：检查 LOCALAPPDATA 和 Program Files
2. **手动输入路径**：直接输入 Code.exe 完整路径

选择后自动保存到 `config.json`，下次运行直接使用记录的路径，也可选择重新扫描或输入新路径。

## 添加新包管理器

运行 `vscode-select-env.ps1`，在包管理器列表选"添加新包管理器"，输入名称和 conda.exe 路径即可。目前支持 conda。

## 系统要求

- Windows 10/11
- PowerShell 5.1+
- VSCode（必需）
- Anaconda/Miniconda（可选，用于 Python 环境管理）
