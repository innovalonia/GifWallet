//
//  Created by Pierluigi Cifani on 28/03/2018.
//  Copyright © 2018 Code Crafters. All rights reserved.
//

import CoreData
import Async

public class DataStore {

    private let persistentStore: NSPersistentContainer
    public var storeIsReady: Bool = false

    public init(kind: Kind = .sqlite, shouldLoadAsync: Bool = true) {
        guard
            let path = Bundle(for: DataStore.self).path(forResource: "Model", ofType: "momd"),
            let model = NSManagedObjectModel(contentsOf: URL(fileURLWithPath: path)) else {
            fatalError()
        }

        persistentStore = NSPersistentContainer(
            name: "GifModel",
            managedObjectModel: model
        )

        let description = NSPersistentStoreDescription()
        description.type = kind.coreDataRepresentation
        description.shouldAddStoreAsynchronously = shouldLoadAsync
        persistentStore.persistentStoreDescriptions = [description]
    }

    public func loadAndMigrateIfNeeded() -> Future<()> {
        let promise = Promise<()>()
        persistentStore.loadPersistentStores { (description, error) in
            if let error = error {
                promise.fail(error)
            } else {
                self.storeIsReady = true
                promise.complete(())
            }
        }
        return promise.future
    }

    //MARK: GIF Creation
    func createGIF(giphyID: String, title: String, subtitle: String, url: URL, tags: Set<String>) -> Future<()> {
        assert(self.storeIsReady)

        let promise = Promise<()>()
        self.persistentStore.performBackgroundTask { (moc) in
            let managedGIF = self.fetchGIF(id: giphyID, moc: moc) ?? ManagedGIF(entity: ManagedGIF.entity(), insertInto: moc)
            managedGIF.title = title
            managedGIF.subtitle = subtitle
            managedGIF.remoteURL = url.absoluteString
            managedGIF.giphyID = giphyID
            managedGIF.creationDate = Date()

            do {
                try moc.save()
                promise.complete()
            } catch let error {
                promise.fail(error)
            }
        }
        return promise.future
    }

    func fetchGIF(id: String) throws -> ManagedGIF? {
        return self.fetchGIF(id: id, moc: self.persistentStore.viewContext)
    }

    private func fetchGIF(id: String, moc: NSManagedObjectContext) -> ManagedGIF? {
        assert(self.storeIsReady)
        let fetchRequest: NSFetchRequest<ManagedGIF> = ManagedGIF.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "giphyID == %@", id)
        let managedGIFs = try? moc.fetch(fetchRequest)
        return managedGIFs?.first
    }
}

extension DataStore {

    public enum Kind {
        case sqlite
        case memory
    }

    public enum Error: Swift.Error {
        case dataStoreNotInitialized
    }
}
extension DataStore.Kind {
    fileprivate var coreDataRepresentation: String {
        switch self {
        case .memory:
            return NSInMemoryStoreType
        case .sqlite:
            return NSSQLiteStoreType
        }
    }
}
