//
//  AboutNyaView.swift
//  Ksign
//
//  Created by Nagata Asami on 23/5/25.
//

import SwiftUI
import NimbleViews
import NimbleJSON

// MARK: - View
struct AboutNyaView: View {
	private let _dataService = NBFetchService()
	
	@State private var shouldShowPatchNotes = false
	
	// MARK: Body
	var body: some View {
		NBList(.localized("About")) {
            Section {
                VStack {
                    if let iconImage = UIImage(named: Bundle.main.iconFileName ?? "") {
                        Image(uiImage: iconImage)
                            .appIconStyle(size: 72)
                    }
                    
                    Text(Bundle.main.exec)
                        .font(.largeTitle)
                        .bold()
                        .foregroundStyle(.accent)
                    
                    HStack(spacing: 4) {
                        Text("Version")
                        Text(Bundle.main.version)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    
                    Button {
                        _showPatchNotes()
                    } label: {
                        Text("Show patch notes").bg()
                    }
                    .font(.footnote)
                    .padding(.top, 4)
                    .tint(.accent)
                }
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(EmptyView())
			
			NBSection(.localized("Credits")) {
				_credit(name: "NovaDev404", desc: "NexStore Developer (Based on Ksign)", github: "novadev404")
				_credit(name: "Nyasami", desc: "Ksign Developer (Based on Feather)", github: "nyasami")
				_credit(name: "Claration", desc: "Feather Developer", github: "claration")
			}
			
			NBSection("Special thanks!") {
				Text(.localized("This couldn't have been done without the original Ksign & Feather devs!"))
					.foregroundStyle(.secondary)
					.padding(.vertical, 2)
			}
            
            NBSection("Acknowledgements") {
                NavigationLink(destination: AboutView()) {
                    HStack {
                        Text("About the original Feather")
                        Spacer()
                    }
                }
            } footer: {
                Text(Bundle.main.bundleIdentifier ?? "")
            }
		}
		.onAppear {
			// Show patch notes when navigating to this view if they haven't been shown before
			if !UserDefaults.standard.bool(forKey: "patchNotesShown") {
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
					_showPatchNotes()
					UserDefaults.standard.set(true, forKey: "patchNotesShown")
				}
			}
		}
	}
	
	private func _showPatchNotes() {
		UIAlertController.showAlertWithOk(
			title: .localized("From NovaDev404, Version \(Bundle.main.version)"),
			message: .localized("This version is a new fork of Ksign, and includes:\n\n- NexRevokeDNS Dynamic Support\n- NexCerts Integration\n- Fixed installation issue\n- NexSideloading Certchecker for accurate OCSP status"),
			isCancel: true,
			thankYou: true
		)
	}
}

// MARK: - Extension: view
extension AboutNyaView {
	@ViewBuilder
	private func _credit(
		name: String?,
		desc: String?,
		github: String
	) -> some View {
		FRIconCellView(
			title: name ?? github,
			subtitle: desc ?? "",
			iconUrl: URL(string: "https://github.com/\(github).png")!,
			trailing: AnyView(
				Image(systemName: "arrow.up.right")
					.foregroundStyle(.secondary)
			)
		)
		.onTapGesture {
			if let url = URL(string: "https://github.com/\(github)") {
				UIApplication.shared.open(url)
			}
		}
	}
}
