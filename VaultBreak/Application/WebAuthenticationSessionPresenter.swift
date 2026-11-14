import AppKit
import AuthenticationServices

@MainActor
protocol WebAuthenticationCancelling: AnyObject {
    func cancel()
}

@MainActor
protocol WebAuthenticationStarting: AnyObject {
    @discardableResult
    func start(
        url: URL,
        callbackScheme: String,
        completion: @escaping @MainActor (Result<URL, Error>) -> Void
    ) throws -> WebAuthenticationCancelling
}

enum WebAuthenticationSessionStartError: Error {
    case couldNotStart
    case missingCallback
}

@MainActor
final class WebAuthenticationSessionPresenter: NSObject, WebAuthenticationStarting,
    ASWebAuthenticationPresentationContextProviding
{
    private var fallbackWindow: NSWindow?

    func start(
        url: URL,
        callbackScheme: String,
        completion: @escaping @MainActor (Result<URL, Error>) -> Void
    ) throws -> WebAuthenticationCancelling {
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callback, error in
            Task { @MainActor in
                if let callback {
                    completion(.success(callback))
                } else if let error {
                    completion(.failure(error))
                } else {
                    completion(.failure(WebAuthenticationSessionStartError.missingCallback))
                }
            }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        guard session.start() else {
            throw WebAuthenticationSessionStartError.couldNotStart
        }
        return WebAuthenticationSessionHandle(session: session)
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let keyWindow = NSApp.keyWindow { return keyWindow }
        if let visibleWindow = NSApp.orderedWindows.first(where: \.isVisible) { return visibleWindow }

        if fallbackWindow == nil {
            fallbackWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            fallbackWindow?.isReleasedWhenClosed = false
            fallbackWindow?.alphaValue = 0
            fallbackWindow?.orderFront(nil)
        }
        return fallbackWindow!
    }
}

@MainActor
private final class WebAuthenticationSessionHandle: WebAuthenticationCancelling {
    private var session: ASWebAuthenticationSession?

    init(session: ASWebAuthenticationSession) {
        self.session = session
    }

    func cancel() {
        session?.cancel()
        session = nil
    }
}
