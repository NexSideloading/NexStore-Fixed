//
//  SourcesViewModel.swift
//  Feather
//
//  Created by samara on 30.04.2025.
//

import Foundation
import CoreData
import AltSourceKit
import SwiftUI
import NimbleJSON

// MARK: - Class
final class SourcesViewModel: ObservableObject {
	static let shared = SourcesViewModel()
	
	typealias RepositoryDataHandler = Result<ASRepository, Error>
	
	private let _dataService = NBFetchService()
	
	var isFinished = true
	@Published var sources: [AltSource: ASRepository] = [:]
	
	func fetchSources(_ sources: FetchedResults<AltSource>, refresh: Bool = false, batchSize: Int = 4) async {
		guard isFinished else { return }
		
		// check if sources to be fetched are the same as before, if yes, return
		// also skip check if refresh is true
		if !refresh, sources.allSatisfy({ self.sources[$0] != nil }) { return }
		
		// isfinished is used to prevent multiple fetches at the same time
		isFinished = false
		defer { isFinished = true }
		
		await MainActor.run {
			self.sources = [:]
		}
		
		let sourcesArray = Array(sources)
		
		for startIndex in stride(from: 0, to: sourcesArray.count, by: batchSize) {
			let endIndex = min(startIndex + batchSize, sourcesArray.count)
			let batch = sourcesArray[startIndex..<endIndex]

			let batchResults = await withTaskGroup(of: (String, ASRepository?).self, returning: [String: ASRepository].self) { group in
				for source in batch {
					let sourceID = source.identifier ?? ""
					let sourceURL = source.sourceURL

					group.addTask {
						guard let url = sourceURL else {
							return (sourceID, nil)
						}

						return await withCheckedContinuation { continuation in
							self._dataService.fetch(from: url) { (result: RepositoryDataHandler) in
								switch result {
								case .success(let repo):
									continuation.resume(returning: (sourceID, repo))
								case .failure(_):
									continuation.resume(returning: (sourceID, nil))
								}
							}
						}
					}
				}

				var results = [String: ASRepository]()
				for await (sourceID, repo) in group {
					if let repo {
						results[sourceID] = repo
					}
				}
				return results
			}

			let batchSources = batch.map { ($0.objectID.uriRepresentation().absoluteString, $0.identifier ?? "") }
			await MainActor.run {
				for (objectURI, sourceID) in batchSources {
					guard
						let uri = URL(string: objectURI),
						let objectID = Storage.shared.context.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: uri),
						let existing = try? Storage.shared.context.existingObject(with: objectID),
						let source = existing as? AltSource
					else { continue }
					if let repo = batchResults[sourceID] {
						self.sources[source] = repo
					}
				}
			}
		}
	}
}
