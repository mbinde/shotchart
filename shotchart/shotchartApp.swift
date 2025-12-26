import SwiftUI

@main
struct HoopChartApp: App {
    let persistenceController = PersistenceController.shared
    @State private var showingSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)

                if showingSplash {
                    LaunchScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showingSplash = false
                    }
                }
            }
        }
    }
}
