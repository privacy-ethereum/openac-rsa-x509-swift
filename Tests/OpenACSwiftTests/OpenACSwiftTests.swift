import Foundation
import Testing

@testable import OpenACSwift

private enum TestSupport {
  static var testBundle: Bundle { Bundle.module }

  /// Matches app-style usage: keys and artifacts use the TestVectors directory as the documents root.
  static var documentsPath: String {
    (testBundle.bundlePath as NSString).appendingPathComponent("TestVectors")
  }

  static var bundledCertChainRs4096R1CSPath: String? {
    testBundle.path(forResource: "cert_chain_rs4096", ofType: "r1cs", inDirectory: "TestVectors")
  }

  static var bundledDeviceSigRs2048R1CSPath: String? {
    testBundle.path(forResource: "device_sig_rs2048", ofType: "r1cs", inDirectory: "TestVectors")
  }

  static var bundledCertChainRs4096InputJSONPath: String? {
    testBundle.path(
      forResource: "cert_chain_rs4096_input", ofType: "json", inDirectory: "TestVectors")
  }

  static var bundledDeviceSigRs2048InputJSONPath: String? {
    testBundle.path(
      forResource: "device_sig_rs2048_input", ofType: "json", inDirectory: "TestVectors")
  }

  static var bundledCertChainRs4096ProvingKeyPath: String? {
    testBundle.path(
      forResource: "cert_chain_rs4096_proving", ofType: "key", inDirectory: "TestVectors/keys")
  }

  static var bundledDeviceSigRs2048ProvingKeyPath: String? {
    testBundle.path(
      forResource: "device_sig_rs2048_proving", ofType: "key", inDirectory: "TestVectors/keys")
  }

  static var bundledCertChainRs4096VerifyingKeyPath: String? {
    testBundle.path(
      forResource: "cert_chain_rs4096_verifying", ofType: "key", inDirectory: "TestVectors/keys")
  }

  static var bundledDeviceSigRs2048VerifyingKeyPath: String? {
    testBundle.path(
      forResource: "device_sig_rs2048_verifying", ofType: "key", inDirectory: "TestVectors/keys")
  }

  static var bundledMOICA_G3CertPath: String? {
    testBundle.path(forResource: "MOICA-G3", ofType: "cer", inDirectory: "TestVectors")
  }

  // static var bundledFidoResponseJSONPath: String? {
  //   testBundle.path(forResource: "fido_response_sign", ofType: "json", inDirectory: "TestVectors")
  // }

  // static var bundledSMTSnapshotJSONPath: String? {
  //   testBundle.path(forResource: "g3-tree-snapshot.json", ofType: "gz", inDirectory: "TestVectors")
  // }
}

// Serialized so tests don't race on the shared documentsPath (keys, proof files written there).
@Suite(.serialized)
struct OpenACSwiftTests {

  @Test func setupKeysSucceedsWithBundleDocumentsPathAndBundledInput() async throws {

    _ = try #require(
      TestSupport.bundledCertChainRs4096R1CSPath,
      "TestVectors/cert_chain_rs4096.r1cs must be copied into the test bundle (see Package.swift resources)."
    )

    _ = try #require(
      TestSupport.bundledDeviceSigRs2048R1CSPath,
      "TestVectors/device_sig_rs2048.r1cs must be copied into the test bundle (see Package.swift resources)."
    )

    let message = try setupKeys(
      documentsPath: TestSupport.documentsPath,
    )

    #expect(!message.isEmpty, "setupKeys should return a non-empty status string.")
  }

  @Test func proveCertChainRs4096ReturnsValidResultWithBundledInput() async throws {
    _ = try #require(
      TestSupport.bundledCertChainRs4096InputJSONPath,
      "TestVectors/cert_chain_rs4096_input.json must be copied into the test bundle (see Package.swift resources)."
    )

    _ = try #require(
      TestSupport.bundledCertChainRs4096ProvingKeyPath,
      "TestVectors/cert_chain_rs4096_proving.key must be copied into the test bundle (see Package.swift resources)."
    )

    let result = try proveCertChainRs4096(documentsPath: TestSupport.documentsPath)

    #expect(result.proveMs > 0, "Proof generation should take measurable time.")
    #expect(result.proofSizeBytes > 0, "Proof should have a non-zero size.")
  }

  @Test func proveUserSigRs2048ReturnsValidResultWithBundledInput() async throws {
    _ = try #require(
      TestSupport.bundledDeviceSigRs2048InputJSONPath,
      "TestVectors/device_sig_rs2048_input.json must be copied into the test bundle (see Package.swift resources)."
    )

    _ = try #require(
      TestSupport.bundledDeviceSigRs2048ProvingKeyPath,
      "TestVectors/device_sig_rs2048_proving.key must be copied into the test bundle (see Package.swift resources)."
    )

    _ = try #require(
      TestSupport.bundledDeviceSigRs2048VerifyingKeyPath,
      "TestVectors/device_sig_rs2048_verifying.key must be copied into the test bundle (see Package.swift resources)."
    )

    let result = try proveUserSigRs2048(documentsPath: TestSupport.documentsPath)

    #expect(result.proveMs > 0, "Proof generation should take measurable time.")
    #expect(result.proofSizeBytes > 0, "Proof should have a non-zero size.")
  }

  @Test func proveAndVerifyCertChainRs4096Succeeds() async throws {
    _ = try #require(
      TestSupport.bundledCertChainRs4096VerifyingKeyPath,
      "TestVectors/cert_chain_rs4096_verifying.key must be copied into the test bundle (see Package.swift resources)."
    )

    _ = try proveCertChainRs4096(documentsPath: TestSupport.documentsPath)

    let valid = try verifyCertChainRs4096(documentsPath: TestSupport.documentsPath)

    #expect(valid, "Verification should succeed after a valid proveCertChainRs4096 call.")
  }


  @Test func proveAndVerifyDeviceSigRs2048Succeeds() async throws {
    _ = try #require(
      TestSupport.bundledDeviceSigRs2048VerifyingKeyPath,
      "TestVectors/device_sig_rs2048_verifying.key must be copied into the test bundle (see Package.swift resources)."
    )

    _ = try proveUserSigRs2048(documentsPath: TestSupport.documentsPath)

    let valid = try verifyDeviceSigRs2048(documentsPath: TestSupport.documentsPath)

    #expect(valid, "Verification should succeed after a valid proveUserSigRs2048 call.")
  }

  // @Test func generateInputSucceeds() async throws {
  //   let responsePath = try #require(
  //     TestSupport.bundledFidoResponseJSONPath,
  //     "TestVectors/fido_response_sign.json must be copied into the test bundle (see Package.swift resources)."
  //   )

  //   // Parse fido_response_sign.json to extract cert and signed_response.
  //   let responseData = try Data(contentsOf: URL(fileURLWithPath: responsePath))
  //   let responseJSON = try #require(
  //     try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
  //     "fido_response_sign.json must be a JSON object."
  //   )
  //   let result = try #require(
  //     responseJSON["result"] as? [String: Any],
  //     "fido_response_sign.json must contain a 'result' object."
  //   )
  //   let certb64 = try #require(
  //     result["cert"] as? String,
  //     "fido_response_sign.json result must contain a 'cert' string."
  //   )
  //   let signedResponse = try #require(
  //     result["signed_response"] as? String,
  //     "fido_response_sign.json result must contain a 'signed_response' string."
  //   )

  //   let tbs = "e775f2805fb993e05a208dbff15d1c1"

  //   let issuerCertPath = try #require(
  //     TestSupport.bundledMOICA_G3CertPath,
  //     "TestVectors/pkcs11info_withcert.json must be copied into the test bundle (see Package.swift resources)."
  //   )

  //   let smtSnapshotPath = try #require(
  //     TestSupport.bundledSMTSnapshotJSONPath,
  //     "TestVectors/g3-tree-snapshot.json must be copied into the test bundle (see Package.swift resources)."
  //   )

  //   let challenge = "1339673755198158349044581307228491536"
  //   let _ = try generateCertChainRs4096Input(
  //     certb64: certb64,
  //     signedResponse: signedResponse,
  //     tbs: tbs,
  //     issuerCertPath: issuerCertPath,
  //     smtSnapshotPath: smtSnapshotPath,
  //     outputDir: TestSupport.documentsPath,
  //     challenge: challenge,
  //   )

  //   #expect(
  //     FileManager.default.fileExists(
  //       atPath: TestSupport.documentsPath + "/cert_chain_rs4096_input.json"),
  //     "generateCertChainRs4096Input should write a circuit input JSON to TestSupport.documentsPath/cert_chain_rs4096_input.json."
  //   )

  //   _ = try proveCertChainRs4096(documentsPath: TestSupport.documentsPath)

  //   let validCert = try verifyCertChainRs4096(documentsPath: TestSupport.documentsPath)

  //   #expect(validCert, "Verification should succeed after a valid proveCertChainRs4096 call.")
  //   _ = try proveUserSigRs2048(documentsPath: TestSupport.documentsPath)

  //   let validDev = try verifyDeviceSigRs2048(documentsPath: TestSupport.documentsPath)

  //   #expect(validDev, "Verification should succeed after a valid proveUserSigRs2048 call.")

  //   let validLink = try linkVerify(documentsPath: TestSupport.documentsPath)

  //   #expect(validLink, "Verification should succeed after a valid linkVerify call.")
  // }
}
