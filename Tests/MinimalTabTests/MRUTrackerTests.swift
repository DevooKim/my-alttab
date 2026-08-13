import CoreGraphics
import MinimalTabCore

func runMRUTrackerTests() {
    var source: [CGWindowID] = [42, 7, 99]
    let snapshot = MRURankSnapshot(windowIDs: source)

    expectEqual(snapshot.rank(of: 42), 0, "first MRU window has rank zero")
    expectEqual(snapshot.rank(of: 7), 1, "second MRU window has rank one")
    expectEqual(snapshot.rank(of: 99), 2, "third MRU window has rank two")
    expect(snapshot.rank(of: 0) == nil, "zero window ID is never ranked")
    expect(snapshot.rank(of: 123) == nil, "unknown window ID is not ranked")

    source.insert(123, at: 0)
    expectEqual(snapshot.rank(of: 42), 0, "snapshot is immutable after source changes")
    expect(snapshot.rank(of: 123) == nil, "snapshot does not observe later source changes")

    let withDuplicate = MRURankSnapshot(windowIDs: [42, 7, 42])
    expectEqual(withDuplicate.rank(of: 42), 0, "duplicate IDs keep their earliest MRU rank")
}
