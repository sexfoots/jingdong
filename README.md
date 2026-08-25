# 京东 WSKey 提取器 (iOS 苹果原生巨魔版)

专为 **iOS (iPhone 巨魔商店 TrollStore)** 用户打造的多账号京东 WSKey / Cookie 提取工具。

## 🌟 核心特性

1. **多账号列表持久化**：使用 `UserDefaults` 本地安全保存常用的京东账号手机号；
2. **零干扰自动填号引擎**：采用最新测试通过的极简字符串匹配算法，进入登录页即刻自动完成手机号注入，**并自动清空验证码框**；
3. **Cookie / WSKey 自动提取**：登录成功瞬间实时抓取 `wskey`、`pt_key` 与 `pin`，并弹窗自动复制到剪贴板；
4. **巨魔商店专属免签包**：配置了 GitHub Actions 自动化编译工作流，**不需要 Mac 电脑即可自动打包出 `.ipa` 文件**。

---

## 🚀 无 Mac 电脑云端打包 IPA 教程

1. 在 [GitHub](https://github.com) 上新建一个空的代码仓库（Repository）；
2. 将本目录 (`E:\DaiMa\IPA\jingdong`) 下的所有文件推送到您的 GitHub 仓库中；
3. 点击仓库顶部的 **`Actions`** 选项卡；
4. 您会看到名为 **`构建 iOS IPA 免签安装包 (适用 TrollStore 巨魔商店)`** 的工作流会自动开始运行（运行耗时约 2 分钟）；
5. 构建完成后，在页面最下方的 **`Artifacts`** 区域即可直接下载 **`JDWSKeyGrabber-TrollStore-IPA.zip`**；
6. 解压得到 **`JDWSKeyGrabber.ipa`**，用 iPhone 手机通过 AirDrop 或微信发送到手机上，选择用 **TrollStore (巨魔商店)** 打开，即可**永久免费免签安装**！

---

## 🛠️ 项目源码结构

* `JDWSKeyGrabber/Views/ContentView.swift`：SwiftUI 构建的现代卡片式多账号管理界面；
* `JDWSKeyGrabber/Views/LoginViewController.swift`：原生 `WKWebView` 登录与 Cookies / JS 注入捕获引擎；
* `JDWSKeyGrabber/Storage/AccountManager.swift`：本地账号持久化存取管理；
* `.github/workflows/build_ipa.yml`：云端 macOS 自动化免签打包配置。
