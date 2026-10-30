import Foundation
import ZIPFoundation

struct NexCertsCertificate: Decodable, Identifiable {
	let id: Int
	let name: String
	let status: String
	let valid_to: String
	let folder_name: String
	let nickname: String?
}

final class NexCertsService {
	static let shared = NexCertsService()
	private let baseURL = URL(string: "https://sideloading.net/api/certificates")!
	private let session = URLSession.shared

	private init() {}

	func fetchCertificates(completion: @escaping (Result<[NexCertsCertificate], Error>) -> Void) {
		request(baseURL.appendingPathComponent("list/all")) { result in
			DispatchQueue.main.async {
				completion(result.flatMap { data in Result { try JSONDecoder().decode([NexCertsCertificate].self, from: data) } })
			}
		}
	}

	func importCertificate(_ certificate: NexCertsCertificate, completion: @escaping (Result<Void, Error>) -> Void) {
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent("nexcerts-\(UUID().uuidString)", isDirectory: true)
		do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
		catch { completion(.failure(error)); return }

		let group = DispatchGroup()
		let lock = NSLock()
		var files: [String: URL] = [:]
		var firstError: Error?
		for name in ["cert.p12", "cert.mobileprovision", "password.txt"] {
			group.enter()
			let url = baseURL.appendingPathComponent("download").appendingPathComponent(String(certificate.id)).appendingPathComponent(name)
			request(url) { result in
				lock.lock()
				switch result {
				case .success(let data):
					let target = directory.appendingPathComponent(name)
					do { try data.write(to: target, options: .atomic); files[name] = target }
					catch { if firstError == nil { firstError = error } }
				case .failure(let error): if firstError == nil { firstError = error }
				}
				lock.unlock()
				group.leave()
			}
		}
		group.notify(queue: .global()) {
			if let error = firstError {
				try? FileManager.default.removeItem(at: directory)
				DispatchQueue.main.async { completion(.failure(error)) }
				return
			}
			guard let p12 = files["cert.p12"], let provision = files["cert.mobileprovision"], let passwordFile = files["password.txt"],
				let password = try? String(contentsOf: passwordFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) else {
				try? FileManager.default.removeItem(at: directory)
				DispatchQueue.main.async { completion(.failure(Self.error("The certificate download is missing a required file."))) }
				return
			}
			self.finishImport(p12: p12, provision: provision, password: password, name: certificate.nickname ?? certificate.folder_name, revoked: certificate.status.localizedCaseInsensitiveContains("revoked")) { result in
				try? FileManager.default.removeItem(at: directory)
				completion(result)
			}
		}
	}

	func importAll(completion: @escaping (Result<Int, Error>) -> Void) {
		request(baseURL.appendingPathComponent("download").appendingPathComponent("all.zip")) { [weak self] result in
			guard let self else { return }
			DispatchQueue.global().async {
				switch result {
				case .failure(let error): DispatchQueue.main.async { completion(.failure(error)) }
				case .success(let data):
					let root = FileManager.default.temporaryDirectory.appendingPathComponent("nexcerts-all-\(UUID().uuidString)", isDirectory: true)
					do {
						try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
						let archive = root.appendingPathComponent("all.zip")
						try data.write(to: archive)
						let extracted = root.appendingPathComponent("extracted", isDirectory: true)
						try FileManager.default.createDirectory(at: extracted, withIntermediateDirectories: true)
						try FileManager.default.unzipItem(at: archive, to: extracted)
						let folders = try FileManager.default.contentsOfDirectory(at: extracted, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]).filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
						guard !folders.isEmpty else { throw Self.error("The archive contains no certificate folders.") }
						let group = DispatchGroup()
						let lock = NSLock()
						var count = 0
						var firstError: Error?
						for folder in folders {
							guard let p12 = Self.findFile(named: ".p12", in: folder), let provision = Self.findFile(named: ".mobileprovision", in: folder), let passwordFile = Self.findFile(named: "password.txt", in: folder),
								let password = try? String(contentsOf: passwordFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) else { continue }
							group.enter()
							self.finishImport(p12: p12, provision: provision, password: password, name: folder.lastPathComponent, revoked: false) { result in
								lock.lock()
								switch result { case .success: count += 1; case .failure(let error): if firstError == nil { firstError = error } }
								lock.unlock()
								group.leave()
							}
						}
						group.notify(queue: .main) {
							try? FileManager.default.removeItem(at: root)
							if let error = firstError { completion(.failure(error)) }
							else if count == 0 { completion(.failure(Self.error("No complete certificate folders were found in the archive."))) }
							else { completion(.success(count)) }
						}
					} catch {
						try? FileManager.default.removeItem(at: root)
						DispatchQueue.main.async { completion(.failure(error)) }
					}
				}
			}
		}
	}

	private func finishImport(p12: URL, provision: URL, password: String, name: String, revoked: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
		FR.handleCertificateFiles(p12URL: p12, provisionURL: provision, p12Password: password, certificateName: name) { error in
			if let error { completion(.failure(error)); return }
			if revoked, let imported = Storage.shared.getCertificate(byNickname: name) {
				imported.revoked = true
				Storage.shared.saveContext()
			}
			completion(.success(()))
		}
	}

	private func request(_ url: URL, completion: @escaping (Result<Data, Error>) -> Void) {
		session.dataTask(with: url) { data, response, error in
			if let error { completion(.failure(error)); return }
			guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode), let data else {
				completion(.failure(Self.error("The NexCerts server returned an invalid response.")))
				return
			}
			completion(.success(data))
		}.resume()
	}

	private static func findFile(named suffix: String, in folder: URL) -> URL? {
		guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil) else { return nil }
		for case let url as URL in enumerator where url.lastPathComponent.lowercased().hasSuffix(suffix.lowercased()) { return url }
		return nil
	}

	private static func error(_ message: String) -> NSError {
		NSError(domain: "NexCerts", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
	}
}
