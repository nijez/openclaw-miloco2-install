# 馨光 AI 设计灯光安装指导

准备好腾讯云轻量服务器的小龙虾（OpenClaw）应用模板和 MiMo API Key 后，把固定安装指令发给小龙虾对话页即可开始安装。

`2026-06-25.3` 已完成真实腾讯云小龙虾应用模板服务器验证，可按本教程安装。

## 项目目标

完成安装后，用户可以在小龙虾里输入灯光需求，例如：

```text
吊顶灯带，设计个马尔代夫灯光效果。
```

小龙虾会通过馨光 Skill 控制馨光设备，生成对应的 AI 设计灯光效果。

## 4 大步骤

1. 准备小龙虾服务器：购买腾讯云轻量服务器，并选择小龙虾应用模板。
2. 配置小龙虾：开通小米 MiMo 大模型账号，获取并填写 MiMo API Key，绑定微信小龙虾。
3. 安装馨光 AI 设计灯光：把固定安装指令发给小龙虾对话页。
4. 配置并测试灯光效果：配置灯光能力 MiMo API Key，绑定米家账号，确认馨光设备，安装馨光 Skill 并测试。

## 教程页面

- 本地教程：[docs/miloco-openclaw-cloud-install.html](docs/miloco-openclaw-cloud-install.html)
- 公开地址：https://nijez.github.io/xingguang-ai-lighting-guide/

## 相关入口

- 购买腾讯云小龙虾服务器：https://cloud.tencent.com/act/pro/openclaw
- 查看腾讯云 OpenClaw 实践教程：https://cloud.tencent.com/document/product/1207/127874
- 小米 MiMo 开放平台：https://platform.xiaomimimo.com/
- OpenClaw 配置 MiMo 说明：https://mimo.mi.com/docs/zh-CN/tokenplan/integration/openclaw

## MiMo API Key 说明

小龙虾和馨光 AI 设计灯光能力都会用到 MiMo API Key。

- 小龙虾 MiMo API Key：用于小龙虾正常对话和执行任务。
- 灯光能力 MiMo API Key：用于馨光 AI 设计灯光能力。
- 这两个位置可以使用同一个 MiMo API Key。

安装过程中不会要求填写你的 API Key。安装完成后，再按页面提示完成 MiMo API Key、米家账号和馨光设备配置。

## 测试灯光示例

```text
吊顶灯带，设计个马尔代夫灯光效果。
客厅灯带，设计一个海边日落灯光效果。
卧室灯光，设计一个适合睡前放松的灯光效果。
茶室灯光，设计一个安静的东方禅意灯光效果。
```

## 异常处理

如果安装过程中页面短暂异常，通常是小龙虾后台服务正在重启。

请等待 1-3 分钟后刷新页面。刷新后如果是空白对话框，直接发送「查看安装进度」。

不要重复发送一键部署指令。

如果多次刷新后仍无法查看进度，请联系技术人员处理。

## 当前说明

完成前面步骤后，即可进入馨光 Skill 安装与灯光测试。馨光 Skill 安装指令将继续补充。
