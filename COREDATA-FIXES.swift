// ============================================================================
// LEGADO iOS - CoreData 实体修复代码片段
// ============================================================================
// 这是根据检查报告生成的修复代码，可直接复制到对应的 Swift 文件中
// 修复优先级：从上到下按重要性排列
// ============================================================================

// MARK: - Book+CoreDataClass.swift 中应添加的字段 (CRITICAL)

/*
在 public class Book: NSManagedObject 中添加:
*/

// 1. 用户自定义字段 (缺失)
@NSManaged public var customCoverUrl: String?
@NSManaged public var customIntro: String?

// 2. 书籍类型 (缺失) 
// 0 = 文本, 1 = 音频, 2 = 图片
@NSManaged public var type: Int32

// 3. 书籍统计 (缺失)
@NSManaged public var wordCount: String?

// 4. 自定义变量 (缺失)
@NSManaged public var variable: String?

// 5. 本地书籍字符集 (缺失)
@NSManaged public var charset: String?

// 6. 缓存字段 (缺失, @Ignore 忽略持久化)
@NSManaged public var infoHtml: String?
@NSManaged public var tocHtml: String?

// 7. 阅读配置对象 (CRITICAL - 缺失)
@NSManaged public var readConfig: ReadConfig?

// 8. 修复 group 类型 (INT32 → INT64)
// 将现有的:
//   @NSManaged public var group: Int32
// 改为:
//   @NSManaged public var group: Int64


// ============================================================================
// MARK: - Book 中应添加的 ReadConfig 嵌套结构体 (CRITICAL)
// ============================================================================

@Codable  // 需要遵循 Codable 协议
struct ReadConfig: Codable {
    var reverseToc: Bool = false              // 反向目录
    var pageAnim: Int? = nil                  // 翻页动画
    var reSegment: Bool = false               // 重新分段
    var imageStyle: String? = nil             // 图片样式
    var useReplaceRule: Bool? = nil           // 是否使用净化规则
    var delTag: Int64 = 0                     // 删除标签
    var ttsEngine: String? = nil              // TTS 引擎
    var splitLongChapter: Bool = true         // 分割长章节
    var readSimulating: Bool = false          // 阅读模拟
    var startDate: String? = nil              // 起始日期 (ISO 8601)
    var startChapter: Int? = nil              // 起始章节
    var dailyChapters: Int = 3                // 每日章节数
}


// ============================================================================
// MARK: - Book+CoreDataClass 中应添加的计算属性和方法 (HIGH)
// ============================================================================

extension Book {
    
    // 显示封面 (优先使用自定义)
    var displayCover: String? {
        customCoverUrl ?? coverUrl
    }
    
    // 显示简介 (优先使用自定义)
    var displayIntro: String? {
        customIntro ?? intro
    }
    
    // 未读章节数
    var unreadChapterCount: Int {
        max(totalChapterNum - durChapterIndex - 1, 0)
    }
    
    // 最后一章索引
    var lastChapterIndex: Int {
        totalChapterNum - 1
    }
    
    // 书籍类型检查
    var isText: Bool {
        type == 0  // BookType.text
    }
    
    var isAudio: Bool {
        type == 1  // BookType.audio
    }
    
    var isImage: Bool {
        type == 2  // BookType.image
    }
    
    // ReadConfig 延迟初始化
    var config: ReadConfig {
        get {
            if readConfig == nil {
                readConfig = ReadConfig()
            }
            return readConfig!
        }
        set {
            readConfig = newValue
        }
    }
    
    // ReadConfig getter/setter 方法 (对应 Android 实现)
    
    func getReverseToc() -> Bool {
        return config.reverseToc
    }
    
    func setReverseToc(_ value: Bool) {
        config.reverseToc = value
    }
    
    func getPageAnim() -> Int {
        return config.pageAnim ?? 0
    }
    
    func setPageAnim(_ value: Int?) {
        config.pageAnim = value
    }
    
    func getUseReplaceRule() -> Bool {
        guard let useReplace = config.useReplaceRule else {
            // 图片/EPUB 默认关闭
            if isImage || false { // 需要 isEpub 检查
                return false
            }
            return true  // 默认开启
        }
        return useReplace
    }
    
    func setUseReplaceRule(_ value: Bool) {
        config.useReplaceRule = value
    }
    
    func getTtsEngine() -> String? {
        return config.ttsEngine
    }
    
    func setTtsEngine(_ value: String?) {
        config.ttsEngine = value
    }
    
    func getSplitLongChapter() -> Bool {
        return config.splitLongChapter
    }
    
    func setSplitLongChapter(_ value: Bool) {
        config.splitLongChapter = value
    }
    
    func getReadSimulating() -> Bool {
        return config.readSimulating
    }
    
    func setReadSimulating(_ value: Bool) {
        config.readSimulating = value
    }
    
    func getStartDate() -> String? {
        if !config.readSimulating || config.startDate == nil {
            return nil  // 返回今天
        }
        return config.startDate
    }
    
    func setStartDate(_ value: String?) {
        config.startDate = value
    }
    
    func getStartChapter() -> Int {
        if config.readSimulating {
            return config.startChapter ?? 0
        }
        return durChapterIndex
    }
    
    func setStartChapter(_ value: Int) {
        config.startChapter = value
    }
    
    func getDailyChapters() -> Int {
        return config.dailyChapters
    }
    
    func setDailyChapters(_ value: Int) {
        config.dailyChapters = value
    }
    
    func getReSegment() -> Bool {
        return config.reSegment
    }
    
    func setReSegment(_ value: Bool) {
        config.reSegment = value
    }
    
    func getImageStyle() -> String? {
        return config.imageStyle
    }
    
    func setImageStyle(_ value: String?) {
        config.imageStyle = value
    }
}


// ============================================================================
// MARK: - BookSource+CoreDataClass.swift 中应添加的字段 (HIGH)
// ============================================================================

/*
在 public class BookSource: NSManagedObject 中添加:
*/

// 1. 自定义变量 (缺失)
@NSManaged public var variable: String?

// 注意: bookSourceUrl 应该设置为 @PrimaryKey
// 检查现有代码，确保:
//   @PrimaryKey  
//   var bookSourceUrl: String = ""


// ============================================================================
// MARK: - BookSource 中缺失的 Codable 结构体定义
// ============================================================================

/*
注: 部分结构体已在 iOS 代码中存在，以下是需要补全或修改的部分
*/

// ExploreRule (发现规则) - 需要添加
struct ExploreRule: Codable {
    var exploreUrl: String?           // 发现地址
    var exploreScreen: String?        // 发现筛选规则
    var exploreList: String?          // 发现列表规则
    var name: String?                 // 书名规则
    var author: String?               // 作者规则
    var intro: String?                // 简介规则
    var bookUrl: String?              // 书籍地址规则
    var coverUrl: String?             // 封面规则
    var kind: String?                 // 分类规则
}

// ReviewRule (段评规则) - 需要补全
struct ReviewRule: Codable {
    var reviewList: String?           // 评论列表规则
    var author: String?               // 评论者规则
    var content: String?              // 评论内容规则
    var time: String?                 // 评论时间规则
    var score: String?                // 评分规则
}


// ============================================================================
// MARK: - BookSource+CoreDataClass 中应添加的方法
// ============================================================================

extension BookSource {
    
    // 获取发现规则
    func getExploreRule() -> ExploreRule? {
        guard let data = ruleExploreData else { return nil }
        return try? JSONDecoder().decode(ExploreRule.self, from: data)
    }
    
    func setExploreRule(_ rule: ExploreRule) {
        ruleExploreData = try? JSONEncoder().encode(rule)
    }
    
    // 获取段评规则
    func getReviewRule() -> ReviewRule? {
        guard let data = ruleReviewData else { return nil }
        return try? JSONDecoder().decode(ReviewRule.self, from: data)
    }
    
    func setReviewRule(_ rule: ReviewRule) {
        ruleReviewData = try? JSONEncoder().encode(rule)
    }
    
    // 显示名称 (带分组)
    var displayNameWithGroup: String {
        if let group = bookSourceGroup, !group.isEmpty {
            return "\(bookSourceName) (\(group))"
        }
        return bookSourceName
    }
}


// =========================================================================
