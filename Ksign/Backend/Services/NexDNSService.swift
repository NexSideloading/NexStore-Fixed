//
//  NexDNSService.swift
//  NexStore
//
//  Created by NovaDev404 on 26.10.2026.
//

import Foundation
import OSLog

class NexDNSService {
	static let shared = NexDNSService()
	private let logger = Logger(subsystem: "com.nexstore.feather", category: "NexDNS")

	private init() {}

	/// Enables PPQ for the given NexDNS Dynamic UID
	/// - Parameter uid: The NexDNS Dynamic UID
	/// - Returns: Boolean indicating success or failure
	func enablePPQ(uid: String) async throws -> Bool {
		guard !uid.isEmpty else {
			logger.error("NexDNS UID is empty")
			throw NexDNSError.emptyUID
		}

		let urlString = "https://dns.sideloading.net/dynamic/\(uid)/allowPPQ"
		guard let url = URL(string: urlString) else {
			logger.error("Invalid URL constructed from UID")
			throw NexDNSError.invalidURL
		}

		logger.info("Enabling PPQ for UID: \(uid)")

		var request = URLRequest(url: url)
		request.httpMethod = "GET"
		request.timeoutInterval = 30

		do {
			let (_, response) = try await URLSession.shared.data(for: request)

			guard let httpResponse = response as? HTTPURLResponse else {
				logger.error("Invalid response from NexDNS API")
				throw NexDNSError.invalidResponse
			}

			logger.info("NexDNS API returned status: \(httpResponse.statusCode)")

			// Wait 10 seconds as required
			logger.info("Waiting 10 seconds before continuing...")
			try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds

			return true
		} catch {
			logger.error("Failed to enable PPQ: \(error.localizedDescription)")
			throw error
		}
	}
}

enum NexDNSError: Error, LocalizedError {
	case emptyUID
	case invalidURL
	case invalidResponse
	case networkError(Error)

	var errorDescription: String? {
		switch self {
		case .emptyUID:
			return "NexDNS UID cannot be empty"
		case .invalidURL:
			return "Invalid NexDNS URL"
		case .invalidResponse:
			return "Invalid response from NexDNS server"
		case .networkError(let error):
			return "Network error: \(error.localizedDescription)"
		}
	}
}
