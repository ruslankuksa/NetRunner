import Testing
@testable import NetRunner

@Suite(.timeLimit(.minutes(1)), .tags(.connectivity))
struct ConnectivityStateStoreTests {
    @Test func beginsWithoutCurrentStateOrUpdate() {
        let store = ConnectivityStateStore()

        #expect(store.currentState == nil)
        #expect(store.currentUpdate == nil)
    }

    @Test func firstEvaluatedCallbackUsesSequenceOne() async {
        let store = ConnectivityStateStore()
        var iterator = store.updateStream().makeAsyncIterator()

        store.update(.connected)

        let update = await iterator.next()
        #expect(update == ConnectivityStateUpdate(sequence: 1, state: .connected))
        #expect(store.currentUpdate == update)
    }

    @Test func duplicateStatesProduceUpdatesButOneLegacyState() async {
        let store = ConnectivityStateStore()
        var updateIterator = store.updateStream().makeAsyncIterator()
        var stateIterator = store.stream().makeAsyncIterator()

        store.update(.connected)
        let firstState = await stateIterator.next()
        store.update(.connected)
        store.finish()

        let firstUpdate = await updateIterator.next()
        let secondUpdate = await updateIterator.next()
        let secondState = await stateIterator.next()

        #expect(firstUpdate == ConnectivityStateUpdate(sequence: 1, state: .connected))
        #expect(secondUpdate == ConnectivityStateUpdate(sequence: 2, state: .connected))
        #expect(firstState == .connected)
        #expect(secondState == nil)
    }

    @Test func orderedUpdatesDoNotDropIntermediateCallbacks() async {
        let store = ConnectivityStateStore()
        var iterator = store.updateStream().makeAsyncIterator()

        store.update(.disconnected)
        store.update(.connected)
        store.update(.connected)

        let updates = [
            await iterator.next(),
            await iterator.next(),
            await iterator.next(),
        ]

        #expect(updates == [
            ConnectivityStateUpdate(sequence: 1, state: .disconnected),
            ConnectivityStateUpdate(sequence: 2, state: .connected),
            ConnectivityStateUpdate(sequence: 3, state: .connected),
        ])
    }

    @Test func newUpdateSubscriberReplaysOnlyLatestUpdate() async {
        let store = ConnectivityStateStore()
        store.update(.disconnected)
        store.update(.connected)
        store.update(.connected)

        var iterator = store.updateStream().makeAsyncIterator()
        store.update(.disconnected)

        let replayedUpdate = await iterator.next()
        let nextUpdate = await iterator.next()

        #expect(replayedUpdate == ConnectivityStateUpdate(sequence: 3, state: .connected))
        #expect(nextUpdate == ConnectivityStateUpdate(sequence: 4, state: .disconnected))
    }

    @Test func finishEndsBothStreams() async {
        let store = ConnectivityStateStore()
        var stateIterator = store.stream().makeAsyncIterator()
        var updateIterator = store.updateStream().makeAsyncIterator()

        store.finish()
        store.finish()

        #expect(await stateIterator.next() == nil)
        #expect(await updateIterator.next() == nil)
    }
}
