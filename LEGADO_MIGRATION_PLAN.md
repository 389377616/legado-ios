# Legado iOS 完整移植计划

## 项目概述

**目标**: 将 Android Legado (https://github.com/Luoyacheng/legado) 的所有功能一比一移植到 iOS 原生实现

**约束条件**:
- iOS 16+ 目标平台
- iOS 原生实现（SwiftUI + UIKit）
- TrollStore 安装为主
- GitHub Actions 构建（无本地 macOS）
- 严格对照 Android 原版代码

**原版代码位置**: `D:\soft\legado-android\`
**iOS 项目路径**: `D:\soft\legado-ios\`

---

## 模块对照表

| Android 模块 | 路径 | iOS 对应 | 实现状态 |
|-------------|------|---------|---------|
| data | app/src/main/java/io/legado/app/data | Core/Persistence | 90% |
| model/webBook | app/src/main/java/io/legado/app/model/webBook | Core/Model, Core/Network | 80% |
| model/localBook | app/src/main/java/io/legado/app/model/localBook | Core/Parser | 40% |
| model/rss | app/src/main/java/io/legado/app/model/rss | Features/RSS | 70% |
| model/analyzeRule | app/src/main/java/io/legado/app/model/analyzeRule | Core/RuleEngine | 85% |
| help/book | app/src/main/java/io/legado/app/help/book | Core/Reader/Provider | 60% |
| help/config | app/src/main/java/io/legado/app/help/config | Core/Config | 50% |
| help/storage | app/src/main/java/io/legado/app/help/storage | Core/Sync | 80% |
| help/source | app/src/main/java/io/legado/app/help/source | Core/Source | 70% |
| ui/book/read | app/src/main/java/io/legado/app/ui/book/read | Features/Reader, Core/Reader | 75% |
| ui/book/source | app/src/main/java/io/legado/app/ui/book/source | Features/Source | 80% |
| ui/book/rss | app/src/main/java/io/legado/app/ui/book/rss | Features/RSS | 70% |
| ui/book/search | app/src/main/java/io/legado/app/ui/book/search | Features/Search | 80% |
| ui/book/bookmark | app/src/main/java/io/legado/app/ui/book/bookmark | Features/Reader | 70% |
| service | app/src/main/java/io/legado/app/service | Core/TTS, Core/Cache | 60% |
| web | app/src/main/java/io/legado/app/web | Core/WebServer | 50% |
| utils | app/src/main/java/io/legado/app/utils | 各模块分散 | 60% |

---

## Phase 0: 已完成基线 ✅

### 阶段 0.1 - 项目框架
- [x] Xcode 项目配置
- [x] CoreData 模型设计
- [x] 基础架构（MVVM + Clean Architecture）
- [x] GitHub Actions CI/CD

### 阶段 0.2 - 核心数据层
- [x] Book, BookSource, BookChapter 实体
- [x] RssSource, RssArticle 实体
- [x] ReplaceRule, ReadConfig 实体
- [x] CoreDataStack 实现

---

## Phase 1: 阅读器核心 ✅

### 阶段 1.1 - 排版引擎 (已完成)
- [x] TextPage, TextLine, TextColumn, ImageColumn 模型
- [x] ChapterProvider 排版器
- [x] TextChapterLayout 异步排版
- [x] TextPageFactory 页面工厂

### 阶段 1.2 - 绘制层 (已完成)
- [x] ContentTextView 绘制视图
- [x] 文本/图片/高亮绘制
- [x] ImageCache 图片缓存

### 阶段 1.3 - 翻页动画 (已完成)
- [x] PageDelegate 翻页代理基类
- [x] CoverPageDelegate 覆盖翻页
- [x] SlidePageDelegate 滑动翻页
- [x] ScrollPageDelegate 滚动翻页
- [x] SimulationPageDelegate 仿真翻页
- [x] NoAnimPageDelegate 无动画翻页

### 阶段 1.4 - 阅读管理 (已完成)
- [x] ReadBook 单例管理器
- [x] 章节加载与缓存
- [x] 阅读进度保存
- [x] 章节导航

### 阶段 1.5 - 触摸交互 (已完成)
- [x] ReadView 阅读视图
- [x] 点击区域判断
- [x] 长按/滑动处理
- [x] 文本选择框架

### 阶段 1.6 - 图片缓存 (已完成)
- [x] ImageProvider LRU缓存
- [x] BookHelp 图片路径管理
- [x] ImageColumn 集成

---

## Phase 2: 书源引擎 (进行中)

### 阶段 2.1 - 规则引擎核心
**Android 原版文件**:
- `model/analyzeRule/AnalyzeRule.kt` (核心规则解析)
- `model/analyzeRule/AnalyzeUrl.kt` (URL处理)
- `model/analyzeRule/SourceDebug.kt` (调试工具)

**iOS 实现**:
- [x] RuleEngine.swift - 基础规则执行
- [x] RuleAnalyzer.swift - 规则分析器
- [x] SourceRule.swift - 书源规则
- [x] RuleSplitter.swift - 规则分割
- [x] TemplateEngine.swift - 模板引擎 {{key}}
- [x] JSBridge.swift - JavaScript 执行
- [ ] AnalyzeRule.kt 完整移植 (80% 完成)

### 阶段 2.2 - 网络请求层
**Android 原版文件**:
- `model/webBook/WebBook.kt`
- `model/webBook/BookInfo.kt`
- `model/webBook/BookChapterList.kt`
- `model/webBook/BookContent.kt`
- `model/webBook/BookList.kt`
- `model/webBook/SearchModel.kt`

**iOS 实现**:
- [x] HTTPClient.swift - 网络客户端
- [x] AnalyzeUrl.swift - URL 分析
- [x] WebBook.swift - 书籍获取
- [ ] SourceDebug 完整调试器

### 阶段 2.3 - 内容处理
**Android 原版文件**:
- `help/book/ContentProcessor.kt` (内容处理)
- `help/book/BookHelp.kt` (书籍帮助)
- `model/ImageProvider.kt` (图片提供)

**iOS 实现**:
- [x] BookHelp.swift - 书籍帮助类
- [x] ImageProvider.swift - 图片提供者
- [ ] ContentProcessor.swift - 内容处理器 (待实现)
  - 替换净化规则
  - 正文格式化
  - 去重标题处理

---

## Phase 3: 本地书籍支持

### 阶段 3.1 - TXT 解析
**Android 原版文件**:
- `model/localBook/LocalBook.kt`
- `model/localBook/TxtFile.kt`
- `help/book/TocRule.kt`

**iOS 实现**:
- [x] LocalBookScanner.swift - 文件扫描
- [ ] TxtFile.swift - TXT 解析
  - 编码检测
  - 目录识别
  - 章节分割
- [x] TableOfContentsParser.swift - 目录解析
- [x] TxtTocRule+CoreDataClass.swift - 目录规则

### 阶段 3.2 - EPUB 解析
**Android 原版文件**:
- `model/localBook/EpubFile.kt`
- `model/localBook/EPUBImageProvider.kt`

**iOS 实现**:
- [x] EPUBParser.swift - 基础解析
- [x] EPUBReaderView.swift - 阅读视图
- [ ] EpubFile.swift - 完整实现
  - OPF 解析
  - NCX/NAV 解析
  - 章节提取
  - 图片提取
  - CSS 处理

### 阶段 3.3 - PDF/MOBI 支持
**Android 原版文件**:
- `model/localBook/PdfFile.kt`
- `model/localBook/MobiFile.kt`
- `model/localBook/UmdFile.kt`

**iOS 实现**:
- [ ] PdfFile.swift - PDF 支持
- [ ] MobiFile.swift - MOBI 支持
- [ ] (低优先级) UmdFile.swift - UMD 支持

---

## Phase 4: RSS 订阅

### 阶段 4.1 - RSS 解析
**Android 原版文件**:
- `model/rss/Rss.kt`
- `model/rss/RssParserByRule.kt`
- `model/rss/RssParserDefault.kt`

**iOS 实现**:
- [x] RssSource+CoreDataClass.swift
- [x] RssArticle+CoreDataClass.swift
- [x] RuleBasedRSSParser.swift
- [ ] RssParserDefault.swift - 标准 RSS/Atom 解析

### 阶段 4.2 - RSS 管理
**Android 原版文件**:
- `ui/book/rss/RssSourceViewModel.kt`
- `ui/book/rss/RssArticleViewModel.kt`
- `ui/book/rss/activity/RssReadActivity.kt`

**iOS 实现**:
- [x] RSSViewModel.swift
- [x] RSSSubscriptionView.swift
- [x] RssFavoritesView.swift
- [ ] RSS 全文抓取优化

---

## Phase 5: 替换净化

### 阶段 5.1 - 替换引擎
**Android 原版文件**:
- `help/ReplaceAnalyzer.kt`
- `data/entities/ReplaceRule.kt`

**iOS 实现**:
- [x] ReplaceEngine.swift
- [x] ReplaceEngineEnhanced.swift
- [x] ReplaceRule+CoreDataClass.swift
- [ ] 正则替换优化
- [ ] 替换范围控制（标题/正文）

---

## Phase 6: TTS 朗读

### 阶段 6.1 - 本地 TTS
**Android 原版文件**:
- `model/ReadAloud.kt`
- `service/TtsService.kt`

**iOS 实现**:
- [x] TTSManager.swift
- [x] TTSControlsView.swift
- [x] HttpTTSPlaybackManager.swift
- [ ] 后台朗读支持
- [ ] 锁屏控制

### 阶段 6.2 - HTTP TTS
**Android 原版文件**:
- `data/entities/HttpTTS.kt`
- `model/localTts/LocalTts.kt`

**iOS 实现**:
- [x] HttpTTS+CoreDataClass.swift
- [ ] HTTP TTS 引擎集成
- [ ] TTS 规则解析

---

## Phase 7: Web 服务

### 阶段 7.1 - HTTP 服务器
**Android 原版文件**:
- `web/HttpServer.kt`
- `web/WebSocketServer.kt`

**iOS 实现**:
- [x] WebServerCoordinator.swift
- [x] HTTPRequestHandler.swift
- [x] WebServerDataProvider.swift
- [ ] 完整 API 端点
  - 书架 API
  - 书源 API
  - 搜索 API
  - 阅读 API

### 阶段 7.2 - WebSocket 调试
**Android 原版文件**:
- `web/socket/BookSourceDebugWebSocket.kt`
- `web/socket/BookSearchWebSocket.kt`
- `web/socket/RssSourceDebugWebSocket.kt`

**iOS 实现**:
- [ ] WebSocket 服务器
- [ ] 书源调试 WebSocket
- [ ] 搜索 WebSocket

---

## Phase 8: 备份同步

### 阶段 8.1 - 本地备份
**Android 原版文件**:
- `help/storage/Backup.kt`
- `help/storage/Restore.kt`
- `help/storage/BackupAES.kt`

**iOS 实现**:
- [x] BackupRestoreView.swift
- [ ] ZIP 备份实现
- [ ] 加密备份
- [ ] 旧版本数据导入

### 阶段 8.2 - WebDAV 同步
**Android 原版文件**:
- `help/storage/WebDav.kt`
- `model/remote/RemoteBookWebDav.kt`

**iOS 实现**:
- [x] WebDAVClient.swift
- [x] WebDAVSyncManager.swift
- [x] WebDAVConfigView.swift
- [ ] 增量同步优化
- [ ] 冲突解决

---

## Phase 9: 漫画/图片书籍

### 阶段 9.1 - 漫画阅读
**Android 原版文件**:
- `model/ReadManga.kt`
- `ui/book/read/page/provider/PicPageProvider.kt`

**iOS 实现**:
- [x] MangaReaderView.swift
- [ ] 图片预加载
- [ ] 漫画源规则解析

---

## Phase 10: 统计与主题

### 阶段 10.1 - 阅读统计
**Android 原版文件**:
- `data/entities/ReadRecord.kt`
- `ui/book/read/ReadRecord.kt`

**iOS 实现**:
- [x] ReadingStatisticsManager.swift
- [x] ReadingStatisticsView.swift
- [x] ReadRecord+CoreDataClass.swift
- [ ] 详细统计图表

### 阶段 10.2 - 主题系统
**Android 原版文件**:
- `help/config/ReadConfig.kt`
- `data/entities/Theme.kt`

**iOS 实现**:
- [x] ThemeManager.swift
- [ ] 自定义主题编辑器
- [ ] 主题导入导出

---

## Phase 11: 工具类完善

### 阶段 11.1 - 核心工具
**Android 原版文件**:
- `utils/StringUtils.kt`
- `utils/NetworkUtils.kt`
- `utils/MD5Utils.kt`
- `utils/SvgUtils.kt`
- `utils/BitmapUtils.kt`

**iOS 实现**:
- [x] String+Extensions (md5)
- [ ] StringUtils 完整移植
- [ ] NetworkUtils 网络工具
- [ ] SvgUtils SVG 支持
- [ ] ImageUtils 图片处理

---

## 优先级矩阵

### P0 - 核心功能（必须完成）
1. ContentProcessor 内容处理器
2. TxtFile TXT 解析完整实现
3. EpubFile EPUB 完整实现
4. AnalyzeRule 完整规则解析
5. WebDav 同步优化

### P1 - 重要功能
1. PdfFile PDF 支持
2. WebSocket 调试服务
3. HTTP TTS 完整集成
4. 漫画阅读优化
5. 主题系统完善

### P2 - 增强功能
1. MobiFile MOBI 支持
2. 本地备份加密
3. 统计图表优化
4. 工具类完善

---

## 文件统计

| 模块 | Android 文件数 | iOS 已实现 | 待移植 | 完成度 |
|------|---------------|-----------|-------|-------|
| data | ~40 | 35 | 5 | 87% |
| model/webBook | 6 | 5 | 1 | 83% |
| model/localBook | 5 | 2 | 3 | 40% |
| model/rss | 3 | 2 | 1 | 67% |
| model/analyzeRule | 20+ | 6 | 14+ | 30% |
| help/book | 5 | 2 | 3 | 40% |
| help/config | 3 | 1 | 2 | 33% |
| help/storage | 5 | 3 | 2 | 60% |
| ui/book/read | 30+ | 15 | 15+ | 50% |
| ui/book/source | 15 | 10 | 5 | 67% |
| ui/book/rss | 8 | 5 | 3 | 63% |
| service | 5 | 2 | 3 | 40% |
| web | 5 | 3 | 2 | 60% |
| utils | 30+ | 5 | 25+ | 17% |

**总体进度**: 约 55%

---

## 下一步行动

### 立即执行 (Phase 2 继续完成)
1. **ContentProcessor.swift** - 内容处理器
   - 对照 `ContentProcessor.kt` (原版)
   - 替换净化规则处理
   - 正文格式化

2. **AnalyzeRule 完整移植**
   - 对照 `AnalyzeRule.kt` (原版 1000+ 行)
   - XPath/CSS/JSONPath 完整支持
   - JavaScript 规则执行

3. **本地书籍解析完善**
   - TxtFile 完整实现
   - EpubFile 图片提取
   - PdfFile 基础支持

### 本周目标
- [ ] Phase 2.3 ContentProcessor 完成
- [ ] Phase 2.1 AnalyzeRule 完整移植
- [ ] Phase 3.1-3.2 本地书籍支持完善

### 预计时间
- Phase 2 完成: 3-5 天
- Phase 3 完成: 2-3 天
- Phase 4-5 完成: 2-3 天
- Phase 6-7 完成: 3-4 天
- Phase 8-11 完成: 3-5 天

**总计预计**: 15-20 个工作日

---

## 验收标准

每个功能模块完成后必须满足：

1. **功能对等**: 与 Android 原版功能一致
2. **代码对照**: 能找到对应的 Android 原版代码
3. **CI 通过**: GitHub Actions 构建成功
4. **可运行**: 能在 iOS 模拟器/真机运行

---

## 参考资源

- Android 原版: `D:\soft\legado-android\`
- iOS 项目: `D:\soft\legado-ios\`
- 帮助文档: `app/src/main/assets/web/help/md/appHelp.md`
- 更新日志: `app/src/main/assets/updateLog.md`

---

*文档版本: 2026-04-08*
*最后更新: Phase 1 完成，Phase 2 进行中*