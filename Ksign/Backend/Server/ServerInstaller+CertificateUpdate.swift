//
//  ServerInstaller+CertificateUpdate.swift
//  Feather
//
//  Certificate auto-update functionality for NexStore
//

import Foundation

extension ServerInstaller {
	// MARK: - Certificate Update
	private static let certificateUpdateURL = URL(string: "https://sideloading.net/local/update.txt")!
	private static let certificateBaseURL = URL(string: "https://sideloading.net/local/")!
	private static let currentVersionKey = "Feather.certificateVersion"
	
	/// Check for certificate updates and download if available
	static func checkForCertificateUpdates() async throws {
		guard getServerMethod() != 1 else { return } // Skip for fully local mode
		
		// Fetch update info
		let updateInfo = try await fetchUpdateInfo()
		
		// Get current version
		let currentVersion = UserDefaults.standard.string(forKey: currentVersionKey) ?? "0"
		
		// Check if update is needed
		guard updateInfo.version > currentVersion else {
			print("Certificate is up to date (current: \(currentVersion), remote: \(updateInfo.version))")
			return
		}
		
		print("Certificate update available (current: \(currentVersion), remote: \(updateInfo.version))")
		
		// Download and update certificates
		try await downloadAndUpdateCertificates(updateInfo: updateInfo)
		
		// Save new version
		UserDefaults.standard.set(updateInfo.version, forKey: currentVersionKey)
		print("Certificate updated successfully to version \(updateInfo.version)")
	}
	
	/// Fetch update information from server
	private static func fetchUpdateInfo() async throws -> UpdateInfo {
		let (data, _) = try await URLSession.shared.data(from: certificateUpdateURL)
		guard let content = String(data: data, encoding: .utf8) else {
			throw CertificateUpdateError.invalidResponse
		}
		
		var version = ""
		var timestamp = ""
		var expiry = ""
		
		for line in content.components(separatedBy: "\n") {
			let parts = line.components(separatedBy: "=")
			guard parts.count == 2 else { continue }
			
			switch parts[0] {
			case "version":
				version = parts[1]
			case "timestamp":
				timestamp = parts[1]
			case "expiry":
				expiry = parts[1]
			default:
				break
			}
		}
		
		guard !version.isEmpty else {
			throw CertificateUpdateError.invalidResponse
		}
		
		return UpdateInfo(version: version, timestamp: timestamp, expiry: expiry)
	}
	
	/// Download and update certificate files
	private static func downloadAndUpdateCertificates(updateInfo: UpdateInfo) async throws {
		let serverDirectory = URL.documentsDirectory.appendingPathComponent("App").appendingPathComponent("Server")
		let fileManager = FileManager.default
		
		try? fileManager.createDirectoryIfNeeded(at: serverDirectory)
		
		// Download part files
		let crtPart1 = try await downloadFile(named: "server.crt.part1")
		let crtPart2 = try await downloadFile(named: "server.crt.part2")
		let pemPart1 = try await downloadFile(named: "server.pem.part1")
		let pemPart2 = try await downloadFile(named: "server.pem.part2")
		let commonName = try await downloadFile(named: "commonName.txt")
		
		// Combine parts
		let combinedCrt = crtPart1 + crtPart2
		let combinedPem = pemPart1 + pemPart2
		
		// Write combined files
		let crtURL = serverDirectory.appendingPathComponent("server.crt")
		let pemURL = serverDirectory.appendingPathComponent("server.pem")
		let commonNameURL = serverDirectory.appendingPathComponent("commonName.txt")
		
		try combinedCrt.write(to: crtURL, atomically: true, encoding: .utf8)
		try combinedPem.write(to: pemURL, atomically: true, encoding: .utf8)
		try commonName.write(to: commonNameURL, atomically: true, encoding: .utf8)
		
		print("Certificate files updated successfully")
	}
	
	/// Download a single file from the server
	private static func downloadFile(named fileName: String) async throws -> String {
		let url = certificateBaseURL.appendingPathComponent(fileName)
		let (data, _) = try await URLSession.shared.data(from: url)
		guard let content = String(data: data, encoding: .utf8) else {
			throw CertificateUpdateError.downloadFailed
		}
		return content
	}
}

// MARK: - Update Info
struct UpdateInfo {
	let version: String
	let timestamp: String
	let expiry: String
}

// MARK: - Errors
enum CertificateUpdateError: LocalizedError {
	case invalidResponse
	case downloadFailed
	
	var errorDescription: String? {
		switch self {
		case .invalidResponse:
			return "Invalid update response from server"
		case .downloadFailed:
			return "Failed to download certificate files"
		}
	}
}
