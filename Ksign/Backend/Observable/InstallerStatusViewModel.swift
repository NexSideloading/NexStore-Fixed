//
//  StatusViewModel.swift
//  Feather
//
//  Created by samara on 24.04.2025.
//

import Foundation
import Combine
import IDeviceSwift
import ObjectiveC

private var dynamicDNSInProgressKey: UInt8 = 0

extension InstallerStatusViewModel {
	/// Enables NexRevokeDNS before the installer starts copying and packaging the app.
	func enableDynamicDNSIfConfigured() async throws {
		let options = OptionsManager.shared.options
		guard options.nexRevokeDNSEnabled, let uid = options.nexRevokeDNSUID else {
			return
		}

		isEnablingDynamicDNS = true
		defer { isEnablingDynamicDNS = false }
		_ = try await NexRevokeDNSService.shared.enablePPQ(uid: uid)
	}

	private var isEnablingDynamicDNS: Bool {
		get { objc_getAssociatedObject(self, &dynamicDNSInProgressKey) as? Bool ?? false }
		set {
			objectWillChange.send()
			objc_setAssociatedObject(self, &dynamicDNSInProgressKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
		}
	}
	
	var statusImage: String {
		if isEnablingDynamicDNS { return "network" }

		switch status {
		case .none: return "archivebox.fill"
		case .ready: return "app.gift"
		case .sendingManifest, .sendingPayload: return "paperplane.fill"
		case .installing: return "square.and.arrow.down"
		case .completed: return "app.badge.checkmark"
		case .broken: return "exclamationmark.triangle.fill"
		}
	}
	
	var statusLabel: String {
		if isEnablingDynamicDNS { return "Enabling Dynamic DNS" }

		switch status {
		case .none: return "Packaging"
		case .ready: return "Ready"
		case .sendingManifest: return "Sending Manifest"
		case .sendingPayload: return "Sending Payload"
		case .installing: return "Installing"
		case .completed: return "Completed"
		case .broken: return "Error"
		}
	}
}
