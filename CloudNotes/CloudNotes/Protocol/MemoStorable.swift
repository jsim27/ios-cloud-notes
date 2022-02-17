import Foundation.NSDate

protocol MemoStorable: AnyObject {
  func updateMemo(title: String, body: String, lastModified: Date)
}
