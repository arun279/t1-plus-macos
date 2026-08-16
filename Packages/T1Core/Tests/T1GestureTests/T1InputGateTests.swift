import T1Gestures
import Testing

@Suite("Input gate")
struct T1InputGateTests {
  @Test("Repeated suspension preserves the lift requirement")
  func repeatedSuspensionPreservesLiftRequirement() {
    var gate = T1InputGate()

    gate.suspend(.system, interactionActive: true)
    gate.suspend(.system, interactionActive: false)
    gate.resume(.system)

    let heldContact = gate.shouldProcess(hasInteraction: true)
    let lift = gate.shouldProcess(hasInteraction: false)
    let nextInteraction = gate.shouldProcess(hasInteraction: true)

    #expect(!heldContact)
    #expect(!lift)
    #expect(nextInteraction)
  }

  @Test("A settings change cannot clear an existing lift requirement")
  func settingsChangePreservesLiftRequirement() {
    var gate = T1InputGate()

    gate.requireLift(interactionActive: true)
    gate.requireLift(interactionActive: false)

    let heldContact = gate.shouldProcess(hasInteraction: true)
    let lift = gate.shouldProcess(hasInteraction: false)
    let nextInteraction = gate.shouldProcess(hasInteraction: true)

    #expect(!heldContact)
    #expect(!lift)
    #expect(nextInteraction)
  }

  @Test("A lift observed while suspended clears the gate")
  func suspendedLiftClearsGate() {
    var gate = T1InputGate()

    gate.suspend(.system, interactionActive: true)
    let lift = gate.shouldProcess(hasInteraction: false)
    gate.resume(.system)
    let nextInteraction = gate.shouldProcess(hasInteraction: true)

    #expect(!lift)
    #expect(nextInteraction)
  }

  @Test("System wake cannot resume an inactive session")
  func overlappingSuspensionReasonsRemainSuspended() {
    var gate = T1InputGate()

    gate.suspend(.session, interactionActive: true)
    gate.suspend(.system, interactionActive: false)
    let fullyResumed = gate.resume(.system)

    let heldContactWhileInactive = gate.shouldProcess(hasInteraction: true)
    gate.resume(.session)
    let heldContactAfterActivation = gate.shouldProcess(hasInteraction: true)
    let lift = gate.shouldProcess(hasInteraction: false)
    let nextInteraction = gate.shouldProcess(hasInteraction: true)

    #expect(!heldContactWhileInactive)
    #expect(!fullyResumed)
    #expect(!heldContactAfterActivation)
    #expect(!lift)
    #expect(nextInteraction)
  }
}
