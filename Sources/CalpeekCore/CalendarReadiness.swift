public enum CalendarAuthorizationStatus: Equatable {
    case notDetermined
    case restricted
    case denied
    case fullAccess
    case writeOnly
    case unknown(Int)
}

public enum CalendarReadinessIssue: Equatable {
    case notDetermined
    case restricted
    case denied
    case writeOnly
    case noReadableCalendars
    case unknownAuthorizationStatus(Int)
}

public func calendarReadinessIssue(
    authorizationStatus: CalendarAuthorizationStatus,
    calendarCount: Int
) -> CalendarReadinessIssue? {
    switch authorizationStatus {
    case .fullAccess:
        return calendarCount == 0 ? .noReadableCalendars : nil
    case .notDetermined:
        return .notDetermined
    case .restricted:
        return .restricted
    case .denied:
        return .denied
    case .writeOnly:
        return .writeOnly
    case let .unknown(rawValue):
        return .unknownAuthorizationStatus(rawValue)
    }
}
