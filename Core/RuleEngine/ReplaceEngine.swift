//
//  ReplaceRule+CoreDataClass.swift
//  Legado-iOS
//
//  替换规则实体
//

import Foundation
import CoreData

@objc(ReplaceRule)
public class ReplaceRule: NSManagedObject {
    @NSManaged public var ruleId: UUID
    @NSManaged public var name: String
    @NSManaged public var pattern: String
    @NSManaged public var replacement: String
    @NSManaged public var scope: String  // global, source, book
    @NSManaged public var scopeId: String?
    @NSManaged public var isRegex: Bool
    @NSManaged public var enabled: Bool
    @NSManaged public var priority: Int32
    @NSManaged public var order: Int32
}

extension ReplaceRule {
    @nonobjc class func fetchRequest() -> NSFetchRequest<ReplaceRule> {
        return NSFetchRequest<ReplaceRule>(entityName: "ReplaceRule")
    }
    
    static func create(in context: NSManagedObjectContext) -> ReplaceRule {
        let entity = NSEntityDescription.entity(forEntityName: "ReplaceRule", in: context)!
        let rule = ReplaceRule(entity: entity, insertInto: context)
        rule.ruleId = UUID()
        rule.enabled = true
        rule.isRegex = true
        rule.priority = 0
        rule.order = 0
        rule.scope = "global"
        return rule
    }
}

//
//  ReplaceEngine.swift
//  Legado-iOS
//
//  替换规则引擎
//

import Foundation

class ReplaceEngine {
    static let shared = ReplaceEngine()
    
    /// 应用替换规则
    func apply(text: String, rules: [ReplaceRule]) -> String {
        var result = text
        
        // 按优先级排序
        let sortedRules = rules.sorted { $0.priority > $1.priority }
        
        for rule in sortedRules where rule.enabled {
            if rule.isRegex {
                // 正则替换
                if let regex = try? NSRegularExpression(pattern: rule.pattern) {
                    let range = NSRange(result.startIndex..., in: result)
                    result = regex.stringByReplacingMatches(
                        in: result,
                        range: range,
                        withTemplate: rule.replacement
                    )
                }
            } else {
                // 普通文本替换
                result = result.replacingOccurrences(of: rule.pattern, with: rule.replacement)
            }
        }
        
        return result
    }
    
    /// 净化内容（广告替换等）
    func purify(content: String, rules: [ReplaceRule]) -> String {
        return apply(text: content, rules: rules.filter { $0.scope == "global" })
    }
}
