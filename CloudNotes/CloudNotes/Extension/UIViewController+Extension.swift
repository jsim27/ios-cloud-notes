import UIKit

extension UIViewController {
  func addKeyboardObserver() {
    let keyboardWillShow: (Notification) -> Void = { [weak self] notification in
      guard
        let self = self,
        let userInfo = notification.userInfo,
        let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
          return
        }
      let safeAreaBottomInset = self.view.safeAreaInsets.bottom
      self.additionalSafeAreaInsets.bottom = keyboardFrame.height - safeAreaBottomInset
    }
    
    let keyboardWillHide: (Notification) -> Void = { [weak self] _ in
      self?.additionalSafeAreaInsets.bottom = .zero
    }
    
    NotificationCenter.default.addObserver(
      forName: UIResponder.keyboardWillShowNotification,
      object: nil,
      queue: nil,
      using: keyboardWillShow
    )
    NotificationCenter.default.addObserver(
      forName: UIResponder.keyboardWillHideNotification,
      object: nil,
      queue: nil,
      using: keyboardWillHide
    )
  }
}
