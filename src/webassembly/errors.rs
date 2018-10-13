// WebAssembly.CompileError(message, fileName, lineNumber)

// The WebAssembly.CompileError() constructor creates a new WebAssembly
// CompileError object, which indicates an error during WebAssembly
// decoding or validation


// WebAssembly.LinkError(message, fileName, lineNumber)

// The WebAssembly.LinkError() constructor creates a new WebAssembly
// LinkError object, which indicates an error during module instantiation
// (besides traps from the start function).

// new WebAssembly.RuntimeError(message, fileName, lineNumber)

// The WebAssembly.RuntimeError() constructor creates a new WebAssembly
// RuntimeError object — the type that is thrown whenever WebAssembly
//  specifies a trap.


error_chain! {
    // Define additional `ErrorKind` variants.  Define custom responses with the
    // `description` and `display` calls.
    errors {
        CompileError(reason: String) {
            description("WebAssembly compilation error")
            display("Compilation error: '{}'", reason)
        }
        LinkError {
            description("WebAssembly link error")
            // display("invalid toolchain name: '{}'", t)
        }
        RuntimeError {
            description("WebAssembly runtime error")
            // display("invalid toolchain name: '{}'", t)
        }
    }
}