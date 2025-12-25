import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            // Same background as main app
            DS.appBackground
                .ignoresSafeArea()

            Image("loading-screen")
                .resizable()
                .scaledToFit()
        }
    }
}

#Preview {
    LaunchScreenView()
}
