import func Darwin.exit

let runtime = T1HelperRuntime()
switch runtime.start() {
case .started:
  break
case .permissionDenied:
  exit(0)
case .failed:
  exit(1)
}
runtime.run()
runtime.stop()
