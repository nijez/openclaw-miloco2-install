# 馨光 AI 设计灯光安装指导

这是面向普通用户的安装说明。用户只需要准备腾讯云轻量服务器的小龙虾（OpenClaw）应用模板、MiMo API Key，然后把固定安装指令发给小龙虾对话页。

`2026-06-25.3` 已完成真实腾讯云 OpenClaw 应用模板服务器验证，第一阶段底座部署版本已冻结。

## 普通用户 4 步

1. 购买腾讯云轻量服务器，并选择小龙虾（OpenClaw）应用模板。
2. 购买 / 开通小米 MiMo 大模型账号，并获取 API Key。
3. 把固定安装指令发给小龙虾，安装馨光 AI 设计灯光能力所需底座。
4. 完成馨光技能配置后，输入灯光需求，测试 AI 灯光效果。

## 公开页面

- 教程页面：[docs/miloco-openclaw-cloud-install.html](docs/miloco-openclaw-cloud-install.html)
- 公开地址：https://nijez.github.io/xingguang-ai-lighting-guide/
- 固定脚本地址：https://nijez.github.io/xingguang-ai-lighting-guide/install-miloco-openclaw-cloud.sh
- 备用脚本地址：https://raw.githubusercontent.com/nijez/xingguang-ai-lighting-guide/main/install-miloco-openclaw-cloud.sh

## 使用方式

打开教程页面后，按顺序完成：

- 复制「发给小龙虾的一键安装指令」
- 粘贴到小龙虾对话页
- 等待安装启动提示
- 如页面短暂异常，等待 1-3 分钟后刷新页面
- 刷新后如果是空白对话框，直接发送「查看安装进度」

不要重复发送一键部署指令。

## MiMo API Key

MiMo API Key 需要用户从小米 MiMo 平台获取。请妥善保存，不要截图公开，不要发给无关人员。

## 测试灯光示例

完成馨光技能配置后，可以用下面这些句子测试：

```text
吊顶灯带，设计个马尔代夫灯光效果。
客厅灯带，设计一个海边日落灯光效果。
卧室灯光，设计一个适合睡前放松的灯光效果。
茶室灯光，设计一个安静的东方禅意灯光效果。
```

## 异常处理

如果安装过程中页面短暂异常，通常是小龙虾后台服务正在重启。

请等待 1-3 分钟后刷新页面。刷新后如果是空白对话框，直接发送「查看安装进度」。

如果多次刷新后仍无法查看进度，请联系技术人员处理。

## 当前边界

当前版本已验证第一阶段底座部署。馨光技能、设备白名单、淡彩光颜色规则和真机控制验收属于后续阶段，不在本页面中声称已经全部完成。
