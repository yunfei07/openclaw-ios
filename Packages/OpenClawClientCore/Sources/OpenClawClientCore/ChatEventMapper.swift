import Foundation
import OpenClawProtocol

public enum ChatEventMapper {
    public static func from(event: EventFrame) -> ChatEvent? {
        guard event.event == "chat" else { return nil }
        guard let payload = event.payload?.value as? [String: AnyCodable] else { return nil }
        guard let runId = payload["runId"]?.value as? String,
              let sessionKey = payload["sessionKey"]?.value as? String else { return nil }
        let seq = (payload["seq"]?.value as? Int) ?? event.seq
        let stateRaw = payload["state"]?.value as? String
        let state = ChatEventState(rawValue: stateRaw ?? "") ?? .unknown
        let errorMessage = payload["errorMessage"]?.value as? String
        let message = payload["message"].flatMap { ChatMessageMapper.fromHistory([$0]).first }
        return ChatEvent(
            runId: runId,
            sessionKey: sessionKey,
            seq: seq,
            state: state,
            message: message,
            errorMessage: errorMessage
        )
    }
}
