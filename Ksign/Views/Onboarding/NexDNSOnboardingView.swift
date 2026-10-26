//
//  NexDNSOnboardingView.swift
//  NexStore
//
//  Created by NovaDev404 on 26.10.2026.
//

import SwiftUI

struct NexDNSOnboardingView: View {
	@State private var isUsingNexDNS = false
	@State private var nexDNSUID = ""
	@State private var showExplanation = false
	@Environment(\.dismiss) private var dismiss
	@ObservedObject private var optionsManager = OptionsManager.shared

	var body: some View {
		NavigationStack {
			Form {
				Section {
					VStack(alignment: .leading, spacing: 12) {
						Text("NexDNS Dynamic")
							.font(.title2)
							.fontWeight(.bold)

						Text("NexDNS Dynamic allows automatic PPQ enablement for signed apps through your Dynamic DNS UID.")
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
					Toggle("Use NexDNS Dynamic", isOn: $isUsingNexDNS)
						.onChange(of: isUsingNexDNS) { newValue in
							if !newValue {
								nexDNSUID = ""
							}
						}
				} header: {
					Text("Setup")
				}

				if isUsingNexDNS {
					Section {
						VStack(alignment: .leading, spacing: 8) {
							Text("NexDNS Dynamic UID")
								.font(.headline)

							TextField("Enter your UID", text: $nexDNSUID)
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
					.disabled(isUsingNexDNS && nexDNSUID.isEmpty)
				}
			}
			.navigationTitle("Setup NexDNS")
			.navigationBarTitleDisplayMode(.inline)
			.sheet(isPresented: $showExplanation) {
				NexDNSExplanationView()
			}
		}
	}

	private func saveAndDismiss() {
		optionsManager.options.nexDNSEnabled = isUsingNexDNS
		optionsManager.options.nexDNSUID = isUsingNexDNS ? nexDNSUID : nil
		optionsManager.saveOptions()
		UserDefaults.standard.set(true, forKey: "hasCompletedNexDNSOnboarding")
		dismiss()
	}
}

struct NexDNSExplanationView: View {
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 16) {
					Text("What is NexDNS Dynamic?")
						.font(.title2)
						.fontWeight(.bold)

					Text("NexDNS Dynamic is a service that automatically enables PPQ (Profile Qualification) for your signed apps. This helps prevent app revocation by Apple.")

					VStack(alignment: .leading, spacing: 8) {
						Text("How it works:")
							.font(.headline)
						Text("1. When you sign an app, NexStore will call the NexDNS API")
						Text("2. Your UID is used to identify your account")
						Text("3. PPQ is automatically enabled for your domain")
						Text("4. The app waits 10 seconds before continuing")
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
			.navigationTitle("About NexDNS")
			.navigationBarTitleDisplayMode(.inline)
		}
	}
}
