import T1Protocol

struct T1ContactBuffer: Sendable {
  private var first: T1Contact?
  private var second: T1Contact?
  private var third: T1Contact?
  private var fourth: T1Contact?

  private(set) var count = 0

  mutating func append(_ contact: T1Contact) {
    switch count {
    case 0: first = contact
    case 1: second = contact
    case 2: third = contact
    case 3: fourth = contact
    default: preconditionFailure("T1 contact buffer capacity exceeded")
    }
    count += 1
  }

  subscript(index: Int) -> T1Contact {
    let contact: T1Contact?
    switch index {
    case 0: contact = first
    case 1: contact = second
    case 2: contact = third
    case 3: contact = fourth
    default: preconditionFailure("T1 contact buffer index must be in 0..<4")
    }
    guard index < count, let contact else {
      preconditionFailure("T1 contact buffer index is not populated")
    }
    return contact
  }
}

struct T1TrackedContacts: Sendable {
  private var zero: T1Contact?
  private var one: T1Contact?
  private var two: T1Contact?
  private var three: T1Contact?
  private var four: T1Contact?
  private var five: T1Contact?
  private var six: T1Contact?
  private var seven: T1Contact?

  mutating func remember(_ contact: T1Contact) {
    switch contact.identifier {
    case 0: zero = contact
    case 1: one = contact
    case 2: two = contact
    case 3: three = contact
    case 4: four = contact
    case 5: five = contact
    case 6: six = contact
    case 7: seven = contact
    default: break
    }
  }

  func copy(into output: inout T1ContactBuffer) {
    append(zero, to: &output)
    append(one, to: &output)
    append(two, to: &output)
    append(three, to: &output)
    append(four, to: &output)
    append(five, to: &output)
    append(six, to: &output)
    append(seven, to: &output)
  }

  private func append(_ contact: T1Contact?, to output: inout T1ContactBuffer) {
    guard output.count < T1ReportDecoder.contactSlotCount, let contact else { return }
    output.append(contact)
  }
}
