import Foundation
import MultipeerConnectivity
import CoreData
import Model
import UIKit

final class NearbySyncManager: NSObject {
    static let shared = NearbySyncManager()

    private let serviceType = "baby-sync" // <=15 chars, lowercase letters/numbers/hyphen
    private var peerID: MCPeerID!
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!

    private let queue = DispatchQueue(label: "NearbySyncManager.queue")

    private override init() {
        super.init()
    }

    func start() {
        queue.async {
            if self.session != nil { return }

            let deviceName = UIDevice.current.name
            self.peerID = MCPeerID(displayName: deviceName)

            self.session = MCSession(peer: self.peerID, securityIdentity: nil, encryptionPreference: .required)
            self.session.delegate = self

            self.advertiser = MCNearbyServiceAdvertiser(peer: self.peerID, discoveryInfo: nil, serviceType: self.serviceType)
            self.advertiser.delegate = self
            self.advertiser.startAdvertisingPeer()

            self.browser = MCNearbyServiceBrowser(peer: self.peerID, serviceType: self.serviceType)
            self.browser.delegate = self
            self.browser.startBrowsingForPeers()
        }
    }

    func stop() {
        queue.async {
            self.advertiser?.stopAdvertisingPeer()
            self.browser?.stopBrowsingForPeers()
            self.session?.disconnect()
            self.advertiser = nil
            self.browser = nil
            self.session = nil
            self.peerID = nil
        }
    }

    func sendPing() {
        queue.async {
            guard let session = self.session, !session.connectedPeers.isEmpty else { return }
            let payload: [String: Any] = [
                "type": "syncPing",
                "ts": Date.current.timeIntervalSince1970
            ]
            if let data = try? JSONSerialization.data(withJSONObject: payload, options: []) {
                try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
            }
        }
    }

    private func handleIncoming(data: Data, from peer: MCPeerID) {
        guard
            let obj = try? JSONSerialization.jsonObject(with: data, options: []),
            let dict = obj as? [String: Any],
            let type = dict["type"] as? String
        else { return }

        switch type {
        case "syncPing":
            // Keep the model stack warm and flush any pending writes so CloudKit mirroring runs promptly.
            DispatchQueue.main.async {
                let context = PersistenceController.shared.viewContext
                do {
                    try context.save()
                } catch {
                    debugPrint("Failed to save on syncPing: \(error.localizedDescription)")
                }
            }
        default:
            break
        }
    }
}

extension NearbySyncManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        // No-op; could log if needed.
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        handleIncoming(data: data, from: peerID)
    }

    func session(_ session: MCSession,
                 didReceive stream: InputStream,
                 withName streamName: String,
                 fromPeer peerID: MCPeerID) { }

    func session(_ session: MCSession,
                 didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID,
                 with progress: Progress) { }

    func session(_ session: MCSession,
                 didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID,
                 at localURL: URL?,
                 withError error: Error?) { }
}

extension NearbySyncManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }
}

extension NearbySyncManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        guard let session = self.session else { return }
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) { }
}
