//
//  SettingsView.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct SettingsView: View {
    @AppStorage("feather.selectedCert") private var _storedSelectedCert: Int = 0
    @FetchRequest(
        entity: CertificatePair.entity(),
        sortDescriptors: [],
        animation: .snappy
    ) private var _certificates: FetchedResults<CertificatePair>

    private var sortedCertificates: [CertificatePair] {
        return _certificates.sorted { cert1, cert2 in
            // First, sort by revoked status (false/valid first, true/revoked last)
            if cert1.revoked != cert2.revoked {
                return !cert1.revoked && cert2.revoked
            }

            // Within the same revoked status, sort by expiry date (latest first)
            let expiry1 = _getEarliestExpiry(for: cert1)
            let expiry2 = _getEarliestExpiry(for: cert2)

            return expiry1 > expiry2
        }
    }

    private func _getEarliestExpiry(for cert: CertificatePair) -> Date {
        var earliestExpiry = cert.expiration ?? Date.distantFuture

        // Check mobileprovision expiry if available
        if let provisionFile = Storage.shared.getFile(.provision, from: cert),
           let provision = Storage.shared.getProvisionFileDecoded(for: cert) {
            let provisionExpiry = provision.expirationDate ?? Date.distantFuture
            earliestExpiry = min(earliestExpiry, provisionExpiry)
        }

        return earliestExpiry
    }

    private var selectedCertificate: CertificatePair? {
        guard
            _storedSelectedCert >= 0,
            _storedSelectedCert < sortedCertificates.count
        else {
            return nil
        }
        return sortedCertificates[_storedSelectedCert]
    }
    
    
	private let _githubUrl = "https://github.com/NexSideloading/NexStore-Fixed"
    private let _discordUrl = "https://discord.gg/nXYUhP6N4N"
	// MARK: Body
    var body: some View {
		NBNavigationView(.localized("Settings")) {
			Form {				
				_feedback()
				
				Section {
					NavigationLink(destination: AppearanceView()) {
						Label(.localized("Appearance"), systemImage: "paintbrush")
					}
				}
                
                NBSection(.localized("Certificates")) {

                    if let cert = selectedCertificate {
                        CertificatesCellView(cert: cert)
                    } else {
                        Text(.localized("No Certificate"))
                            .font(.footnote)
                            .foregroundColor(.disabled())
                    }
                    NavigationLink(destination: CertificatesView()) {
                        Label(.localized("Certificates"), systemImage: "signature")
                    }

                } footer: {
                    Text(.localized("Add and manage certificates used for signing applications."))
                }
                .onAppear {
					// Update the selected index to match the sorted order
					if _storedSelectedCert >= 0 && _storedSelectedCert < _certificates.count {
						let currentUUID = _certificates[_storedSelectedCert].uuid
						if let newIndex = sortedCertificates.firstIndex(where: { $0.uuid == currentUUID }) {
							_storedSelectedCert = newIndex
						}
					}
				}
				.onChange(of: _certificates.count) { _, _ in
					// Update the selected index when certificates change
					if _storedSelectedCert >= 0 && _storedSelectedCert < _certificates.count {
						let currentUUID = _certificates[_storedSelectedCert].uuid
						if let newIndex = sortedCertificates.firstIndex(where: { $0.uuid == currentUUID }) {
							_storedSelectedCert = newIndex
						}
					}
				}

                Section {
                    NavigationLink(destination: NexDNSSettingsView()) {
                        Label("NexDNS Dynamic", systemImage: "network")
                    }
                } footer: {
                    Text("Configure NexDNS Dynamic for automatic PPQ enablement.")
                }
				
				NBSection(.localized("Features")) {
                    NavigationLink(destination: LogsView(manager: LogsManager.shared)) {
                        Label(.localized("Logs"), systemImage: "apple.terminal")
                    }
					NavigationLink(destination: AppFeaturesView()) {
                        Label(.localized("App Features"), systemImage: "sparkles")
                    }
					NavigationLink(destination: ConfigurationView()) {
                        Label(.localized("Signing Options"), systemImage: "gear")
                    }
					NavigationLink(destination: ArchiveView()) {
                        Label(.localized("Archive & Extraction"), systemImage: "archivebox")
                    }
					NavigationLink(destination: InstallationView()) {
                        Label(.localized("Installation"), systemImage: "server.rack")
                    }
				}
				
				_directories()
                
                Section {
                    NavigationLink(destination: ResetView()) {
                        Label(.localized("Reset"), systemImage: "trash")
                    }
                } footer: {
                    Text("Reset the applications sources, certificates, apps, and general contents.")
                }

            }
        }
    }
}

// MARK: - View extension
extension SettingsView {
	@ViewBuilder
	private func _feedback() -> some View {
		Section {
			NavigationLink(destination: AboutNyaView()) {
                Label(.localized("About"), systemImage: "info.circle")
            }
			Button(.localized("GitHub Repository"), systemImage: "safari") {
				UIApplication.open(_githubUrl)
			}
            Button(.localized("Discord Server"), systemImage: "safari") {
                UIApplication.open(_discordUrl)
            }
		}
	}
	
	@ViewBuilder
	private func _directories() -> some View {
		NBSection(.localized("Misc")) {
			Button(.localized("Open Documents"), systemImage: "folder") {
				UIApplication.open(URL.documentsDirectory.toSharedDocumentsURL()!)
			}
			Button(.localized("Open Archives"), systemImage: "folder") {
				UIApplication.open(FileManager.default.archives.toSharedDocumentsURL()!)
			}
		} footer: {
			Text(.localized("All of NexStore files except certificates are contained in the documents directory, here are some quick links to these."))
		}
	}
}
