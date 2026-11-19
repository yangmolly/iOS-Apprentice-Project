import SwiftUI

struct ContentView: View {
    @Environment(AuthViewModel.self) private var auth

    var body: some View {
        Group {
            switch auth.phase {
            case .launching:
                ProgressView()
            case .signedOut:
                AuthFlowView()
            case .signedIn:
                MainTabView()
            }
        }
        .animation(.default, value: auth.phase)
        .task {
            auth.start()
        }
    }
}

#Preview {
    ContentView()
        .environment(AuthViewModel.preview())
        .environment(AppEnvironment.preview())
        .environment(LocationService())
}
