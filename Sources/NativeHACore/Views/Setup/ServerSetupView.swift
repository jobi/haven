import SwiftUI

public struct ServerSetupView: View {
    @State private var serverUrlString: String = "http://homeassistant.local:8123"
    @State private var serverName: String = "Home Assistant"
    @State private var longLivedToken: String = ""
    @State private var useManualToken: Bool = false
    
    @State private var isConnecting: Bool = false
    @State private var errorMessage: String? = nil
    
    let onLoginSuccess: (ServerConfig) -> Void
    
    public init(onLoginSuccess: @escaping (ServerConfig) -> Void) {
        self.onLoginSuccess = onLoginSuccess
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.haBlue)
                            .padding(.top, 8)
                        
                        Text("Connect to Home Assistant")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)
                        
                        Text("Enter your Home Assistant instance URL to connect and render native Section dashboards.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }
                
                Section("Server Details") {
                    TextField("Server Name", text: $serverName)
                    
                    TextField("Server URL", text: $serverUrlString)
                        #if os(iOS)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        #endif
                }
                
                Section("Authentication Method") {
                    Toggle("Use Long-Lived Access Token", isOn: $useManualToken)
                    
                    if useManualToken {
                        SecureField("Access Token", text: $longLivedToken)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            #endif
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                
                Section {
                    Button {
                        handleConnect()
                    } label: {
                        HStack {
                            Spacer()
                            if isConnecting {
                                ProgressView()
                                    .padding(.trailing, 4)
                            }
                            Text(useManualToken ? "Save & Connect" : "Log In with Home Assistant")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(isConnecting || serverUrlString.isEmpty || (useManualToken && longLivedToken.isEmpty))
                }
            }
            .navigationTitle("Welcome")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
    
    private func handleConnect() {
        guard let url = ServerConfig.normalizeURLString(serverUrlString) else {
            errorMessage = "Invalid URL. Please enter a valid address."
            return
        }
        
        isConnecting = true
        errorMessage = nil
        
        Task {
            let restClient = HARestClient()
            let isReachable = (try? await restClient.testConnection(url: url)) ?? false
            
            if !isReachable {
                await MainActor.run {
                    errorMessage = "Could not reach server at \(url.absoluteString). Please check the address."
                    isConnecting = false
                }
                return
            }
            
            let server = ServerConfig(
                name: serverName.isEmpty ? "Home Assistant" : serverName,
                url: url
            )
            
            if useManualToken {
                do {
                    try await HAAuthManager.shared.saveLongLivedToken(server: server, token: longLivedToken)
                    await MainActor.run {
                        isConnecting = false
                        onLoginSuccess(server)
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = "Failed to save token: \(error.localizedDescription)"
                        isConnecting = false
                    }
                }
            } else {
                do {
                    let code = try await OAuthSessionManager.shared.startOAuth(serverURL: url)
                    _ = try await HAAuthManager.shared.completeOAuthLogin(server: server, authCode: code)
                    await MainActor.run {
                        isConnecting = false
                        onLoginSuccess(server)
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = "Authentication failed: \(error.localizedDescription)"
                        isConnecting = false
                    }
                }
            }
        }
    }
}
