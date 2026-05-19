//
//  Item.swift
//  SpendTracker
//
//  Created by Harshal Sarode on 19/05/2026.
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
