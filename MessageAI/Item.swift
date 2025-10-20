//
//  Item.swift
//  MessageAI
//
//  Created by Akhil Pinnani on 10/20/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
