//
//  NetworkMonitor.swift
//  MessageAI
//
//  Real-time network connectivity monitoring
//

import Foundation
import Network
import Combine

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published private(set) var isConnected: Bool = true
    @Published private(set) var connectionType: ConnectionType = .unknown
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        monitor.cancel()
    }
    
    // MARK: - Monitoring
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                let wasConnected = self.isConnected
                self.isConnected = path.status == .satisfied
                
                // Log connection changes
                if wasConnected != self.isConnected {
                    if self.isConnected {
                        print("🌐 Network: Connected")
                    } else {
                        print("📡 Network: Disconnected")
                    }
                }
                
                // Determine connection type
                if path.usesInterfaceType(.wifi) {
                    self.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.connectionType = .ethernet
                } else {
                    self.connectionType = .unknown
                }
            }
        }
        
        monitor.start(queue: queue)
        print("🌐 NetworkMonitor: Started monitoring")
    }
    
    // MARK: - Public API
    
    var connectionDescription: String {
        if !isConnected {
            return "Offline"
        }
        
        switch connectionType {
        case .wifi:
            return "Wi-Fi"
        case .cellular:
            return "Cellular"
        case .ethernet:
            return "Ethernet"
        case .unknown:
            return "Connected"
        }
    }
}

