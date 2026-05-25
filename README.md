# OpenACSwift

Swift bindings for the OpenAC zero-knowledge proof system, enabling cert_chain_rs4096 and user_sig_rs2048 circuit proof generation and verification on iOS.

The prebuilt binaries are distributed via the [zkID latest release](https://github.com/zkmopro/zkID/releases/tag/latest).

## Requirements

- iOS 16+
- Xcode 15+

## Installation

### Swift Package Manager

Add OpenACSwift to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/zkmopro/OpenACSwift", from: "1.0.0"),
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["OpenACSwift"]
    ),
]
```

Or in Xcode: **File → Add Package Dependencies**, enter the repository URL.

## Usage

Import the library and call the functions in order: `setupKeys` → `prove*` → `verify*`.

```swift
import OpenACSwift
```

### 1. Setup Keys

Generates proving and verifying keys for both circuits. Run once before any prove/verify calls.

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

| File | Download URL |
|------|-------------|
| `cert_chain_rs4096.r1cs` | [cert_chain_rs4096.r1cs.gz](https://github.com/zkmopro/zkID/releases/download/latest/cert_chain_rs4096.r1cs.gz) |
| `user_sig_rs2048.r1cs` | [user_sig_rs2048.r1cs.gz](https://github.com/zkmopro/zkID/releases/download/latest/user_sig_rs2048.r1cs.gz) |

**Key files** (in `documentsPath/keys/`):

| File | Download URL |
|------|-------------|
| `cert_chain_rs4096_proving.key` | [cert_chain_rs4096_proving.key.gz](https://github.com/zkmopro/zkID/releases/download/latest/cert_chain_rs4096_proving.key.gz) |
| `cert_chain_rs4096_verifying.key` | [cert_chain_rs4096_verifying.key.gz](https://github.com/zkmopro/zkID/releases/download/latest/cert_chain_rs4096_verifying.key.gz) |
| `user_sig_rs2048_proving.key` | [user_sig_rs2048_proving.key.gz](https://github.com/zkmopro/zkID/releases/download/latest/user_sig_rs2048_proving.key.gz) |
| `user_sig_rs2048_verifying.key` | [user_sig_rs2048_verifying.key.gz](https://github.com/zkmopro/zkID/releases/download/latest/user_sig_rs2048_verifying.key.gz) |

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
- `smtSnapshotPath` — path to the compressed SMT snapshot (`.json.gz`); pass `nil` to skip revocation checking
- `challenge` — challenge string included in the circuit input

The SMT snapshot can be downloaded from the [moica-revocation-smt snapshot release](https://github.com/moven0831/moica-revocation-smt/releases/tag/snapshot-latest) (`g3-tree-snapshot.json.gz`). Keep it compressed — the library reads it directly in gzip format.

---

### SMT Revocation

OpenACSwift includes offline SMT (Sparse Merkle Tree) revocation checking using a local snapshot, without requiring a network call to the revocation server.

#### Using the snapshot directly in `generateCertChainRs4096Input`

The simplest path is to pass `smtSnapshotPath` to `generateCertChainRs4096Input` (see above). The library handles loading and proof generation internally.

#### Manual SMT operations

For more control, use the lower-level SMT functions:

```swift
// Load the snapshot and generate a non-membership proof for a certificate serial number
let gzData = try Data(contentsOf: URL(fileURLWithPath: "/path/to/g3-tree-snapshot.json.gz"))
let smtProof: SmtProof = try createSmtProofFromGz(gzData: gzData, keyHex: "0x<serial-number-hex>")

// Verify the proof against the snapshot root
let root = buildSmtFromSnapshot(snapshotJson: decompressedJsonString)
let valid = verifySmtProof(proof: smtProof, expectedRoot: root)

// Convert to Circom circuit inputs (decimal strings, siblings padded to depth)
let circuitInputs: SmtCircuitInputs = try smtProofToCircuitInputs(proof: smtProof, depth: 160)
```

**`SmtProof`** fields:
- `root: String` — tree root at proof time (hex)
- `siblings: [String]` — sibling hashes from leaf level upward (hex)
- `entry: [String]` — `[key]` for non-membership; `[key, value, marker]` for membership
- `matchingEntry: [String]?` — present for non-membership proofs when a conflicting leaf exists
- `membership: Bool` — true if the key exists in the tree

**`SmtCircuitInputs`** fields (all decimal strings, for Circom):
- `smtRoot`, `serialNumber`, `smtSiblings`, `smtOldKey`, `smtOldValue`, `smtIsOld0`

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

| Function | Returns | Description |
|----------|---------|-------------|
| `setupKeys(documentsPath:)` | `String` | Generate keys for both circuits |
| `proveCertChainRs4096(documentsPath:)` | `ProofResult` | Prove cert chain (RS4096) circuit |
| `proveUserSigRs2048(documentsPath:)` | `ProofResult` | Prove user signature (RS2048) circuit |
| `verifyCertChainRs4096(documentsPath:)` | `Bool` | Verify cert chain proof |
| `verifyUserSigRs2048(documentsPath:)` | `Bool` | Verify user signature proof |
| `linkVerify(documentsPath:)` | `Bool` | Verify both proofs together |
| `generateCertChainRs4096Input(certb64:signedResponse:tbs:issuerCertPath:smtSnapshotPath:outputDir:challenge:)` | `String` | Generate circuit input JSONs from credential data |
| `runCompleteBenchmark(documentsPath:)` | `BenchmarkResults` | Run full pipeline and return timing/size stats |
| `buildSmtFromSnapshot(snapshotJson:)` | `String` | Parse snapshot JSON and return the SMT root |
| `createSmtProof(snapshotJson:keyHex:)` | `SmtProof` | Generate an SMT proof from a decompressed snapshot |
| `createSmtProofFromGz(gzData:keyHex:)` | `SmtProof` | Generate an SMT proof from a compressed `.json.gz` snapshot |
| `smtProofToCircuitInputs(proof:depth:)` | `SmtCircuitInputs` | Convert `SmtProof` to Circom-ready decimal inputs |
| `verifySmtProof(proof:expectedRoot:)` | `Bool` | Verify an SMT proof against a trusted root |

## Error Handling

All throwing functions throw `ZkProofError`:

| Case | Description |
|------|-------------|
| `SetupRequired` | `prove*` or `verify*` called before `setupKeys` |
| `FileNotFound` | A required file is missing from `documentsPath` |
| `InvalidInput` | The input JSON is malformed or missing required fields |
| `ProofGenerationFailed` | An error occurred during proof generation |
| `VerificationFailed` | The proof failed verification |
| `IoError` | A filesystem read/write error occurred |
