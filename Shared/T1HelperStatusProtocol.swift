import Foundation

enum T1HelperMachService {
  static let name = "io.github.arun279.t1plus.helper.status"
}

@objc(T1HelperStatusProtocol)
protocol T1HelperStatusProtocol: AnyObject {
  func ping(reply: @escaping () -> Void)
}
