//
//  ConvenApp.swift
//  Conven
//
//  Created by 土豆星球 on 2025/10/9.
//

import SwiftUI
import CoreData

@main
struct ConvenApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
