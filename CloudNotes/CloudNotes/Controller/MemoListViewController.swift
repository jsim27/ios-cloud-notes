import UIKit
import CoreData

private let reuseIdentifier = "Cell"

final class MemoListViewController: UITableViewController {
  weak var delegate: MemoDisplayable?
  private var managedContext: NSManagedObjectContext!
  private var memos = [Memo]()
  private let firstRowIndexPath = IndexPath(row: 0, section: 0)
  private var currentMemoIndexPath = IndexPath(row: 0, section: 0)
  private var keyboardShowNotification: NSObjectProtocol?
  private var keyboardHideNotification: NSObjectProtocol?

  deinit {
    removeObservers()
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setNavigationBar()
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: reuseIdentifier)
    tableView.allowsSelectionDuringEditing = true
    loadCoreData()
    if memos.isEmpty == false {
      loadDetail(at: firstRowIndexPath)
    }
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if memos.isEmpty == false {
      tableView.selectRow(at: currentMemoIndexPath, animated: false, scrollPosition: .top)
    }
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    addObservers()
  }
  
  override func setEditing(_ editing: Bool, animated: Bool) {
    super.setEditing(editing, animated: animated)
    tableView.selectRow(at: currentMemoIndexPath, animated: false, scrollPosition: .none)
  }

  private func addObservers() {
    if keyboardShowNotification == nil {
      let bottomInset = view.safeAreaInsets.bottom
      let addSafeAreaInset: (Notification) -> Void = { [weak self] notification in
        guard
          let self = self,
          let userInfo = notification.userInfo,
          let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
          return
        }
        self.additionalSafeAreaInsets.bottom = keyboardFrame.height - bottomInset
      }
      
      keyboardShowNotification = NotificationCenter.default.addObserver(
        forName: UIResponder.keyboardWillShowNotification,
        object: nil,
        queue: nil,
        using: addSafeAreaInset
      )
    }
    if keyboardHideNotification == nil {
      let removeSafeAreaInset: (Notification) -> Void = { [weak self] _ in
        self?.additionalSafeAreaInsets.bottom = 0
      }
      
      keyboardHideNotification = NotificationCenter.default.addObserver(
        forName: UIResponder.keyboardWillHideNotification,
        object: nil,
        queue: nil,
        using: removeSafeAreaInset
      )
    }
  }

  private func removeObservers() {
    if let keyboardShowNotification = keyboardShowNotification {
      NotificationCenter.default.removeObserver(keyboardShowNotification)
      self.keyboardShowNotification = nil
    }
    if let keyboardHideNotification = keyboardHideNotification {
      NotificationCenter.default.removeObserver(keyboardHideNotification)
      self.keyboardHideNotification = nil
    }
  }

  private func setNavigationBar() {
    let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addMemo))
    navigationItem.rightBarButtonItem = addButton
    navigationItem.title = "메모"
  }

  @objc private func addMemo() {
    guard let entity = NSEntityDescription.entity(forEntityName: "Memo", in: managedContext) else { return }
    let newMemo = Memo(entity: entity, insertInto: managedContext)
    newMemo.id = UUID()
    newMemo.lastModified = Date()
    if memos.isEmpty {
      memos.append(newMemo)
      if tableView.numberOfRows(inSection: 0) == .zero {
        tableView.insertRows(at: [firstRowIndexPath], with: .fade)
      } else {
        tableView.reloadRows(at: [firstRowIndexPath], with: .fade)
      }
    } else {
      memos.insert(newMemo, at: 0)
      tableView.insertRows(at: [firstRowIndexPath], with: .fade)
    }
    tableView.selectRow(at: firstRowIndexPath, animated: true, scrollPosition: .top)
    try? managedContext.save()
    loadDetail(at: firstRowIndexPath)
  }
  
  private func loadCoreData() {
    let appDelegate = UIApplication.shared.delegate as? AppDelegate
    managedContext = appDelegate?.persistentContainer.viewContext
    
    let request = Memo.fetchRequest()
    do {
      let results = try managedContext.fetch(request)
      memos = results
    } catch let error as NSError {
      print("Could not fetch \(error), \(error.userInfo)")
    }
  }

  private func loadDetail(at indexPath: IndexPath) {
    let memo = memos[indexPath.row]
    currentMemoIndexPath = indexPath
    delegate?.show(memo: memo)
  }
}

// MARK: - MemoStorable

extension MemoListViewController: MemoStorable {
  func updateMemo(title: String, body: String, lastModified: Date) {
    let index = currentMemoIndexPath.row
    let memo = memos[index]
    memo.title = title
    memo.body = body
    memo.lastModified = lastModified
    try? managedContext.save()
    
    tableView.reloadData()
    tableView.selectRow(at: currentMemoIndexPath, animated: false, scrollPosition: .none)
  }
}

// MARK: - UITableViewDataSource

extension MemoListViewController {
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return memos.count
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
    let memo = memos[indexPath.row]
    var configuration = cell.defaultContentConfiguration()
    let title = memo.title ?? ""
    configuration.text = title.isEmpty ? "새로운 메모" : title
    configuration.secondaryAttributedText = memo.subtitle
    configuration.textProperties.numberOfLines = 1
    configuration.secondaryTextProperties.numberOfLines = 1
    cell.contentConfiguration = configuration
    cell.accessoryType = .disclosureIndicator
    return cell
  }
}

// MARK: - UITableViewDelegate

extension MemoListViewController {
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    loadDetail(at: indexPath)
    splitViewController?.show(.secondary)
  }
  
  override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
    let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [unowned self] _, _, completionHandler in
      let memo = self.memos[indexPath.row]
      self.managedContext.delete(memo)
      self.memos.remove(at: indexPath.row)
      
      if self.memos.isEmpty {
        self.addMemo()
      } else {
        tableView.deleteRows(at: [indexPath], with: .fade)
        self.currentMemoIndexPath.row -= self.currentMemoIndexPath.row > indexPath.row ?  1 : 0
      }
      completionHandler(true)
    }
    deleteAction.image = UIImage(systemName: "trash")
    let configuration = UISwipeActionsConfiguration(actions: [deleteAction])
    return configuration
  }
  
  override func tableView(_ tableView: UITableView, didEndEditingRowAt indexPath: IndexPath?) {
    let section = currentMemoIndexPath.section
    let numberOfRows = tableView.numberOfRows(inSection: section)
    let maximumVaildRow = numberOfRows - 1
    let willSelectIndexPath: IndexPath
    
    if maximumVaildRow < currentMemoIndexPath.row {
      willSelectIndexPath = IndexPath(row: maximumVaildRow, section: section)
    } else if numberOfRows > 1 {
      willSelectIndexPath = currentMemoIndexPath
    } else {
      willSelectIndexPath = firstRowIndexPath
    }
    tableView.selectRow(at: willSelectIndexPath, animated: false, scrollPosition: .none)
    self.loadDetail(at: willSelectIndexPath)
  }
}
