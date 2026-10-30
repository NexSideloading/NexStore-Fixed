//
//  NexRevokeDNSSettingsView.swift
//  NexStore
//
//  Created by NovaDev404 on 26.10.2026.
//

import SwiftUI

struct NexRevokeDNSSettingsView: View {
	@ObservedObject private var optionsManager = OptionsManager.shared
	@State private var isEditingUID = false
	@State private var tempUID = ""

	var body: some View {
		Form {
			Section {
				Toggle("Enable NexRevokeDNS Dynamic", isOn: Binding(
					get: { optionsManager.options.nexRevokeDNSEnabled },
					set: { newValue in
						optionsManager.options.nexRevokeDNSEnabled = newValue
						if !newValue {
							optionsManager.options.nexRevokeDNSUID = nil
						}
						optionsManager.saveOptions()
					}
				))
			} header: {
				Text("NexRevokeDNS Dynamic")
			} footer: {
				Text("Automatically enable PPQ for signed apps using your NexRevokeDNS Dynamic UID.")
			}

			if optionsManager.options.nexRevokeDNSEnabled {
				Section {
					HStack {
						Text("UID")
						Spacer()
						if let uid = optionsManager.options.nexRevokeDNSUID {
							Text(uid)
								.foregroundColor(.secondary)
						} else {
							Text("Not set")
								.foregroundColor(.secondary)
						}
					}

					Button("Change UID") {
						tempUID = optionsManager.options.nexRevokeDNSUID ?? ""
						isEditingUID = true
					}
				} header: {
					Text("Configuration")
				} footer: {
					Text("Find your UID in the Dynamic DNS section at https://sideloading.net/dns/")
				}
			}

			Section {
				Button("Open NexRevokeDNS Settings") {
					if let url = URL(string: "https://sideloading.net/dns/") {
						UIApplication.open(url)
					}
				}
			}
		}
		.navigationTitle("NexRevokeDNS")
		.navigationBarTitleDisplayMode(.inline)
		.sheet(isPresented: $isEditingUID) {
			NavigationStack {
				Form {
					Section {
						VStack(alignment: .leading, spacing: 8) {
							Text("NexRevokeDNS Dynamic UID")
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
							optionsManager.options.nexRevokeDNSUID = tempUID.isEmpty ? nil : tempUID
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
