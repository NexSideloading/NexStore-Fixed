//
//  NexRevokeDNSService.swift
//  NexStore
//
//  Created by NovaDev404 on 26.10.2026.
//

import Foundation
import OSLog

class NexRevokeDNSService {
	static let shared = NexRevokeDNSService()
	private let logger = Logger(subsystem: "com.nexstore.feather", category: "NexRevokeDNS")

	private init() {}

	/// Enables PPQ for the given NexRevokeDNS Dynamic UID
	/// - Parameter uid: The NexRevokeDNS Dynamic UID
	/// - Returns: Boolean indicating success or failure
	func enablePPQ(uid: String) async throws -> Bool {
		guard !uid.isEmpty else {
			logger.error("NexRevokeDNS UID is empty")
			throw NexRevokeDNSError.emptyUID
		}

		let urlString = "https://dns.sideloading.net/dynamic/\(uid)/allowPPQ"
		guard let url = URL(string: urlString) else {
			logger.error("Invalid URL constructed from UID")
			throw NexRevokeDNSError.invalidURL
		}

		logger.info("Enabling PPQ for UID: \(uid)")

		var request = URLRequest(url: url)
		request.httpMethod = "GET"
		request.timeoutInterval = 30

		do {
			let (_, response) = try await URLSession.shared.data(for: request)

			guard let httpResponse = response as? HTTPURLResponse else {
				logger.error("Invalid response from NexRevokeDNS API")
				throw NexRevokeDNSError.invalidResponse
			}

			logger.info("NexRevokeDNS API returned status: \(httpResponse.statusCode)")

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

enum NexRevokeDNSError: Error, LocalizedError {
	case emptyUID
	case invalidURL
	case invalidResponse
	case networkError(Error)

	var errorDescription: String? {
		switch self {
		case .emptyUID:
			return "NexRevokeDNS UID cannot be empty"
		case .invalidURL:
			return "Invalid NexRevokeDNS URL"
		case .invalidResponse:
			return "Invalid response from NexRevokeDNS server"
		case .networkError(let error):
			return "Network error: \(error.localizedDescription)"
		}
	}
}
