# OpenAC RSA X.509 Certificate Swift Package

Swift bindings for the OpenAC zero-knowledge proof system that proves and verifies **RSA-X.509-Cert** — wrapping the mobile bindings built from the [`RSA-X.509-Cert`](https://github.com/privacy-ethereum/zkID/tree/RSA-X.509-Cert) branch of [zkID](https://github.com/privacy-ethereum/zkID) to expose `setupKeys` / `prove*` / `verify*` and related circuit helpers (cert_chain_rs4096, user_sig_rs2048) for proof generation and verification on iOS.

The prebuilt binaries are distributed via the [zkID RSA-X.509-Cert latest release](https://github.com/privacy-ethereum/zkID/releases/tag/RSA-X.509-Cert-latest).

## Requirements

- iOS 16+
- Xcode 15+

## Installation

### Swift Package Manager

Add OpenACSwift to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/privacy-ethereum/openac-rsa-x509-swift", from: "1.0.0"),
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["OpenACSwift"]
    ),
]
```

Or in Xcode: **File → Add Package Dependencies**, enter the repository URL.

## Example App

A complete example app is available at [privacy-ethereum/openac-taiwan-citizen-digital-certificate-ios-example](https://github.com/privacy-ethereum/openac-taiwan-citizen-digital-certificate-ios-example).

## Usage

Import the library and call the functions in order: `setupKeys` (optional) → `prove*` → `verify*`.

```swift
import OpenACSwift
```

### 1. Setup Keys (Optional)

Generates proving and verifying keys for both circuits. **Skip this step if you already have the proving and verifying key files** — place them directly in `documentsPath/keys/` and proceed to `prove*`. Only run `setupKeys` if the key files are not yet present.

```swift
let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path

do {
    let message = try setupKeys(documentsPath: documentsPath)
    print("Setup complete:", message)
} catch let error as ZkProofError {
    print("Setup failed:", error)
}
```

Before calling `setupKeys`, download the required files and place them in `documentsPath`:

**R1CS files** (directly in `documentsPath/`):

| File                   | Download URL                                                                                                                        |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `certChainRS4096.r1cs` | [certChainRS4096.r1cs.gz](https://github.com/privacy-ethereum/zkID/releases/download/RSA-X.509-Cert-latest/certChainRS2048.r1cs.gz) |
| `userSigRS2048.r1cs`   | [userSigRS2048.r1cs.gz](https://github.com/privacy-ethereum/zkID/releases/download/RSA-X.509-Cert-latest/userSigRS2048.r1cs.gz)     |

**Key files** (in `documentsPath/keys/`):

| File                              | Download URL                                                                                                                                              |
| --------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `cert_chain_rs4096_proving.key`   | [cert_chain_rs4096_proving.key.gz](https://github.com/privacy-ethereum/zkID/releases/download/RSA-X.509-Cert-latest/cert_chain_rs4096_proving.key.gz)     |
| `cert_chain_rs4096_verifying.key` | [cert_chain_rs4096_verifying.key.gz](https://github.com/privacy-ethereum/zkID/releases/download/RSA-X.509-Cert-latest/cert_chain_rs4096_verifying.key.gz) |
| `user_sig_rs2048_proving.key`     | [user_sig_rs2048_proving.key.gz](https://github.com/privacy-ethereum/zkID/releases/download/RSA-X.509-Cert-latest/user_sig_rs2048_proving.key.gz)         |
| `user_sig_rs2048_verifying.key`   | [user_sig_rs2048_verifying.key.gz](https://github.com/privacy-ethereum/zkID/releases/download/RSA-X.509-Cert-latest/user_sig_rs2048_verifying.key.gz)     |

The `.gz` key files must be decompressed before use (e.g. `gunzip *.gz`). The `.r1cs` files are also gzip-compressed — decompress them too.

> **Note:** If you are using the example app, the download URLs for the proving keys and SMT snapshot are defined in `ProofViewModel.swift` and can be updated there.

**Parameters:**

- `documentsPath` — directory containing the `.r1cs` files and the `keys/` subdirectory

**Returns:** a status string confirming completion.

---

### 2. Prove

Generate a zero-knowledge proof for a specific circuit. Both functions return a `ProofResult`.

```swift
// Certificate chain circuit (RS4096)
let certResult: ProofResult = try proveCertChainRs4096(documentsPath: documentsPath)
print("Proved in \(certResult.proveMs) ms, size: \(certResult.proofSizeBytes) bytes")

// User signature circuit (RS2048)
let devResult: ProofResult = try proveUserSigRs2048(documentsPath: documentsPath)
print("Proved in \(devResult.proveMs) ms, size: \(devResult.proofSizeBytes) bytes")
```

**Returns:** `ProofResult` with:

- `proveMs: UInt64` — time taken to generate the proof in milliseconds
- `proofSizeBytes: UInt64` — size of the generated proof in bytes

---

### 3. Verify

Verify the proof produced by the corresponding prove function.

```swift
// Verify individually
let certValid = try verifyCertChainRs4096(documentsPath: documentsPath)
let devValid  = try verifyUserSigRs2048(documentsPath: documentsPath)

// Or verify both circuits together
let linked = try linkVerify(documentsPath: documentsPath)
```

**Returns:** `true` if the proof is valid, `false` otherwise.

---

### Generate Circuit Input

Use `generateCertChainRs4096Input` to produce JSON input files for both circuits from raw credential data.

> [!NOTE]
> `signedResponse` (and the accompanying `cert`) comes from the Taiwan FIDO service. Authenticate via [https://fido.moi.gov.tw/pt/](https://fido.moi.gov.tw/pt/) to obtain a response shaped like:
>
> ```json
> {
>     "error_code": "0",
>     "error_message": "SUCCESS",
>     "result": {
>         "hashed_id_num": "...",
>         "signed_response": "...",
>         "idp_checksum": "...",
>         "cert": "..."
>     }
> }
> ```
>
> Pass `result.signed_response` as `signedResponse` and `result.cert` (base64 DER) as `certb64`.

```swift
let outputPath = try generateCertChainRs4096Input(
    certb64: "<base64-encoded-cert>",
    signedResponse: "<signed-response-json>",
    tbs: "<tbs-data>",
    issuerCertPath: "/path/to/issuer.cer",
    smtSnapshotPath: "/path/to/g3-tree-snapshot.json.gz", // optional; pass nil to skip SMT revocation
    outputDir: documentsPath,
    challenge: "<challenge-string>"
)
print("Input written to:", outputPath)
```

This writes two files into `outputDir`:

- `cert_chain_rs4096_input.json`
- `user_sig_rs2048_input.json`

**Parameters:**

- `smtSnapshotPath` — reserved for future revocation support; pass `nil`
- `challenge` — challenge string included in the circuit input

---

### Benchmarking

Run the complete pipeline and get timing and size statistics for all stages:

```swift
let results: BenchmarkResults = try runCompleteBenchmark(documentsPath: documentsPath)
print("Setup: \(results.setupMs) ms")
print("Prove: \(results.proveMs) ms")
print("Verify: \(results.verifyMs) ms")
print("Proving key: \(results.provingKeyBytes) bytes")
print("Verifying key: \(results.verifyingKeyBytes) bytes")
print("Proof: \(results.proofBytes) bytes")
print("Witness: \(results.witnessBytes) bytes")
```

---

### Full Example

```swift
import OpenACSwift

func runZKProof() async {
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path

    do {
        // 1. Generate keys (run once; skip if keys already exist)
        let status = try setupKeys(documentsPath: documentsPath)
        print("Keys ready:", status)

        // 2. Generate circuit inputs (with optional SMT revocation)
        let snapshotPath = documentsPath + "/g3-tree-snapshot.json.gz"
        _ = try generateCertChainRs4096Input(
            certb64: "<base64-cert>",
            signedResponse: "<signed-response-json>",
            tbs: "<tbs>",
            issuerCertPath: documentsPath + "/MOICA-G3.cer",
            smtSnapshotPath: snapshotPath,
            outputDir: documentsPath,
            challenge: "<challenge-string>"
        )

        // 3. Generate proofs
        let certProof = try proveCertChainRs4096(documentsPath: documentsPath)
        print("cert_chain proved in \(certProof.proveMs) ms (\(certProof.proofSizeBytes) bytes)")

        let devProof = try proveUserSigRs2048(documentsPath: documentsPath)
        print("user_sig proved in \(devProof.proveMs) ms (\(devProof.proofSizeBytes) bytes)")

        // 4. Verify proofs
        let certValid = try verifyCertChainRs4096(documentsPath: documentsPath)
        let devValid  = try verifyUserSigRs2048(documentsPath: documentsPath)
        let linked    = try linkVerify(documentsPath: documentsPath)
        print("cert_chain valid:", certValid)
        print("user_sig valid:", devValid)
        print("link verify:", linked)
    } catch let error as ZkProofError {
        switch error {
        case .SetupRequired(let msg):         print("Run setupKeys first:", msg)
        case .FileNotFound(let msg):          print("Missing file:", msg)
        case .InvalidInput(let msg):          print("Bad input:", msg)
        case .ProofGenerationFailed(let msg): print("Prove error:", msg)
        case .VerificationFailed(let msg):    print("Verify error:", msg)
        case .IoError(let msg):               print("IO error:", msg)
        }
    } catch {
        print("Unexpected error:", error)
    }
}
```

## API Reference

| Function                                                                                                       | Returns            | Description                                       |
| -------------------------------------------------------------------------------------------------------------- | ------------------ | ------------------------------------------------- |
| `setupKeys(documentsPath:)`                                                                                    | `String`           | Generate keys for both circuits                   |
| `proveCertChainRs4096(documentsPath:)`                                                                         | `ProofResult`      | Prove cert chain (RS4096) circuit                 |
| `proveUserSigRs2048(documentsPath:)`                                                                           | `ProofResult`      | Prove user signature (RS2048) circuit             |
| `verifyCertChainRs4096(documentsPath:)`                                                                        | `Bool`             | Verify cert chain proof                           |
| `verifyUserSigRs2048(documentsPath:)`                                                                          | `Bool`             | Verify user signature proof                       |
| `linkVerify(documentsPath:)`                                                                                   | `Bool`             | Verify both proofs together                       |
| `generateCertChainRs4096Input(certb64:signedResponse:tbs:issuerCertPath:smtSnapshotPath:outputDir:challenge:)` | `String`           | Generate circuit input JSONs from credential data |
| `runCompleteBenchmark(documentsPath:)`                                                                         | `BenchmarkResults` | Run full pipeline and return timing/size stats    |

## Error Handling

All throwing functions throw `ZkProofError`:

| Case                    | Description                                            |
| ----------------------- | ------------------------------------------------------ |
| `SetupRequired`         | `prove*` or `verify*` called before `setupKeys`        |
| `FileNotFound`          | A required file is missing from `documentsPath`        |
| `InvalidInput`          | The input JSON is malformed or missing required fields |
| `ProofGenerationFailed` | An error occurred during proof generation              |
| `VerificationFailed`    | The proof failed verification                          |
| `IoError`               | A filesystem read/write error occurred                 |

## Development

The bindings are uploaded to the [zkID RSA-X.509-Cert latest release](https://github.com/privacy-ethereum/zkID/releases/tag/RSA-X.509-Cert-latest).

Download the bindings:

```sh
./Scripts/update-bindings.sh
```

Download the test vectors and run the tests:

```sh
./Scripts/download-test-vectors.sh
xcodebuild test \
    -scheme OpenACSwift \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest'
```
