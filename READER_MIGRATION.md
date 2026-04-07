# Legado 阅读器一比一移植计划

## 原版架构分析

### 核心组件层次结构

```
ReadBookActivity (阅读界面)
├── ReadBookViewModel (数据管理)
├── ReadView (阅读视图容器)
│   ├── PageDelegate (翻页动画代理)
│   │   ├── CoverPageDelegate (覆盖翻页)
│   │   ├── SlidePageDelegate (滑动翻页)
│   │   ├── SimulationPageDelegate (仿真翻页)
│   │   ├── ScrollPageDelegate (滚动翻页)
│   │   └── NoAnimPageDelegate (无动画)
│   ├── TextPageFactory (页面工厂)
│   └── PageView x3 (前一页/当前页/下一页)
│       ├── ContentTextView (内容绘制)
│       ├── HeaderView (页眉)
│       └── FooterView (页脚)
└── ReadMenu (阅读菜单)

ReadBook (阅读管理单例)
├── TextChapter (章节管理)
│   └── TextPage[] (页面数组)
│       └── TextLine[] (行数组)
│           └── BaseColumn[] (列/字符数组)
│               ├── TextColumn (文本)
│               ├── ImageColumn (图片)
│               └── ButtonColumn (按钮)
└── ChapterProvider (章节排版器)
    └── TextChapterLayout (异步排版)
```

### 数据流

```
1. 用户打开书籍
   → ReadBook.resetData(book)
   → loadContent(durChapterIndex)
   → ChapterProvider.getTextChapterAsync()

2. 章节排版
   → TextChapterLayout (协程)
   → setTypeText() / setTypeImage() (逐行排版)
   → TextPage[] 生成完成
   → 回调 upContent()

3. 页面绘制
   → ContentTextView.onDraw()
   → TextPage.draw()
   → TextLine.draw()
   → TextColumn.draw() / ImageColumn.draw()

4. 翻页交互
   → ReadView.onTouchEvent()
   → PageDelegate.onTouch()
   → scroller.fling() / startScroll()
   → computeScroll() 更新动画
   → fillPage() 切换页面
```

## iOS 移植架构

### 目标架构

```
ReaderView (SwiftUI)
├── ReaderViewModel (ObservableObject)
├── ReaderPageController (UIViewControllerRepresentable)
│   └── PageViewController (UIKit)
│       ├── PageDelegate (协议)
│       │   ├── CoverPageDelegate
│       │   ├── SlidePageDelegate
│       │   ├── SimulationPageDelegate
│       │   └── ScrollPageDelegate
│       └── PageView x3 (UIView)
│           ├── ContentTextView (UIView - 绘制)
│           ├── HeaderView (UIView)
│           └── FooterView (UIView)
└── ReaderMenu (SwiftUI View)

ReadBook (单例管理器)
├── TextChapter (章节模型)
│   └── TextPage[] (页面数组)
│       └── TextLine[] (行数组)
│           └── TextColumn[] (列数组)
└── ChapterProvider (章节排版器)
    └── TextChapterLayout (异步排版)
```

## 移植优先级

### P0 - 核心阅读功能 (必须完成)
1. **TextPage 模型** - 页面数据结构
2. **TextLine 模型** - 行数据结构
3. **TextColumn 模型** - 字符/图片数据结构
4. **ChapterProvider** - 章节排版引擎
5. **ContentTextView** - 内容绘制视图
6. **ReadBook 管理器** - 阅读状态管理
7. **TextPageFactory** - 页面工厂

### P1 - 翻页动画
1. **PageDelegate 协议** - 翻页代理接口
2. **CoverPageDelegate** - 覆盖翻页
3. **ScrollPageDelegate** - 滚动翻页
4. **SlidePageDelegate** - 滑动翻页
5. **SimulationPageDelegate** - 仿真翻页

### P2 - 交互增强
1. **文本选择** - 长按选择、光标移动
2. **图片交互** - 点击预览、长按菜单
3. **点击区域** - 九宫格点击区域处理
4. **自动翻页** - AutoPager

### P3 - UI 增强
1. **页眉页脚** - 时间、电量、进度
2. **阅读菜单** - 设置、目录、进度条
3. **进度同步** - WebDAV 同步

## 关键实现差异

### Android vs iOS

| 功能 | Android | iOS |
|------|---------|-----|
| 绘制 | Canvas + Paint | CGContext + UIFont/UIColor |
| 布局 | StaticLayout | TextKit / CoreText |
| 动画 | Scroller | UIView.animate / CADisplayLink |
| 触摸 | onTouchEvent | UIGestureRecognizer |
| 异步 | Coroutines | async/await |
| 存储 | Room | CoreData |

### 排版引擎

Android 使用 `StaticLayout` 进行文本排版，iOS 需要使用：
- **TextKit** (推荐) - UITextView 内部使用，易用
- **CoreText** - 底层 API，性能更好
- **CTFramesetter** - 框架排版

选择 **TextKit + CTFramesetter** 混合方案：
- TextKit 处理基本文本测量
- CTFramesetter 处理精确排版控制

## 实施计划

### 阶段 1: 模型层 (1-2天)
- [ ] 创建 TextColumn 协议和实现类
- [ ] 创建 TextLine 模型
- [ ] 创建 TextPage 模型
- [ ] 创建 TextChapter 模型
- [ ] 创建 TextPos 位置模型

### 阶段 2: 排版引擎 (2-3天)
- [ ] 实现 ChapterProvider 排版器
- [ ] 实现 setTypeText 文本排版
- [ ] 实现 setTypeImage 图片排版
- [ ] 实现 TextChapterLayout 异步排版
- [ ] 处理两端对齐、首行缩进

### 阶段 3: 绘制层 (2-3天)
- [ ] 实现 ContentTextView 绘制
- [ ] 实现 TextPage.draw()
- [ ] 实现 TextLine.draw()
- [ ] 实现 TextColumn.draw() / ImageColumn.draw()
- [ ] 处理选中高亮、搜索高亮

### 阶段 4: 阅读管理 (1-2天)
- [ ] 实现 ReadBook 单例
- [ ] 实现 loadContent 章节加载
- [ ] 实现 moveToNextPage/moveToPrevPage
- [ ] 实现 TextPageFactory

### 阶段 5: 翻页动画 (2-3天)
- [ ] 定义 PageDelegate 协议
- [ ] 实现 CoverPageDelegate
- [ ] 实现 ScrollPageDelegate
- [ ] 实现 SlidePageDelegate
- [ ] 实现 SimulationPageDelegate

### 阶段 6: 交互完善 (1-2天)
- [ ] 实现触摸事件处理
- [ ] 实现点击区域判断
- [ ] 实现文本选择
- [ ] 实现图片交互

## 文件结构规划

```
Legado/
├── Core/
│   ├── Reader/
│   │   ├── Models/
│   │   │   ├── TextColumn.swift
│   │   │   ├── TextLine.swift
│   │   │   ├── TextPage.swift
│   │   │   ├── TextChapter.swift
│   │   │   ├── TextPos.swift
│   │   │   └── PageDirection.swift
│   │   ├── Provider/
│   │   │   ├── ChapterProvider.swift
│   │   │   ├── TextChapterLayout.swift
│   │   │   └── TextPageFactory.swift
│   │   └── Manager/
│   │       └── ReadBook.swift
│   └── ...
├── Features/
│   └── Reader/
│       ├── Views/
│       │   ├── ReaderView.swift
│       │   ├── ReaderPageController.swift
│       │   ├── PageView.swift
│       │   ├── ContentTextView.swift
│       │   ├── HeaderView.swift
│       │   └── FooterView.swift
│       ├── Delegates/
│       │   ├── PageDelegate.swift
│       │   ├── CoverPageDelegate.swift
│       │   ├── SlidePageDelegate.swift
│       │   ├── SimulationPageDelegate.swift
│       │   └── ScrollPageDelegate.swift
│       ├── ViewModels/
│       │   └── ReaderViewModel.swift
│       └── ...
└── ...
```

## 测试策略

### 单元测试
- TextPage 模型测试
- ChapterProvider 排版测试
- ReadBook 状态管理测试

### 集成测试
- 章节加载流程
- 翻页动画流程
- 进度保存流程

### UI 测试
- 阅读界面显示
- 翻页手势
- 文本选择