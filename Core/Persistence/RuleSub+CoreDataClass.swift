//
//  RuleSub+CoreDataClass.swift
//  Legado-iOS
//
//  规则订阅实体 — 对标 Android RuleSub
//

import Foundation
import CoreData

@objc(RuleSub)
public class RuleSub: NSManagedObject {
    @NSManaged public var id: Int64
    @NSManaged public var name: String
    @NSManaged public var url: String
    @NSManaged public var type: Int32          // 0=BookSource, 1=RssSource, 2=ReplaceRule, 3=HttpTTS, 4=DictRule, 5=TxtTocRule
    @NSManaged public var customOrder: Int32
    @NSManaged public var autoUpdate: Bool
    @NSManaged public var lastUpdateTime: Int64
}

// MARK: - Fetch Request
extension RuleSub {
    @nonobjc class func fetchRequest() -> NSFetchRequest<RuleSub> {
        return NSFetchRequest<RuleSub>(entityName: "RuleSub")
    }
}

// MARK: - 类型枚举
extension RuleSub {
    enum SubType: Int32, CaseIterable {
        case bookSource = 0
        case rssSource = 1
        case replaceRule = 2
        case httpTTS = 3
        case dictRule = 4
        case txtTocRule = 5

        public static var allCases: [RuleSub.SubType] {
            [.bookSource, .rssSource, .replaceRule, .httpTTS, .dictRule, .txtTocRule]
        }

        var title: String {
            switch self {
            case .bookSource: return "书源"
            case .rssSource: return "RSS源"
            case .replaceRule: return "替换规则"
            case .httpTTS: return "在线TTS"
            case .dictRule: return "词典规则"
            case .txtTocRule: return "TXT目录规则"
            }
        }

        var iconName: String {
            switch self {
            case .bookSource: return "book"
            case .rssSource: return "antenna.radiowaves.left.and.right"
            case .replaceRule: return "arrow.triangle.2.circlepath"
            case .httpTTS: return "speaker.wave.2"
            case .dictRule: return "character.book.closed"
            case .txtTocRule: return "list.bullet.indent"
            }
        }
    }

    var subType: SubType? {
        SubType(rawValue: type)
    }
}

// MARK: - 初始化
extension RuleSub {
    static func create(in context: NSManagedObjectContext) -> RuleSub {
        let entity = NSEntityDescription.entity(forEntityName: "RuleSub", in: context)!
        let sub = RuleSub(entity: entity, insertInto: context)
        sub.id = Int64(Date().timeIntervalSince1970 * 1000)
        sub.name = ""
        sub.url = ""
        sub.type = 0
        sub.customOrder = 0
        sub.autoUpdate = false
        sub.lastUpdateTime = 0
        return sub
    }
}

// MARK: - JSON Codable
extension RuleSub {
    struct CodableForm: Codable {
        var id: Int64
        var name: String
        var url: String
        var type: Int32
        var customOrder: Int32
        var autoUpdate: Bool
        var lastUpdateTime: Int64
    }

    var codableForm: CodableForm {
        CodableForm(id: id, name: name, url: url, type: type,
                     customOrder: customOrder, autoUpdate: autoUpdate,
                     lastUpdateTime: lastUpdateTime)
    }

    func update(from form: CodableForm) {
        self.id = form.id
        self.name = form.name
        self.url = form.url
        self.type = form.type
        self.customOrder = form.customOrder
        self.autoUpdate = form.autoUpdate
        self.lastUpdateTime = form.lastUpdateTime
    }
}
