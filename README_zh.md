# VoiceInput

[English](README.md) | [中文](README_zh.md)

macOS 菜单栏语音输入应用。按住 **Fn 键**说话，松开即输入——在任意应用中均可使用。

## 功能特性

- **Fn 键触发** — 按住 Fn 开始录音，松开自动识别并输入
- **实时反馈** — 悬浮窗显示波形动画和实时字幕
- **多语言支持** — 简体中文、繁體中文、English、日本語、한국어
- **自动标点** — 自动添加逗号、句号等标点符号
- **中文输入法兼容** — 粘贴时自动切换到英文输入法，粘贴后恢复
- **可选 LLM 润色** — 利用大模型修正语音识别错误（如"配森" → "Python"）
- **轻量** — 使用 Apple Speech 框架，无需下载额外模型

## 系统要求

- macOS 14.0 (Sonoma) 及以上
- Apple Silicon (M1/M2/M3/M4)
- Xcode（用于编译）

## 编译运行

```bash
git clone https://github.com/kuorazy/VoiceInput.git
cd VoiceInput
make run
```

## 权限配置

首次运行需要授予以下权限：

1. **麦克风** — 系统设置 → 隐私与安全性 → 麦克风
2. **语音识别** — 系统设置 → 隐私与安全性 → 语音识别
3. **辅助功能** — 系统设置 → 隐私与安全性 → 辅助功能

> 每次重新编译后，可能需要在辅助功能权限中将 VoiceInput 关闭再重新打开。

## 使用方法

1. 应用启动后，菜单栏右上角出现麦克风图标
2. **按住 Fn 键** — 开始说话，悬浮窗显示波形和实时识别文字
3. **松开 Fn 键** — 识别结果自动输入到当前光标位置
4. 点击菜单栏图标可切换语言或配置 LLM

## LLM 润色（可选）

开启 LLM 后处理可修正语音识别中的常见错误，如同音字、技术术语识别错误等。支持任何 OpenAI 兼容 API。

1. 点击菜单栏图标 → **LLM Refinement → Enabled**
2. 点击 **Settings…** 配置：
   - **API Base URL** — 如 `https://api.openai.com/v1`
   - **API Key**
   - **Model** — 默认：`gpt-4o-mini`

## 其他命令

```bash
make build    # 仅编译
make install  # 编译并安装到 /Applications
make clean    # 清理编译产物
```

## 许可证

MIT
