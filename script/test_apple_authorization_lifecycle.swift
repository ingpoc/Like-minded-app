import Foundation

@main
struct AuthorizationLifecycleChecks {
    @MainActor
    static func main() async {
        await missingCallbackTimesOut()
        await callbackDuringCancelIsIgnored()
        await lateCallbackCannotCompleteReplacement()
        print("PASS Apple authorization lifecycle: timeout, synchronous cancel callback, late callback, replacement nonce")
    }

    @MainActor
    private static func missingCallbackTimesOut() async {
        let coordinator = AuthorizationRequestCoordinator<String>()
        let controller = NSObject()
        let result = await coordinator.begin(
            controller: controller,
            nonce: "timeout-nonce",
            timeoutNanoseconds: 10_000_000,
            cancelController: {},
            perform: {}
        )
        guard case .failure(let error) = result,
              (error as? URLError)?.code == .timedOut else {
            preconditionFailure("missing callback did not time out")
        }
    }

    @MainActor
    private static func callbackDuringCancelIsIgnored() async {
        let coordinator = AuthorizationRequestCoordinator<String>()
        let firstController = NSObject()
        let secondController = NSObject()
        let first = Task { await coordinator.begin(controller: firstController, nonce: "A", timeoutNanoseconds: 1_000_000_000, cancelController: {}, perform: {}) }
        while coordinator.nonce(for: firstController) == nil { await Task.yield() }
        let second = Task {
            await coordinator.begin(
                controller: secondController,
                nonce: "B",
                timeoutNanoseconds: 1_000_000_000,
                cancelController: { coordinator.complete(controller: firstController, with: .success("stale-sync")) },
                perform: {}
            )
        }
        while coordinator.nonce(for: secondController) == nil { await Task.yield() }
        coordinator.complete(controller: secondController, with: .success("accepted"))
        let firstResult = await first.value
        let secondResult = await second.value
        guard case .failure(let error) = firstResult,
              (error as? URLError)?.code == .cancelled,
              case .success(let accepted) = secondResult,
              accepted.value == "accepted",
              accepted.nonce == "B" else {
            preconditionFailure("callback fired inside cancel was not ignored")
        }
    }

    @MainActor
    private static func lateCallbackCannotCompleteReplacement() async {
        let coordinator = AuthorizationRequestCoordinator<String>()
        let firstController = NSObject()
        let secondController = NSObject()
        let first = Task { await coordinator.begin(controller: firstController, nonce: "A", timeoutNanoseconds: 1_000_000_000, cancelController: {}, perform: {}) }
        while coordinator.nonce(for: firstController) == nil { await Task.yield() }
        let second = Task { await coordinator.begin(controller: secondController, nonce: "B", timeoutNanoseconds: 1_000_000_000, cancelController: {}, perform: {}) }
        while coordinator.nonce(for: secondController) == nil { await Task.yield() }
        coordinator.complete(controller: firstController, with: .success("late-A"))
        coordinator.complete(controller: secondController, with: .success("B-result"))
        let firstResult = await first.value
        let secondResult = await second.value
        guard case .failure(let error) = firstResult,
              (error as? URLError)?.code == .cancelled,
              case .success(let accepted) = secondResult,
              accepted.value == "B-result",
              accepted.nonce == "B" else {
            preconditionFailure("late A callback completed replacement request")
        }
    }
}
