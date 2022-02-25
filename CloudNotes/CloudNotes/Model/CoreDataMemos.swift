import Foundation
import CoreData

class CoreDataMemos {
  static let shared = CoreDataMemos()
  private var memos = [Memo]()
  
  private lazy var entity = NSEntityDescription.entity(forEntityName: "\(Memo.self)", in: managedContext)
  private lazy var managedContext = persistentContainer.viewContext
  private lazy var persistentContainer: NSPersistentCloudKitContainer = {
    let container = NSPersistentCloudKitContainer(name: "CloudNotes")
    container.loadPersistentStores(completionHandler: { (storeDescription, error) in
      if let error = error as NSError? {
        fatalError("Unresolved error \(error), \(error.userInfo)")
      }
    })
    return container
  }()

  private init() {
    do {
      try reload()
    } catch let error {
      #if DEBUG
      print(error)
      #endif
    }
  }
  
  func saveContext() {
    let context = persistentContainer.viewContext
    if context.hasChanges {
      do {
        try context.save()
      } catch {

        let nserror = error as NSError
        fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
      }
    }
  }
}

extension CoreDataMemos {
  var count: Int {
    return memos.count
  }
  
  var isEmpty: Bool {
    return memos.isEmpty
  }
  
  private func insert(_ memo: Memo, at index: Int) throws {
    memos.insert(memo, at: index)
    try managedContext.save()
  }
  
  func createFirst(title: String, body: String) throws {
    guard let entity = entity else { return }
    let memo = Memo(entity: entity, insertInto: managedContext)
    memo.title = title
    memo.body = body
    memo.lastModified = Date()
    memo.id = UUID()
    try insert(memo, at: 0)
  }
  
  func reload() throws {
    let request: NSFetchRequest<Memo> = Memo.fetchRequest()
    request.sortDescriptors = [NSSortDescriptor(keyPath: \Memo.lastModified, ascending: false)]
    let persistentData = try managedContext.fetch(request)
    memos = persistentData
  }

  func remove(at index: Int) throws {
    let memo = self[index]
    managedContext.delete(memo)
    try managedContext.save()
    memos.remove(at: index)
  }

  func update(at index: Int, title: String, body: String) throws {
    let memo = self[index]
    memo.title = title
    memo.body = body
    memo.lastModified = Date()
    memos = memos.sorted(by: { (lhs, rhs) -> Bool in
      guard let lhsDate = lhs.lastModified, let rhsDate = rhs.lastModified else { return true }
      return lhsDate > rhsDate
    })
    try managedContext.save()
  }
}

extension CoreDataMemos {
  subscript(index: Int) -> Memo {
    return memos[index]
  }
}
