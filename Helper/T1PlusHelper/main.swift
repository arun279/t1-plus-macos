import Darwin

let runtime = T1HelperRuntime()
guard runtime.start() else {
  exit(EXIT_FAILURE)
}
runtime.run()
runtime.stop()
