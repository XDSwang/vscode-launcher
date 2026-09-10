# VSCode 启动器

让 VSCode 像 PyCharm 一样：默认纯净启动、按需选择扩展、自动管理 conda/Python 环境、选择工作区、记忆上次选择。

## 功能

- **扩展按需加载**：自动扫描已安装扩展，带中文说明，循环选择，每次启动只加载选中的扩展
- **Python 环境管理**：自动扫描 conda 环境，支持创建/删除环境，显示完整版本号和下载进度
- **工作区选择**：扫描常用项目目录，选择后自动打开
- **记忆上次选择**：扩展、环境、工作区都记录，下次可一键继续
- **输入安全**：所有选择都有确认步骤，无效输入提示重新输入，不会误操作
- **错误日志**：运行异常自动记录到脚本目录的 `error.log`
- **自动关闭**：启动 VSCode 后脚本窗口自动关闭，进程完全分离

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

双击桌面快捷方式，依次走四步：

1. **选择扩展**：有记录问是否继续 → 循环添加未选扩展 → 每次添加确认
2. **选择 Python 环境**：选包管理器 → 选环境（可创建/删除）→ 确认
3. **选择工作区**：选项目目录 → 确认
4. **启动**：自动写入工作区设置，启动 VSCode，窗口自动关闭

## 单独运行

脚本都在 `文档\VSCode启动器\`，可单独运行：

| 脚本 | 功能 |
|------|------|
| `vscode-main.ps1` | 主入口，四步全流程 |
| `vscode-select-ext.ps1` | 只选扩展，不启动 |
| `vscode-select-env.ps1` | 只选环境，不启动 |
| `vscode-select-workspace.ps1` | 只选工作区，不启动 |
| `vscode-run.ps1` | 只读记录直接启动 |

## 配置文件

- `%USERPROFILE%\.vscode-launcher\last.json`：上次选择记录
- `%USERPROFILE%\.vscode-launcher\package-managers.json`：包管理器配置
- `文档\VSCode启动器\error.log`：运行错误日志

## 添加新包管理器

运行 `vscode-select-env.ps1`，在包管理器列表选"添加新包管理器"，输入名称和 conda.exe 路径即可。目前支持 conda。

## 系统要求

- Windows 10/11
- PowerShell 5.1+
- VSCode（必需）
- Anaconda/Miniconda（可选，用于 Python 环境管理）