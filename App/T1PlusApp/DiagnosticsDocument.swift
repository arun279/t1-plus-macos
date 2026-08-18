import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct DiagnosticsDocument: FileDocument {
  static let readableContentTypes: [UTType] = [.plainText]

  let text: String

  init(text: String) {
    self.text = text
  }

  init(configuration: ReadConfiguration) throws {
    guard
      let data = configuration.file.regularFileContents,
      let text = String(data: data, encoding: .utf8)
    else {
      throw CocoaError(.fileReadCorruptFile)
    }
    self.text = text
  }

  func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: Data(text.utf8))
  }
}
