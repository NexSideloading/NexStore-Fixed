import SwiftUI

struct NexCertsImportView: View {
	@Environment(\.dismiss) private var dismiss
	@State private var certificates: [NexCertsCertificate] = []
	@State private var isLoading = true
	@State private var isImportingAll = false
	@State private var importingIDs: Set<Int> = []
	@State private var errorMessage: String?
	@State private var notice: String?

	var body: some View {
		NavigationStack {
			Group {
				if isLoading {
					ProgressView("Loading certificates…")
				} else if certificates.isEmpty {
					VStack(spacing: 12) {
						Image(systemName: "person.text.rectangle").font(.largeTitle).foregroundStyle(.secondary)
						Text("No certificates available").font(.headline)
					}
					.frame(maxWidth: .infinity, maxHeight: .infinity)
				} else {
					List {
						Section {
							Button {
								importAll()
							} label: {
								HStack {
									Label("Import all", systemImage: "square.and.arrow.down")
									Spacer()
									if isImportingAll { ProgressView() }
								}
							}
							.disabled(isImportingAll || !importingIDs.isEmpty)
						}
						ForEach(certificates) { certificate in
							HStack(spacing: 12) {
								VStack(alignment: .leading, spacing: 5) {
									Text(certificate.name).font(.body)
									Text(certificate.status).font(.subheadline).foregroundStyle(.secondary)
									Text(expiryText(certificate.valid_to)).font(.caption).foregroundStyle(.secondary)
								}
								Spacer(minLength: 8)
								if importingIDs.contains(certificate.id) {
									ProgressView()
								} else {
									Button("Import") { importCertificate(certificate) }
										.buttonStyle(.bordered)
										.disabled(isImportingAll || !importingIDs.isEmpty)
								}
							}
							.padding(.vertical, 4)
						}
					}
				}
			}
			.navigationTitle("Import NexCerts")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
				ToolbarItem(placement: .primaryAction) {
					Button { load() } label: { Image(systemName: "arrow.clockwise") }
						.disabled(isLoading || isImportingAll || !importingIDs.isEmpty)
				}
			}
			.alert("Import error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
				Button("OK", role: .cancel) { errorMessage = nil }
			} message: { Text(errorMessage ?? "") }
			.alert("Import complete", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
				Button("OK", role: .cancel) { notice = nil }
			} message: { Text(notice ?? "") }
			.onAppear(perform: load)
		}
	}

	private func load() {
		isLoading = true
		NexCertsService.shared.fetchCertificates { result in
			isLoading = false
			switch result {
			case .success(let values): certificates = values
			case .failure(let error): errorMessage = error.localizedDescription
			}
		}
	}

	private func importCertificate(_ certificate: NexCertsCertificate) {
		importingIDs.insert(certificate.id)
		NexCertsService.shared.importCertificate(certificate) { result in
			importingIDs.remove(certificate.id)
			switch result {
			case .success: notice = "\(certificate.name) was imported."
			case .failure(let error): errorMessage = error.localizedDescription
			}
		}
	}

	private func importAll() {
		isImportingAll = true
		NexCertsService.shared.importAll { result in
			isImportingAll = false
			switch result {
			case .success(let count): notice = "Imported \(count) certificates."
			case .failure(let error): errorMessage = error.localizedDescription
			}
		}
	}

	private func expiryText(_ value: String) -> String {
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.timeZone = TimeZone(secondsFromGMT: 0)
		formatter.dateFormat = "MMM d HH:mm:ss yyyy 'GMT'"
		guard let expiry = formatter.date(from: value) else { return "Expires \(value)" }
		let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: expiry)).day ?? 0
		if days < 0 { return "Expired \(abs(days)) \(abs(days) == 1 ? "day" : "days") ago" }
		if days == 0 { return "Expires today" }
		return "\(days) \(days == 1 ? "day" : "days") left"
	}
}
