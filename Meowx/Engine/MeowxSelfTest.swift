import Foundation

enum MeowxSelfTest {
    static func runIfRequested() {
        guard CommandLine.arguments.contains("--self-test") else { return }
        exit(run())
    }

    static func run() -> Int32 {
        guard let handle = mpv_create() else {
            fputs("mpv_create failed\n", stderr)
            return 1
        }
        mpv_set_option_string(handle, "config", "no")
        mpv_set_option_string(handle, "terminal", "no")
        mpv_set_option_string(handle, "vo", "libmpv")
        let code = mpv_initialize(handle)
        guard code >= 0 else {
            let text = mpv_error_string(code).map({ String(cString: $0) }) ?? "unknown"
            fputs("mpv_initialize failed: \(text)\n", stderr)
            mpv_terminate_destroy(handle)
            return 1
        }
        if let value = mpv_get_property_string(handle, "mpv-version") {
            print(String(cString: value))
            mpv_free(value)
        } else {
            print("mpv")
        }
        fflush(stdout)
        mpv_terminate_destroy(handle)
        return 0
    }
}
