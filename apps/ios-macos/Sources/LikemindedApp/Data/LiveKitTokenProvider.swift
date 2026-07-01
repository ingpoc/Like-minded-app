import Foundation

struct LiveKitTokenProvider {
    let client: LikemindedAPIClient

    func token(for meetingId: String) async throws -> LiveKitJoinToken {
        try await client.joinMeeting(id: meetingId)
    }
}
