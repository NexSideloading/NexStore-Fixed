//
//  NexCertsService.swift
//  NexStore
//
//  Created by NovaDev404 on 26.10.2026.
//

import Foundation
import OSLog
import ZIPFoundation

// MARK: - Models
struct NexCertsCertificate: Codable {
    let id: Int
    let name: String
    let status: String
    let valid_from: String
    let valid_to: String
    let folder_name: String
    let nickname: String?
}

// MARK: - Service
class NexCertsService {
    static let shared = NexCertsService()
    private let baseURL = "https://sideloading.net/api/certificates"
    private let logger = Logger(subsystem: "com.nexstore", category: "NexCerts")

    private init() {}

    // MARK: - Public Methods

    /// Syncs all certificates from NexCerts API
    func syncAllCertificates(completion: @escaping (Result<Int, Error>) -> Void) {
        let listURL = URL(string: "\(baseURL)/list/all")!

        URLSession.shared.dataTask(with: listURL) { [weak self] data, _, error in
            guard let self = self else { return }

            if error != nil {
                self.logger.error("Network error: \(error!.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error!))
                }
                return
            }

            guard let data = data else {
                self.logger.error("No data received")
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "NexCerts", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                }
                return
            }

            do {
                let decoder = JSONDecoder()
                let certificates = try decoder.decode([NexCertsCertificate].self, from: data)

                self.importCertificates(certificates: certificates) { result in
                    completion(result)
                }
            } catch {
                self.logger.error("Failed to decode NexCerts response: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    // MARK: - Private Methods

    private func importCertificates(certificates: [NexCertsCertificate], completion: @escaping (Result<Int, Error>) -> Void) {
        let group = DispatchGroup()
        var importedCount = 0
        var lastError: Error?

        for cert in certificates {
            // Check if certificate already exists by checking if a certificate with the same folder name exists
            if Storage.shared.certificateExists(for: cert.folder_name) {
                logger.info("Certificate \(cert.folder_name) already exists, skipping")
                continue
            }

            // Determine if certificate is revoked based on status
            let isRevoked = cert.status.contains("Revoked") || cert.status.contains("❌")

            group.enter()
            downloadAndImportCertificate(cert: cert, isRevoked: isRevoked) { result in
                switch result {
                case .success:
                    importedCount += 1
                    self.logger.info("Successfully imported certificate: \(cert.folder_name)")
                case .failure(let error):
                    self.logger.error("Failed to import certificate \(cert.folder_name): \(error.localizedDescription)")
                    lastError = error
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if let error = lastError {
                completion(.failure(error))
            } else {
                completion(.success(importedCount))
            }
        }
    }

    private func downloadAndImportCertificate(cert: NexCertsCertificate, isRevoked: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        let downloadURL = URL(string: "\(baseURL)/download/\(cert.id)/cert.zip")!

        URLSession.shared.downloadTask(with: downloadURL) { tempURL, response, error in
            if error != nil {
                DispatchQueue.main.async {
                    completion(.failure(error!))
                }
                return
            }

            guard let tempURL = tempURL else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "NexCerts", code: -1, userInfo: [NSLocalizedDescriptionKey: "No temporary file URL"])))
                }
                return
            }

            // Process the downloaded zip file
            self.processCertificateZip(
                cert: cert,
                zipURL: tempURL,
                isRevoked: isRevoked,
                completion: completion
            )
        }.resume()
    }

    private func processCertificateZip(cert: NexCertsCertificate, zipURL: URL, isRevoked: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        let tempDir = FileManager.default.temporaryDirectory
        let extractDir = tempDir.appendingPathComponent("nexcerts_\(cert.id)")

        // Create extraction directory
        do {
            try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        } catch {
            DispatchQueue.main.async {
                completion(.failure(error))
            }
            return
        }

        // Extract zip
        do {
            try FileManager.default.unzipItem(at: zipURL, to: extractDir)
        } catch {
            DispatchQueue.main.async {
                completion(.failure(NSError(domain: "NexCerts", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to extract zip file"])))
            }
            return
        }

        // Find required files
        let p12URL = extractDir.appendingPathComponent("cert.p12")
        let provisionURL = extractDir.appendingPathComponent("cert.mobileprovision")
        let passwordURL = extractDir.appendingPathComponent("cert.txt")

        guard FileManager.default.fileExists(atPath: p12URL.path),
              FileManager.default.fileExists(atPath: provisionURL.path),
              FileManager.default.fileExists(atPath: passwordURL.path) else {
            DispatchQueue.main.async {
                completion(.failure(NSError(domain: "NexCerts", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing required files in zip"])))
            }
            return
        }

        // Read password
        do {
            let password = try String(contentsOf: passwordURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)

            // Use nickname if available, otherwise use folder_name
            let certificateName = cert.nickname ?? cert.folder_name

            // Import using existing FR method
            FR.handleCertificateFiles(
                p12URL: p12URL,
                provisionURL: provisionURL,
                p12Password: password,
                certificateName: certificateName
            ) { error in
                // Cleanup
                try? FileManager.default.removeItem(at: extractDir)
                try? FileManager.default.removeItem(at: zipURL)

                // Set revoked status after successful import
                if error == nil && isRevoked {
                    DispatchQueue.main.async {
                        if let cert = Storage.shared.getCertificate(byNickname: certificateName) {
                            cert.revoked = true
                            Storage.shared.saveContext()
                        }
                        completion(.success(()))
                    }
                } else {
                    DispatchQueue.main.async {
                        if let error = error {
                            completion(.failure(error))
                        } else {
                            completion(.success(()))
                        }
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        }
    }
}
