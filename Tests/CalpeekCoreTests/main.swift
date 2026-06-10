import CalpeekCore

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
    if actual != expected {
        fatalError("\(message): expected \(expected), got \(actual)")
    }
}

func expectNil<T>(_ actual: T?, _ message: String) {
    if actual != nil {
        fatalError("\(message): expected nil, got \(String(describing: actual))")
    }
}

expectEqual(
    calendarReadinessIssue(authorizationStatus: .fullAccess, calendarCount: 0),
    .noReadableCalendars,
    "full access with no calendars should report unreadable store"
)

expectNil(
    calendarReadinessIssue(authorizationStatus: .fullAccess, calendarCount: 1),
    "full access with calendars should be ready"
)

expectEqual(
    calendarReadinessIssue(authorizationStatus: .denied, calendarCount: 0),
    .denied,
    "denied access should report denied"
)

print("CalpeekCoreTests passed")
