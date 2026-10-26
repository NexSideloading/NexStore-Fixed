//
//  NexDNSSettingsView.swift
//  NexStore
//
//  Created by NovaDev404 on 26.10.2026.
//

import SwiftUI

struct NexDNSSettingsView: View {
	@ObservedObject private var optionsManager = OptionsManager.shared
	@State private var isEditingUID = false
	@State private var tempUID = ""

	var body: some View {
		Form {
			Section {
				Toggle("Enable NexDNS Dynamic", isOn: Binding(
					get: { optionsManager.options.nexDNSEnabled },
					set: { newValue in
						optionsManager.options.nexDNSEnabled = newValue
						if !newValue {
							optionsManager.options.nexDNSUID = nil
						}
						optionsManager.saveOptions()
					}
				))
			} header: {
				Text("NexDNS Dynamic")
			} footer: {
				Text("Automatically enable PPQ for signed apps using your NexDNS Dynamic UID.")
			}

			if optionsManager.options.nexDNSEnabled {
				Section {
					HStack {
						Text("UID")
						Spacer()
						if let uid = optionsManager.options.nexDNSUID {
							Text(uid)
								.foregroundColor(.secondary)
						} else {
							Text("Not set")
								.foregroundColor(.secondary)
						}
					}

					Button("Change UID") {
						tempUID = optionsManager.options.nexDNSUID ?? ""
						isEditingUID = true
					}
				} header: {
					Text("Configuration")
				} footer: {
					Text("Find your UID in the Dynamic DNS section at https://sideloading.net/dns/")
				}
			}

			Section {
				Button("Open NexDNS Settings") {
					if let url = URL(string: "https://sideloading.net/dns/") {
						UIApplication.open(url)
					}
				}
			}
		}
		.navigationTitle("NexDNS")
		.navigationBarTitleDisplayMode(.inline)
		.sheet(isPresented: $isEditingUID) {
			NavigationStack {
				Form {
					Section {
						VStack(alignment: .leading, spacing: 8) {
							Text("NexDNS Dynamic UID")
								.font(.headline)

							TextField("Enter your UID", text: $tempUID)
								.textFieldStyle(.roundedBorder)
								.autocapitalization(.none)
								.disableAutocorrection(true)

							Text("Find your UID in the Dynamic DNS section at sideloading.net/dns/")
								.font(.caption)
								.foregroundColor(.secondary)
						}
						.padding(.vertical, 4)
					}

					Section {
						Button("Save") {
							optionsManager.options.nexDNSUID = tempUID.isEmpty ? nil : tempUID
							optionsManager.saveOptions()
							isEditingUID = false
						}
						.frame(maxWidth: .infinity)
						.disabled(tempUID.isEmpty)
					}
				}
				.navigationTitle("Edit UID")
				.navigationBarTitleDisplayMode(.inline)
				.toolbar {
					ToolbarItem(placement: .cancellationAction) {
						Button("Cancel") {
							isEditingUID = false
						}
					}
				}
			}
		}
	}
}
