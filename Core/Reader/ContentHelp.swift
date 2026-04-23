//
//  ContentHelp.swift
//  Legado-iOS
//
//  中文小说段落重排引擎 — 1:1 对标 Android ContentHelp.kt
//  处理错误分段、引号配对、断句重排等功能
//

import Foundation

// MARK: - 内容排版帮助（对标 Android ContentHelp）

enum ContentHelp {
    
    // MARK: - 常量（对标 Android）
    
    /// 句子结尾标点
    private static let markSentencesEnd = "？。！?!~"
    private static let markSentencesEndP = ".？。！?!~"
    
    /// 句中标点
    private static let markSentencesMid = ".，、—…"
    private static let markSentencesSay = "问说喊唱叫骂道着答"
    
    /// 引号前标记（冒号等）
    private static let markQuotationBefore = "，：,:"
    
    /// 引号
    private static let markQuotation = "\"\u{201C}\u{201D}"  // " ""
    private static let markQuotationRight = "\"\u{201D}"    // " "
    
    /// 对话段落的正则
    private static let paragraphDialogPattern = "^[\"\u{201C}\u{201D}][^\"\u{201C}\u{201D}]+[\"\u{201C}\u{201D}]$"
    
    /// 字典最大长度
    private static let wordMaxLength = 16
    
    // MARK: - 公开方法
    
    /// 段落重排算法入口 — 对标 Android reSegment()
    /// 将整篇内容输入，连接错误的分段，再重新切分
    static func reSegment(content: String, chapterName: String) -> String {
        var content1 = content
        
        let dict = makeDict(str: content1)
        
        let p = content1
            .replacingOccurrences(of: "&quot;", with: "\u{201C}")
            .replacingOccurrences(of: "[:：][\u{201C}\u{201D}\"']+".regexPattern, with: "：\u{201C}")
            .replacingOccurrences(of: "[\u{201C}\u{201D}\"']\\s*[\u{201C}\u{201D}\"'][\\s\u{201C}\u{201D}\"']+".regexPattern, with: "\u{201D}\n\u{201C}")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0) }
        
        // 初始化 StringBuilder
        var buffer = [Character]()
        buffer.reserveCapacity(Int(Double(content1.count) * 1.15))
        
        // 章节标题处理
        buffer.append(contentsOf: "  ")
        let trimmedChapterName = chapterName.trimmingCharacters(in: .whitespaces)
        let trimmedFirst = p.first?.trimmingCharacters(in: .whitespaces) ?? ""
        
        if trimmedChapterName != trimmedFirst {
            // 去除段落内空格（包括全角空格 \u{3000}）
            buffer.append(contentsOf: removeWhitespace(p[0]))
        }
        
        // 连接错误分段
        for i in 1..<p.count {
            let lastChar = buffer.last ?? " "
            if match(rule: markSentencesEnd, char: lastChar) ||
                (match(rule: markQuotationRight, char: lastChar) &&
                 buffer.count >= 2 && match(rule: markSentencesEnd, char: buffer[buffer.count - 2])) {
                buffer.append("\n")
            }
            buffer.append(contentsOf: removeWhitespace(p[i]))
        }
        
        // 预分段预处理
        let processed = String(buffer)
            .replacingOccurrences(of: "[\u{201C}\u{201D}\"']+\\s*[\u{201C}\u{201D}\"']+".regexPattern, with: "\u{201D}\n\u{201C}")
            .replacingOccurrences(of: "[\u{201C}\u{201D}\"']+([？。！?!~])[\u{201C}\u{201D}\"']+".regexPattern, with: "\u{201D}$1\n\u{201C}")
            .replacingOccurrences(of: "[\u{201C}\u{201D}\"']+([？。！?!~])([^\"\u{201C}\u{201D}])".regexPattern, with: "\u{201D}$1\n$2")
            .replacingOccurrences(of: "([问说喊唱叫骂道着答])[\\.。]".regexPattern, with: "$1。\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0) }
        
        var buffer2 = [Character]()
        buffer2.reserveCapacity(Int(Double(content1.count) * 1.15))
        for s in processed {
            buffer2.append("\n")
            buffer2.append(contentsOf: findNewLines(str: s, dict: dict))
        }
        
        let reduced = reduceLength(str: buffer2)
        
        let result = String(reduced)
            .replacingOccurrences(of: "^\\s+".regexPattern, with: "")
            .replacingOccurrences(of: "\\s*[\u{201C}\u{201D}\"']+\\s*[\u{201C}\u{201D}\"][\\s\u{201C}\u{201D}\"']*".regexPattern, with: "\u{201D}\n\u{201C}")
            .replacingOccurrences(of: "[:：][\u{201C}\u{201D}\"\\s]+".regexPattern, with: "：\u{201C}")
            .replacingOccurrences(of: "\n[\u{201C}\u{201D}\"]([^\n\u{201C}\u{201D}\"]+)([,:，：][\u{201C}\u{201D}\"])([^\n\u{201C}\u{201D}\"]+)".regexPattern, with: "\n$1：\u{201C}$3")
            .replacingOccurrences(of: "\n(\\s*)".regexPattern, with: "\n")
        
        return result
    }
    
    // MARK: - 私有方法
    
    /// 强制切分，减少段落内句子
    private static func reduceLength(str: [Character]) -> [Character] {
        let p = String(str).split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }
        let l = p.count
        var b = [Bool](repeating: false, count: l)
        
        for i in 0..<l {
            b[i] = p[i].matches(regex: paragraphDialogPattern)
        }
        
        var dialogue = 0
        for i in 0..<l {
            if b[i] {
                if dialogue < 0 { dialogue = 1 } else if dialogue < 2 { dialogue += 1 }
            } else {
                if dialogue > 1 {
                    p[i] = splitQuote(str: p[i])
                    dialogue -= 1
                } else if dialogue > 0 && i < l - 2 {
                    if b[i + 1] { p[i] = splitQuote(str: p[i]) }
                }
            }
        }
        
        var result = [Character]()
        result.append("\n")
        for s in p {
            result.append(contentsOf: s)
            result.append("\n")
        }
        return result
    }
    
    /// 强制切分未构成配对引号的段落
    private static func splitQuote(str: String) -> String {
        let length = str.count
        if length < 3 { return str }
        let chars = Array(str)
        
        if match(rule: markQuotation, char: chars[0]) {
            let i = seekIndex(str: str, key: markQuotation, from: 1, to: length - 2, inOrder: true) + 1
            if i > 1 && !match(rule: markQuotationBefore, char: chars[i - 1]) {
                let idx = str.index(str.startIndex, offsetBy: i)
                return String(str[..<idx]) + "\n" + String(str[idx...])
            }
        } else if match(rule: markQuotation, char: chars[length - 1]) {
            let seekIdx = seekIndex(str: str, key: markQuotation, from: 1, to: length - 2, inOrder: false)
            let i = length - 1 - seekIdx
            if i > 1 && !match(rule: markQuotationBefore, char: chars[i - 1]) {
                let idx = str.index(str.startIndex, offsetBy: i)
                return String(str[..<idx]) + "\n" + String(str[idx...])
            }
        }
        return str
    }
    
    /// 随机插入换行符 — 对标 Android forceSplit()
    private static func forceSplit(
        str: String,
        offset: Int,
        min: Int,
        gain: Int,
        trigger: Int
    ) -> [Int] {
        var result = [Int]()
        let arrayEnd = seekIndexes(str: str, key: markSentencesEndP, from: 0, to: str.count - 2, inOrder: true)
        let arrayMid = seekIndexes(str: str, key: markSentencesMid, from: 0, to: str.count - 2, inOrder: true)
        
        if arrayEnd.count < trigger && arrayMid.count < trigger * 3 { return result }
        
        var j = 0
        var i = min
        while i < arrayEnd.count {
            var k = 0
            while j < arrayMid.count {
                if arrayMid[j] < arrayEnd[i] { k += 1 }
                j += 1
            }
            if Double.random(in: 0..<Double(gain)) < 0.8 + Double(k) / 2.5 {
                result.append(arrayEnd[i] + offset)
                i = max(i + min, i)
            }
            i += 1
        }
        return result
    }
    
    /// 对内容重新划分段落 — 对标 Android findNewLines()
    private static func findNewLines(str: String, dict: [String]) -> String {
        let string = Array(str)
        var arrayQuote = [Int]()
        var insN = [Int]()
        
        let chars = Array(str)
        var mod = [Int](repeating: 0, count: chars.count)
        var waitClose = false
        
        for i in chars.indices {
            let c = chars[i]
            if match(rule: markQuotation, char: c) {
                let size = arrayQuote.count
                
                // 合并 "xxx"、"yy" 为 "xxx_yy"
                if size > 0 {
                    let quotePre = arrayQuote[size - 1]
                    if i - quotePre == 2 {
                        var shouldRemove = false
                        if waitClose {
                            if match(rule: ",，、/", char: chars[i - 1]) {
                                shouldRemove = true
                            }
                        } else if match(rule: ",，、/和与或", char: chars[i - 1]) {
                            shouldRemove = true
                        }
                        if shouldRemove {
                            arrayQuote.removeLast()
                            mod[size - 1] = 1
                            mod.append(-1)
                            continue
                        }
                    }
                }
                
                arrayQuote.append(i)
                
                if i > 1 {
                    let charB1 = chars[i - 1]
                    if match(rule: markQuotationBefore, char: charB1) {
                        if arrayQuote.count > 1 {
                            let lastQuote = arrayQuote[arrayQuote.count - 2]
                            var p = 0
                            if charB1 == "," || charB1 == "，" {
                                if arrayQuote.count > 2 {
                                    p = arrayQuote[arrayQuote.count - 3]
                                    if p > 0 {
                                        let charB2 = chars[p - 1]
                                        if match(rule: markSentencesEndP, char: charB2) {
                                            insN.append(p - 1)
                                        } else if !match(rule: "的地得", char: charB2) {
                                            let lastEnd = seekLast(str: str, key: markSentencesEnd, from: i, to: lastQuote)
                                            if lastEnd > 0 { insN.append(lastEnd) } else { insN.append(lastQuote) }
                                        }
                                    }
                                }
                            }
                        }
                        waitClose = true
                        mod[arrayQuote.count - 1] = 1
                        if arrayQuote.count > 1 {
                            mod[arrayQuote.count - 2] = -1
                            if arrayQuote.count > 2 {
                                mod[arrayQuote.count - 3] = 1
                            }
                        }
                    } else if waitClose {
                        waitClose = false
                        insN.append(i)
                    }
                }
            }
        }
        
        let size = arrayQuote.count
        
        // 第1次遍历标记引号配对
        var opened = false
        for i in 0..<size {
            if mod[i] > 0 {
                opened = true
            } else if mod[i] < 0 {
                if !opened && i > 0 { mod[i] = 3 }
                opened = false
            } else {
                opened = !opened
                mod[i] = opened ? 2 : -2
            }
        }
        
        // 修正断尾引号
        if opened && size > 0 {
            let lastIdx = arrayQuote[size - 1]
            if chars.count - lastIdx <= 3 {
                if size > 1 { mod[size - 2] = 4 }
                mod[size - 1] = -4
            }
        }
        
        // 第2次遍历：mod[i]由负变正时插入换行
        var loop2Mod1 = -1
        var ii = 0
        var jj = arrayQuote.count > 0 ? arrayQuote[0] - 1 : -1
        
        while ii < size {
            jj = arrayQuote[ii] - 1
            let loop2Mod2 = mod[ii]
            if loop2Mod1 < 0 && loop2Mod2 > 0 {
                if jj >= 0 && jj < chars.count && match(rule: markSentencesEnd, char: chars[jj]) {
                    insN.append(jj)
                }
            }
            loop2Mod1 = loop2Mod2
            ii += 1
        }
        
        // 使用字典验证 insN
        var insN1 = [Int]()
        for pos in insN {
            if pos < chars.count && match(rule: "\"'\u{201C}\u{201D}", char: chars[pos]) {
                let start = seekLast(str: str, key: "\"'\u{201C}\u{201D}", from: pos - 1, to: max(0, pos - wordMaxLength))
                if start > 0 {
                    let startIndex = str.index(str.startIndex, offsetBy: start + 1)
                    let endIndex = str.index(str.startIndex, offsetBy: min(pos, str.count))
                    let word = String(str[startIndex..<endIndex])
                    if dict.contains(word) {
                        continue
                    } else {
                        if start > 0 && match(rule: "的地得", char: chars[start]) {
                            continue
                        }
                    }
                }
            }
            insN1.append(pos)
        }
        insN = insN1
        
        // 去重排序
        insN = Array(Set(insN)).sorted()
        
        // 字典验证后的随机断句
        var forceSplitResults = [Int]()
        var progress = 0
        var jj2 = 0
        var nextLine = insN.count > 0 ? insN[0] : -1
        var gain = 3
        var minCount = 0
        var triggerCount = 2
        
        for i in arrayQuote.indices {
            let quote = arrayQuote[i]
            if quote > 0 {
                gain = 4; minCount = 2; triggerCount = 4
            } else {
                gain = 3; minCount = 0; triggerCount = 2
            }
            
            while jj2 < insN.count {
                if nextLine >= quote { break }
                let nl = insN[jj2]
                if progress < nl {
                    let startIdx = str.index(str.startIndex, offsetBy: progress)
                    let endIdx = str.index(str.startIndex, offsetBy: min(nl + 1, str.count))
                    let subs = String(str[startIdx..<endIdx])
                    forceSplitResults.append(contentsOf: forceSplit(str: subs, offset: progress, min: minCount, gain: gain, trigger: triggerCount))
                    progress = nl + 1
                }
                jj2 += 1
                nextLine = jj2 < insN.count ? insN[jj2] : -1
            }
            if progress < quote {
                let startIdx = str.index(str.startIndex, offsetBy: progress)
                let endIdx = str.index(str.startIndex, offsetBy: min(quote + 1, str.count))
                let subs = String(str[startIdx..<endIdx])
                forceSplitResults.append(contentsOf: forceSplit(str: subs, offset: progress, min: minCount, gain: gain, trigger: triggerCount))
                progress = quote + 1
            }
        }
        
        insN.append(contentsOf: forceSplitResults)
        insN = Array(Set(insN)).sorted()
        
        // 修正引号方向
        let insQuote = [Bool](repeating: false, count: size)
        opened = false
        for i in 0..<size {
            let p = arrayQuote[i]
            if mod[i] > 0 {
                // 正引号
                if opened { /* insQuote[i] = true // 需要插入引号 */ }
                opened = true
            } else if mod[i] < 0 {
                opened = false
            } else {
                opened = !opened
            }
        }
        
        // 完成字符串拼接
        var buffer = [Character]()
        buffer.reserveCapacity(Int(Double(str.count) * 1.15))
        var j = 0
        progress = 0
        nextLine = insN.count > 0 ? insN[0] : -1
        
        for i in arrayQuote.indices {
            let quote = arrayQuote[i]
            
            while j < insN.count {
                if nextLine >= quote { break }
                let nl = insN[j]
                if progress <= nl {
                    let startIdx = str.index(str.startIndex, offsetBy: progress)
                    let endIdx = str.index(str.startIndex, offsetBy: min(nl + 1, str.count))
                    buffer.append(contentsOf: str[startIdx..<endIdx])
                    buffer.append("\n")
                    progress = nl + 1
                }
                j += 1
                nextLine = j < insN.count ? insN[j] : -1
            }
            
            if progress < quote {
                let startIdx = str.index(str.startIndex, offsetBy: progress)
                let endIdx = str.index(str.startIndex, offsetBy: min(quote + 1, str.count))
                buffer.append(contentsOf: str[startIdx..<endIdx])
                progress = quote + 1
            }
            
            if i < insQuote.count && insQuote[i] && buffer.count > 2 {
                if buffer.last == "\n" {
                    buffer.append("\u{201C}")
                } else {
                    buffer.insert(contentsOf: "\u{201D}\n", at: buffer.count - 1)
                }
            }
        }
        
        while j < insN.count {
            let nl = insN[j]
            if progress <= nl {
                let startIdx = str.index(str.startIndex, offsetBy: progress)
                let endIdx = str.index(str.startIndex, offsetBy: min(nl + 1, str.count))
                buffer.append(contentsOf: str[startIdx..<endIdx])
                buffer.append("\n")
                progress = nl + 1
            }
            j += 1
        }
        
        if progress < str.count {
            let startIdx = str.index(str.startIndex, offsetBy: progress)
            buffer.append(contentsOf: str[startIdx...])
        }
        
        return String(buffer)
    }
    
    /// 从字符串提取引号包围的字典 — 对标 Android makeDict()
    private static func makeDict(str: String) -> [String] {
        let pattern = "(?<= [\"'\u{201C}\u{201D}])([^\n\"'\u{201C}\u{201D}]{1,\(wordMaxLength)})(?=[\"'\u{201C}\u{201D}])"
            .replacingOccurrences(of: " ", with: "")
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let nsRange = NSRange(str.startIndex..., in: str)
        let matches = regex.matches(in: str, range: nsRange)
        
        var cache = [String]()
        var dict = [String]()
        
        for match in matches {
            guard let range = Range(match.range, in: str) else { continue }
            let word = String(str[range])
            if cache.contains(word) {
                if !dict.contains(word) { dict.append(word) }
            } else {
                cache.append(word)
            }
        }
        return dict
    }
    
    /// 计算匹配位置索引 — 对标 Android seekIndexes()
    private static func seekIndexes(str: String, key: String, from: Int, to: Int, inOrder: Bool) -> [Int] {
        var list = [Int]()
        let chars = Array(str)
        let start = max(0, from)
        let end = min(chars.count - 1, to)
        
        var i = start
        while i <= end {
            let c = inOrder ? chars[i] : chars[chars.count - i - 1]
            if key.contains(c) {
                if let last = list.last, i - last == 1 {
                    list[list.count - 1] = i
                } else {
                    list.append(i)
                }
            }
            i += 1
        }
        return list
    }
    
    /// 计算字符串最后出现位置 — 对标 Android seekLast()
    private static func seekLast(str: String, key: String, from: Int, to: Int) -> Int {
        let chars = Array(str)
        var i = min(from, chars.count - 1)
        while i > to {
            if key.contains(chars[i]) { return i }
            i -= 1
        }
        return -1
    }
    
    /// 计算最短距离 — 对标 Android seekIndex()
    private static func seekIndex(str: String, key: String, from: Int, to: Int, inOrder: Bool) -> Int {
        let chars = Array(str)
        let start = max(0, from)
        let end = min(chars.count - 1, to)
        
        var i = start
        while i <= end {
            let c = inOrder ? chars[i] : chars[chars.count - i - 1]
            if key.contains(c) { return i }
            i += 1
        }
        return -1
    }
    
    /// 字符匹配
    private static func match(rule: String, char: Character) -> Bool {
        return rule.contains(char)
    }
    
    /// 去除全角空格和普通空格
    private static func removeWhitespace(_ str: String) -> String {
        return str.replacingOccurrences(of: "[\u{3000}\\s]+", with: "", options: .regularExpression)
    }
}

// MARK: - String 正则扩展

private extension String {
    var regexPattern: String { self }
    
    func matches(regex pattern: String) -> Bool {
        (try? NSRegularExpression(pattern: pattern, options: []))?
            .firstMatch(in: self, range: NSRange(self.startIndex..., in: self)) != nil
    }
    
    func replacingOccurrences(of pattern: String, with replacement: String, options: String.CompareOptions = []) -> String {
        // 使用正则替换
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options.contains(.regularExpression) ? [] : []) else { return self }
        let range = NSRange(self.startIndex..., in: self)
        return regex.stringByReplacingMatches(in: self, range: range, withTemplate: replacement)
    }
}