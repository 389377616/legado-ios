# Legado iOS

<p align="center">
<img src="https://github.com/gedoor/legado/raw/master/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" width="120"/>
</p>

<p align="center">
<strong>Legado iOS</strong> - iOS 原生阅读应用
</p>

<p align="center">
<a href="https://github.com/chrn11/legado-ios/actions/workflows/ios-ci.yml"><img src="https://github.com/chrn11/legado-ios/actions/workflows/ios-ci.yml/badge.svg" alt="iOS CI"/></a>
<img src="https://img.shields.io/badge/platform-iOS%2016.0+-blue" alt="Platform"/>
<img src="https://img.shields.io/badge/Swift-5.10-orange" alt="Swift"/>
<img src="https://img.shields.io/badge/license-GPL--3.0-green" alt="License"/>
</p>

<p align="center">
<a href="#readme"><img src="https://img.shields.io/badge/-Contents:-696969.svg"/></a>
<a href="#功能"><img src="https://img.shields.io/badge/-Function-FF5F5F.svg"/></a>
<a href="#社区"><img src="https://img.shields.io/badge/-Community-FF5F5F.svg"/></a>
<a href="#界面"><img src="https://img.shields.io/badge/-Interface-FF5F5F.svg"/></a>
</p>

> 📚 基于 Legado 的 iOS 原生阅读应用，纯 SwiftUI 实现，支持自定义书源规则

---

## 功能

[English](English.md)

中文

1. 自定义书源，自己设置规则，抓取网页数据，规则简单易懂。
2. 列表书架，网格书架自由切换。
3. 书源规则支持搜索及发现，所有找书看书功能全部自定义。
4. 订阅内容，可以订阅想看的任何内容。
5. 支持替换净化，去除广告替换内容很方便。
6. 支持本地 TXT、EPUB 阅读，手动浏览，智能扫描。
7. 支持高度自定义阅读界面，切换字体、颜色、背景、行距、段距等。
8. 支持多种翻页模式，覆盖、仿真、滑动、滚动等。
9. 软件开源，持续优化，无广告。

---

## 社区

欢迎加入讨论群组，交流使用心得和问题反馈。

---

## 界面

<p align="center">
<img src="https://via.placeholder.com/300x600/4A90E2/FFFFFF?text=书架" width="200"/>
<img src="https://via.placeholder.com/300x600/4A90E2/FFFFFF?text=阅读器" width="200"/>
<img src="https://via.placeholder.com/300x600/4A90E2/FFFFFF?text=书源管理" width="200"/>
</p>

<p align="center">
<img src="https://via.placeholder.com/300x600/4A90E2/FFFFFF?text=搜索" width="200"/>
<img src="https://via.placeholder.com/300x600/4A90E2/FFFFFF?text=设置" width="200"/>
<img src="https://via.placeholder.com/300x600/4A90E2/FFFFFF?text=替换规则" width="200"/>
</p>

---

## 项目结构

```
Legado-iOS/
├── App/                      # 应用入口
├── Core/                     # 核心模块
│   ├── Persistence/         # CoreData 持久化
│   ├── Network/             # 网络请求
│   └── RuleEngine/          # 规则解析引擎 ⭐
├── Features/                 # 功能模块
│   ├── Bookshelf/           # 书架
│   ├── Reader/              # 阅读器
│   ├── Search/              # 搜索
│   ├── Source/              # 书源管理
│   └── Config/              # 设置
└── UIComponents/            # 通用 UI 组件
```

---

## 快速开始

### 环境要求

- Xcode 15.0+
- iOS 16.0+
- Swift 5.10+
- macOS 13+ (编译需要)

### 安装依赖

```bash
cd Legado-iOS
xcodebuild -resolvePackageDependencies -scheme Legado
```

### 运行项目

1. 在 Xcode 中打开 `Legado.xcodeproj`
2. 选择目标设备（真机或模拟器）
3. 点击运行（⌘R）

### GitHub Actions 编译

项目在以下情况会自动编译：
- Push 到 main/develop 分支
- 创建 Pull Request
- 手动触发 workflow

编译产物会上传到 Actions Artifacts，可以在 [Actions](https://github.com/chrn11/legado-ios/actions) 页面下载。

---

## 书源规则

### 支持的选择器类型

- **CSS 选择器**: `div.book@text`, `a@href`
- **XPath**: `//div[@class='book']`
- **JSONPath**: `$.book.name`, `$.list[0].title`
- **正则**: `regex:\d+`
- **JavaScript**: `{{js result + ' suffix'}}`

### 模板语法

支持变量替换和嵌套模板：

```
{{key}}              // 搜索关键词
{{page}}             // 页码
{{$.jsonPath}}       // JSONPath 取值
{{key,default}}      // 默认值
@put,{key,value}     // 变量存储
@get,{key}           // 变量读取
```

### 书源导入格式

```json
{
  "bookSourceUrl": "https://example.com",
  "bookSourceName": "示例书源",
  "bookSourceGroup": "分组",
  "bookSourceType": 0,
  "searchUrl": "https://example.com/search?keyword={{key}}",
  "ruleSearch": {
    "bookList": "div.book-item",
    "name": "h2@text",
    "author": "span.author@text",
    "bookUrl": "a@href"
  },
  "ruleContent": {
    "content": "div.content@html"
  }
}
```

---

## 技术栈

- **UI**: SwiftUI + UIKit
- **架构**: MVVM + Clean Architecture
- **数据库**: CoreData
- **网络**: URLSession
- **HTML 解析**: SwiftSoup
- **XPath**: Kanna
- **JS 引擎**: JavaScriptCore

---

## 贡献

欢迎提交 Issue 和 Pull Request！

---

## 开源协议

本项目遵循 GPL-3.0 协议。

---

## 链接

- [原项目 (Android)](https://github.com/gedoor/legado)
- [帮助文档](https://www.legado.top/)
- [书源规则教程](https://mgz0227.github.io/The-tutorial-of-Legado/)

---

## 免责声明

本应用仅供学习交流使用，请勿用于商业目的。
使用本应用时请遵守相关法律法规，尊重版权。
