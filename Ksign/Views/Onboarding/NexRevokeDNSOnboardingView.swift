//
//  NexRevokeDNSOnboardingView.swift
//  NexStore
//
//  Created by NovaDev404 on 26.10.2026.
//

import SwiftUI

struct NexRevokeDNSOnboardingView: View {
	@State private var isUsingNexRevokeDNS = false
	@State private var nexRevokeDNSUID = ""
	@State private var showExplanation = false
	@Environment(\.dismiss) private var dismiss
	@ObservedObject private var optionsManager = OptionsManager.shared

	var body: some View {
		NavigationStack {
			Form {
				Section {
					VStack(alignment: .leading, spacing: 12) {
						Text("NexRevokeDNS Dynamic")
							.font(.title2)
							.fontWeight(.bold)

						Text("NexRevokeDNS Dynamic allows automatic PPQ enablement for signed apps through your Dynamic DNS UID.")
							.font(.subheadline)
							.foregroundColor(.secondary)

						Button("Learn more") {
							showExplanation = true
						}
						.font(.caption)
					}
					.padding(.vertical, 8)
				}

				Section {
					Toggle("Use NexRevokeDNS Dynamic", isOn: $isUsingNexRevokeDNS)
						.onChange(of: isUsingNexRevokeDNS) { newValue in
							if !newValue {
								nexRevokeDNSUID = ""
							}
						}
				} header: {
					Text("Setup")
				}

				if isUsingNexRevokeDNS {
					Section {
						VStack(alignment: .leading, spacing: 8) {
							Text("NexRevokeDNS Dynamic UID")
								.font(.headline)

							TextField("Enter your UID", text: $nexRevokeDNSUID)
								.textFieldStyle(.roundedBorder)
								.autocapitalization(.none)
								.disableAutocorrection(true)

							Text("Find your UID in the Dynamic DNS section at sideloading.net/dns/")
								.font(.caption)
								.foregroundColor(.secondary)
						}
						.padding(.vertical, 4)
					}
				}

				Section {
					Button("Continue") {
						saveAndDismiss()
					}
					.frame(maxWidth: .infinity)
					.disabled(isUsingNexRevokeDNS && nexRevokeDNSUID.isEmpty)
				}
			}
			.navigationTitle("Setup NexRevokeDNS")
			.navigationBarTitleDisplayMode(.inline)
			.sheet(isPresented: $showExplanation) {
				NexRevokeDNSExplanationView()
			}
		}
	}

	private func saveAndDismiss() {
		optionsManager.options.nexRevokeDNSEnabled = isUsingNexRevokeDNS
		optionsManager.options.nexRevokeDNSUID = isUsingNexRevokeDNS ? nexRevokeDNSUID : nil
		optionsManager.saveOptions()
		UserDefaults.standard.set(true, forKey: "hasCompletedNexRevokeDNSOnboarding")
		dismiss()
	}
}

struct NexRevokeDNSExplanationView: View {
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 16) {
					Text("What is NexRevokeDNS Dynamic?")
						.font(.title2)
						.fontWeight(.bold)

					Text("NexRevokeDNS Dynamic is a service that automatically enables PPQ (Provisioning Profile Query) for your signed apps. This helps prevent app revokes by Apple.")

					VStack(alignment: .leading, spacing: 8) {
						Text("How it works:")
							.font(.headline)
						Text("1. When you sign an app, NexStore will call the NexRevokeDNS API")
						Text("2. Your UID is used to identify your personal DNS")
						Text("3. PPQ is automatically enabled to let your app install")
					}

					VStack(alignment: .leading, spacing: 8) {
						Text("Finding your UID:")
							.font(.headline)
						Text("1. Visit https://sideloading.net/dns/")
						Text("2. Go to the Dynamic DNS section")
						Text("3. Copy your NexRevokeDNS Dynamic UID")
					}

					Button("Got it") {
						dismiss()
					}
					.frame(maxWidth: .infinity)
					.buttonStyle(.borderedProminent)
				}
				.padding()
			}
			.navigationTitle("About NexRevokeDNS")
			.navigationBarTitleDisplayMode(.inline)
		}
	}
}
