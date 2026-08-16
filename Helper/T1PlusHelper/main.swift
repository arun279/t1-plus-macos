import func Darwin.exit

let runtime = T1HelperRuntime()
guard runtime.start() else {
  exit(1)
}
runtime.run()
runtime.stop()
