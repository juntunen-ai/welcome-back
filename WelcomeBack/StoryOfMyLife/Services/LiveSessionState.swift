import Foundation

// MARK: - Live Session State

/// Shared state enum that drives the UI, service, and view model
/// for a Gemini Multimodal Live API conversation session.
enum LiveSessionState: Equatable {
    /// No session active.
    case idle
    /// WebSocket is opening; setup message not yet acknowledged.
    case connecting
    /// Setup complete; mic hot; waiting for Harri to speak.
    case listening
    /// VAD detected Harri is actively speaking.
    case userSpeaking
    /// Harri's turn ended; Gemini is generating a response.
    case aiThinking
    /// Gemini is streaming audio back; player is active.
    case aiSpeaking
    /// Harri spoke mid-response; player stopped; resuming listening.
    case interrupted
    /// A non-recoverable error occurred.
    case error(String)
    /// Session cleanly ended.
    case disconnected
}
