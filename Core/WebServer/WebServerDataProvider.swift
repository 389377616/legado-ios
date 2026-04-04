import Foundation
import CoreData

struct WebBookDTO: Codable {
    let bookId: String
    let name: String
    let author: String
    let originName: String
    let bookUrl: String
}

struct WebSourceDTO: Codable {
    let sourceId: String
    let name: String
    let url: String
    let group: String
    let enabled: Bool
}

protocol WebServerDataProviding {
    func fetchBooks() throws -> [WebBookDTO]
    func fetchSources() throws -> [WebSourceDTO]
}

final class CoreDataWebServerDataProvider: WebServerDataProviding {
    private let stack: CoreDataStack

    init(stack: CoreDataStack = .shared) {
        self.stack = stack
    }

    func fetchBooks() throws -> [WebBookDTO] {
        let context = stack.newBackgroundContext()
        var result: [WebBookDTO] = []
        var fetchError: Error?

        context.performAndWait {
            do {
                let request: NSFetchRequest<Book> = Book.fetchRequest()
                request.fetchLimit = 300
                request.returnsObjectsAsFaults = false
                request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]

                let books = try context.fetch(request)
                result = books.map {
                    WebBookDTO(
                        bookId: $0.bookId.uuidString,
                        name: $0.name,
                        author: $0.author,
                        originName: $0.originName,
                        bookUrl: $0.bookUrl
                    )
                }
            } catch {
                fetchError = error
            }
        }

        if let fetchError {
            throw fetchError
        }

        return result
    }

    func fetchSources() throws -> [WebSourceDTO] {
        let context = stack.newBackgroundContext()
        var result: [WebSourceDTO] = []
        var fetchError: Error?

        context.performAndWait {
            do {
                let request: NSFetchRequest<BookSource> = BookSource.fetchRequest()
                request.fetchLimit = 300
                request.returnsObjectsAsFaults = false
                request.sortDescriptors = [NSSortDescriptor(key: "customOrder", ascending: true)]

                let sources = try context.fetch(request)
                result = sources.map {
                    WebSourceDTO(
                        sourceId: $0.sourceId.uuidString,
                        name: $0.bookSourceName,
                        url: $0.bookSourceUrl,
                        group: $0.bookSourceGroup ?? "",
                        enabled: $0.enabled
                    )
                }
            } catch {
                fetchError = error
            }
        }

        if let fetchError {
            throw fetchError
        }

        return result
    }
}
