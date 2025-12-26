import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            // Same background as main app
            DS.appBackground
                .ignoresSafeArea()

            Image("launchscreen")
                .resizable()
                .scaledToFit()
        }
    }
}

#Preview {
    LaunchScreenView()
}
