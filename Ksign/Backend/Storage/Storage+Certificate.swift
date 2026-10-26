//
//  Storage+Certificate.swift
//  Feather
//
//  Created by samara on 16.04.2025.
//

import CoreData
import UIKit.UIImpactFeedbackGenerator

// MARK: - Class extension: certificate
extension Storage {
	func addCertificate(
		uuid: String,
		password: String? = nil,
		nickname: String? = nil,
		ppq: Bool = false,
		expiration: Date,
		completion: @escaping (Error?) -> Void
	) {
		let generator = UIImpactFeedbackGenerator(style: .light)
		
		let new = CertificatePair(context: context)
		new.uuid = uuid
		new.date = Date()
		new.password = password
		new.ppQCheck = ppq
		new.expiration = expiration
		new.nickname = nickname
		
        saveContext()
        generator.impactOccurred()
        completion(nil)
	}
    
    func revokagedCertificate(for cert: CertificatePair) {
        guard !cert.revoked else { return }
        print("Checking revokage for \(cert.nickname ?? "Unknown")")

        guard let p12URL = getFile(.certificate, from: cert),
              let password = cert.password else {
            print("Cannot check revokage: missing p12 file or password")
            return
        }

        let mobileprovisionURL = getFile(.provision, from: cert)

        CertificateCheckerService.shared.checkCertificate(
            p12URL: p12URL,
            password: password,
            mobileprovisionURL: mobileprovisionURL
        ) { result in
            switch result {
            case .success(let response):
                if let p12Info = response.p12, let status = p12Info.Status {
                    DispatchQueue.main.async {
                        // Map API status to revoked boolean
                        // API returns: "Signed" -> Valid (revoked = false)
                        //              "Revoked" -> Revoked (revoked = true)
                        //              Other -> Unknown (revoked = false, but could add unknown status field)
                        switch status.lowercased() {
                        case "signed":
                            cert.revoked = false
                        case "revoked":
                            cert.revoked = true
                        default:
                            // Unknown status - treat as valid for now
                            cert.revoked = false
                        }
                        Storage.shared.saveContext()
                    }
                }
            case .failure(let error):
                print("Failed to check certificate status: \(error.localizedDescription)")
            }
        }
    }
    
    func getProvisionFileDecoded(for cert: CertificatePair) -> Certificate? {
        guard let url = getFile(.provision, from: cert) else {
            return nil
        }
        
        let read = CertificateReader(url)
        return read.decoded
    }
    
	func deleteCertificate(for cert: CertificatePair) {
		do {
			if cert.p12Data == nil && cert.provisionData == nil {
				if let url = getUuidDirectory(for: cert) {
					try FileManager.default.removeItem(at: url)
				}
			}
			context.delete(cert)
			saveContext()
		} catch {
			print(error)
		}
	}
		
	enum FileRequest: String {
		case certificate = "p12"
		case provision = "mobileprovision"
	}
	
	func getFile(_ type: FileRequest, from cert: CertificatePair) -> URL? {
		guard let url = getUuidDirectory(for: cert) else {
			return nil
		}
		
		return FileManager.default.getPath(in: url, for: type.rawValue)
	}
	
	func getUuidDirectory(for cert: CertificatePair) -> URL? {
		guard let uuid = cert.uuid else {
			return nil
		}
		
		return FileManager.default.certificates(uuid)
	}
}
