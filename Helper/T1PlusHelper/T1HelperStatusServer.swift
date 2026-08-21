import Foundation

final class T1HelperStatusServer: NSObject, NSXPCListenerDelegate, T1HelperStatusProtocol {
  private let listener = NSXPCListener(
    machServiceName: T1HelperMachService.name
  )

  func start() {
    listener.delegate = self
    listener.resume()
  }

  func stop() {
    listener.invalidate()
  }

  func listener(
    _: NSXPCListener,
    shouldAcceptNewConnection connection: NSXPCConnection
  ) -> Bool {
    connection.exportedInterface = NSXPCInterface(
      with: T1HelperStatusProtocol.self
    )
    connection.exportedObject = self
    connection.resume()
    return true
  }

  func ping(reply: @escaping () -> Void) {
    reply()
  }
}
