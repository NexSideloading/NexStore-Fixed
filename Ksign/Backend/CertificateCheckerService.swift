//
//  CertificateCheckerService.swift
//  NexStore
//
//  Created by NovaDev404 on 10/26/2026.
//

import Foundation

// MARK: - Models
struct CertificateCheckerResponse: Codable {
    let p12: P12Info?
    let mobileprovision: MobileProvisionInfo?
}

struct P12Info: Codable {
    let CertificateType: String?
    let CommonName: String?
    let Organization: String?
    let SerialNumber: String?
    let TeamID: String?
    let Status: String?
    let ValidFrom: String?
    let ValidTo: String?
    let MD5: String?
    let SHA1: String?
    let SHA256: String?
    let ocsp_url: String?
}

struct MobileProvisionInfo: Codable {
    let TeamName: String?
    let Name: String?
    let AppIDName: String?
    let UUID: String?
    let TimeToLive: Int?
    let ValidFrom: String?
    let ValidTo: String?
    let Platforms: [String]?
    let Entitlements: [String: AnyCodable]?
    let ProvisionsAllDevices: Bool?
}

// MARK: - Service
class CertificateCheckerService {
    static let shared = CertificateCheckerService()
    private static let baseURL = "https://sideloading.net/api/certchecker/checkCert"
    private let checkQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.nexstore.certificate-checks"
        queue.qualityOfService = .utility
        queue.maxConcurrentOperationCount = 2
        return queue
    }()

    private init() {}

    func checkCertificate(
        p12URL: URL,
        password: String,
        mobileprovisionURL: URL? = nil,
        completion: @escaping (Result<CertificateCheckerResponse, Error>) -> Void
    ) {
        checkQueue.addOperation {
            guard let p12Data = try? Data(contentsOf: p12URL) else {
                let error = NSError(domain: "CertificateChecker", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to read the certificate file"])
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            let boundary = UUID().uuidString
            var request = URLRequest(url: URL(string: Self.baseURL)!)
            request.httpMethod = "POST"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            var body = Data()
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"p12\"; filename=\"certificate.p12\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: application/x-pkcs12\r\n\r\n".data(using: .utf8)!)
            body.append(p12Data)
            body.append("\r\n".data(using: .utf8)!)

            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"password\"\r\n\r\n".data(using: .utf8)!)
            body.append(password.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)

            if let mobileURL = mobileprovisionURL, let mobileData = try? Data(contentsOf: mobileURL) {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"mobileprovision\"; filename=\"profile.mobileprovision\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: application/x-apple-aspen-mobileprovision\r\n\r\n".data(using: .utf8)!)
                body.append(mobileData)
                body.append("\r\n".data(using: .utf8)!)
            }

            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            request.httpBody = body

            // Keep the operation slot until the request completes, limiting the number of
            // certificates being read, buffered, and uploaded at the same time.
            let requestFinished = DispatchSemaphore(value: 0)
            URLSession.shared.dataTask(with: request) { data, _, error in
                defer { requestFinished.signal() }

                let result: Result<CertificateCheckerResponse, Error>
                if let error {
                    result = .failure(error)
                } else if let data {
                    result = Result { try JSONDecoder().decode(CertificateCheckerResponse.self, from: data) }
                } else {
                    result = .failure(NSError(domain: "CertificateChecker", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                }
                DispatchQueue.main.async { completion(result) }
            }.resume()
            requestFinished.wait()
        }
    }

    func checkMobileProvisionOnly(
        mobileprovisionURL: URL,
        completion: @escaping (Result<CertificateCheckerResponse, Error>) -> Void
    ) {
        var request = URLRequest(url: URL(string: Self.baseURL)!)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add mobileprovision file
        if let mobileData = try? Data(contentsOf: mobileprovisionURL) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"mobileprovision\"; filename=\"profile.mobileprovision\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: application/x-apple-aspen-mobileprovision\r\n\r\n".data(using: .utf8)!)
            body.append(mobileData)
            body.append("\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                DispatchQueue.main.async {
                    completion(.failure(error!))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "CertificateChecker", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                }
                return
            }

            do {
                let decoder = JSONDecoder()
                let result = try decoder.decode(CertificateCheckerResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
}
