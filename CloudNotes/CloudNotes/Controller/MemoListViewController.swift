import UIKit

final class MemoListViewController: UITableViewController {
  weak var delegate: MemoDisplayable?
  private let reuseIdentifier = "Cell"
  private var memos = CoreDataMemos.shared
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
    do {
      try memos.reload()
    } catch {
      showAlert(title: "Load fail")
    }
    
    if memos.isEmpty {
      delegate?.set(editable: false, needClear: true)
    } else {
      loadDetail(at: .first)
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

  @objc private func shareActionTapped(_ sender: UIView, completionHandler: @escaping (Bool) -> Void) {
    let memo = memos[currentMemoIndexPath.row]
    let textToShare = memo.title ?? "" + "\n" + (memo.body ?? "")
    let activityViewController = UIActivityViewController(activityItems: [textToShare], applicationActivities: nil)
    activityViewController.completionWithItemsHandler = { _, completed, _, _ in
      completionHandler(completed)
    }
    activityViewController.popoverPresentationController?.sourceView = sender
    present(activityViewController, animated: true)
  }

  @objc private func addMemo() {
    do {
      try memos.createFirst(title: "", body: "")
      tableView.insertRows(at: [.first], with: .fade)
      tableView.selectRow(at: .first, animated: true, scrollPosition: .top)
      loadDetail(at: .first)
    } catch {
      showAlert(title: "Save fail")
    }
  }
  
  private func removeMemo(at indexPath: IndexPath) {
    do {
      try memos.remove(at: indexPath.row)
      tableView.deleteRows(at: [indexPath], with: .fade)
      if memos.isEmpty == false {
        let lastIndex = memos.count - 1
        currentMemoIndexPath.row -= currentMemoIndexPath.row > lastIndex ?  1 : 0
        tableView.selectRow(at: currentMemoIndexPath, animated: true, scrollPosition: .none)
        loadDetail(at: currentMemoIndexPath)
      } else {
        delegate?.set(editable: false, needClear: true)
      }
    } catch {
      showAlert(title: "Remove fail")
    }
  }
  
  private func showRemoveMemo(at indexPath: IndexPath) {
    let alertController = UIAlertController(title: "진짜요?", message: "정말로 삭제하시겠어요?", preferredStyle: .alert)
    let cancel = UIAlertAction(title: "취소", style: .cancel)
    let delete = UIAlertAction(title: "삭제", style: .destructive) { [weak self] _ in
      self?.removeMemo(at: indexPath)
    }
    alertController.addAction(cancel)
    alertController.addAction(delete)
    present(alertController, animated: true)
  }

  private func loadDetail(at indexPath: IndexPath) {
    let memo = memos[indexPath.row]
    currentMemoIndexPath = indexPath
    delegate?.showMemo(title: memo.title, body: memo.body)
    delegate?.set(editable: true, needClear: false)
  }
}

// MARK: - MemoStorable

extension MemoListViewController: MemoStorable {
  func updateMemo(title: String, body: String) {
    let index = currentMemoIndexPath.row
    do {
      try memos.update(at: index, title: title, body: body)
      tableView.moveRow(at: currentMemoIndexPath, to: .first)
      tableView.reloadRows(at: [.first], with: .none)
      currentMemoIndexPath = .first
      tableView.selectRow(at: currentMemoIndexPath, animated: false, scrollPosition: .none)
    } catch {
      showAlert(title: "Update fail")
    }
  }
  
  func removeCurrentMemo() {
    if memos.isEmpty == false {
      showRemoveMemo(at: currentMemoIndexPath)
    }
  }
}

// MARK: - UITableViewDataSource

extension MemoListViewController {
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if memos.isEmpty {
      tableView.separatorStyle = .none
      setBackgroundView(with: "메모 없음")
    } else {
      tableView.separatorStyle = .singleLine
      tableView.backgroundView = nil
    }
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
    let shareAction = UIContextualAction(style: .normal, title: "Share") { [weak self] _, sourceView, completionHandler in
      self?.shareActionTapped(sourceView, completionHandler: completionHandler)
    }
    shareAction.image = UIImage(systemName: "square.and.arrow.up")
    let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completionHandler in
      self?.showRemoveMemo(at: indexPath)
      completionHandler(true)
    }
    deleteAction.image = UIImage(systemName: "trash")
    let configuration = UISwipeActionsConfiguration(actions: [deleteAction, shareAction])
    return configuration
  }
  
  override func tableView(_ tableView: UITableView, didEndEditingRowAt indexPath: IndexPath?) {
    guard tableView.numberOfRows(inSection: 0) != 0 else { return }
    let section = currentMemoIndexPath.section
    let numberOfRows = tableView.numberOfRows(inSection: section)
    let maximumVaildRow = numberOfRows - 1
    let willSelectIndexPath: IndexPath

    if maximumVaildRow < currentMemoIndexPath.row {
      willSelectIndexPath = IndexPath(row: maximumVaildRow, section: section)
    } else if numberOfRows > 1 {
      willSelectIndexPath = currentMemoIndexPath
    } else {
      willSelectIndexPath = .first
    }
    tableView.selectRow(at: willSelectIndexPath, animated: false, scrollPosition: .none)
    loadDetail(at: willSelectIndexPath)
  }
}

private extension IndexPath {
  static var first: Self {
    return .init(row: 0, section: 0)
  }
}
