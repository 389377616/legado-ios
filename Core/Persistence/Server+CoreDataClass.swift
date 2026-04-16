import Foundation
import CoreData

@objc(Server)
public class Server: NSManagedObject {
    @NSManaged public var id: Int64
    @NSManaged public var name: String
    @NSManaged public var configUrl: String
    @NSManaged public var type: Int32
    @NSManaged public var customOrder: Int32
    @NSManaged public var lastUpdateTime: Int64
}

extension Server {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Server> {
        return NSFetchRequest<Server>(entityName: "Server")
    }

    enum ServerType: Int32 {
        case webDav = 0
        case httpServer = 1
        case sftp = 2
    }

    var serverType: ServerType? {
        ServerType(rawValue: type)
    }

    static func create(in context: NSManagedObjectContext) -> Server {
        let entity = NSEntityDescription.entity(forEntityName: "Server", in: context)!
        let server = Server(entity: entity, insertInto: context)
        server.id = Int64(Date().timeIntervalSince1970 * 1000)
        server.name = ""
        server.configUrl = ""
        server.type = 0
        server.customOrder = 0
        server.lastUpdateTime = 0
        return server
    }
}

extension Server {
    struct CodableForm: Codable {
        var id: Int64
        var name: String
        var configUrl: String
        var type: Int32
        var customOrder: Int32
        var lastUpdateTime: Int64
    }

    var codableForm: CodableForm {
        CodableForm(id: id, name: name, configUrl: configUrl, type: type,
                     customOrder: customOrder, lastUpdateTime: lastUpdateTime)
    }

    func update(from form: CodableForm) {
        id = form.id
        name = form.name
        configUrl = form.configUrl
        type = form.type
        customOrder = form.customOrder
        lastUpdateTime = form.lastUpdateTime
    }
}
