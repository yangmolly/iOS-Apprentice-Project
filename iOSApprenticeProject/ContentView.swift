import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        Group {
            if auth.isSignedIn {
                ExploreView()
            } else {
                NavigationStack {
                    SignInView()
                }
            }
        }
        .task {
            await auth.restoreSession()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
