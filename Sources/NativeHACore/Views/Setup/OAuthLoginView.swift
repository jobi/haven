import SwiftUI
import AuthenticationServices

public final class OAuthSessionManager: NSObject, ASWebAuthenticationPresentationContextProviding, Sendable {
    public static let shared = OAuthSessionManager()
    
    @MainActor
    public func startOAuth(
        serverURL: URL,
        clientId: String = HAAuthManager.defaultClientId,
        redirectScheme: String = "homeassistant"
    ) async throws -> String {
        guard var components = URLComponents(url: serverURL.appendingPathComponent("auth/authorize"), resolvingAgainstBaseURL: true) else {
            throw AuthSessionError.invalidURL
        }
        
        let redirectURI = "homeassistant://auth-callback"
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code")
        ]
        
        guard let authURL = components.url else {
            throw AuthSessionError.invalidURL
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: redirectScheme
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let callbackURL = callbackURL,
                      let urlComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = urlComponents.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: AuthSessionError.codeMissingInCallback)
                    return
                }
                
                continuation.resume(returning: code)
            }
            
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }
    
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if os(iOS)
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        return windowScene?.windows.first(where: { $0.isKeyWindow }) ?? ASPresentationAnchor()
        #else
        return NSApplication.shared.windows.first ?? ASPresentationAnchor()
        #endif
    }
    
    public enum AuthSessionError: Error, LocalizedError {
        case invalidURL
        case codeMissingInCallback
        
        public var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Failed to build OAuth authorization URL."
            case .codeMissingInCallback:
                return "Authorization code was not found in the callback URL."
            }
        }
    }
}
