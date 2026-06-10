import EventKit
import Foundation

// MARK: - 引数

struct Options {
    var calendarNames: [String] = []
    var thresholdMinutes = 30
    var debug = false
}

func writeStderr(_ text: String) {
    FileHandle.standardError.write(Data(text.utf8))
}

var debugEnabled = false

func debugLog(_ message: @autoclosure () -> String) {
    if debugEnabled { writeStderr("[calpeek debug] \(message())\n") }
}

func fail(_ message: String) -> Never {
    writeStderr("calpeek: \(message)\n")
    exit(1)
}

func parseOptions() -> Options {
    var options = Options()
    var args = CommandLine.arguments.dropFirst()
    while let arg = args.popFirst() {
        switch arg {
        case "--calendars":
            guard let value = args.popFirst() else { fail("--calendars には値が必要です") }
            options.calendarNames = value.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespaces)
            }
        case "--threshold":
            guard let value = args.popFirst(), let minutes = Int(value), minutes >= 0 else {
                fail("--threshold には 0 以上の分数を指定してください")
            }
            options.thresholdMinutes = minutes
        case "--debug":
            options.debug = true
        case "--help", "-h":
            print("usage: calpeek [--calendars <名前,...>] [--threshold <分>] [--debug]")
            exit(0)
        default:
            fail("不明な引数: \(arg)")
        }
    }
    return options
}

// MARK: - カレンダー権限

func ensureCalendarAccess(_ store: EKEventStore) -> Bool {
    let status = EKEventStore.authorizationStatus(for: .event)
    debugLog("authorizationStatus rawValue = \(status.rawValue) (0=未確定 1=制限 2=拒否 3=フルアクセス 4=書込のみ)")
    switch status {
    case .fullAccess:
        return false
    case .notDetermined:
        let semaphore = DispatchSemaphore(value: 0)
        var granted = false
        store.requestFullAccessToEvents { ok, error in
            granted = ok
            if let error { debugLog("requestFullAccessToEvents error: \(error)") }
            semaphore.signal()
        }
        // GUI を出せない文脈では許可ダイアログが表示されず永久に待つことがある。
        // ステータスバーホスト(a-bar 等)は 10 秒程度でプロセスを SIGTERM するため、
        // それより手前で打ち切って権限なし扱いの警告を出す
        if semaphore.wait(timeout: .now() + 8) == .timedOut {
            debugLog("requestFullAccessToEvents timed out (8s)")
            exitForDeniedAccess()
        }
        debugLog("requestFullAccessToEvents granted = \(granted)")
        if !granted { exitForDeniedAccess() }
        return true
    default:
        exitForDeniedAccess()
    }
}

func exitForDeniedAccess() -> Never {
    // ステータスバー上で異常に気づけるよう、警告は stdout に出す
    print("⚠ calpeek: カレンダー権限なし")
    writeStderr(
        """
        カレンダーへのフルアクセスが許可されていません。
        システム設定 > プライバシーとセキュリティ > カレンダー で、
        calpeek の起動元アプリ(ターミナル等)に「フルアクセス」を許可してください。
        初回はターミナルから calpeek を直接実行すると許可ダイアログが表示されます。

        設定上は許可済みなのに失敗する場合、起動元アプリの更新で許可が
        失効している可能性があります(ad-hoc 署名アプリはビルドごとに失効する)。
        次のコマンドで許可をリセットすると、再度ダイアログが表示されます:
          tccutil reset Calendar <起動元アプリの bundle ID>

        """
    )
    exit(1)
}

// MARK: - イベント選択

/// 自分が辞退済みのイベントか
func isDeclined(_ event: EKEvent) -> Bool {
    guard let me = event.attendees?.first(where: { $0.isCurrentUser }) else { return false }
    return me.participantStatus == .declined
}

/// now の選択規則: 最も遅く始まったもの。同時開始なら終了が早いもの
func pickCurrent(from events: [EKEvent], at now: Date) -> EKEvent? {
    events
        .filter { $0.startDate <= now && now < $0.endDate }
        .min { a, b in
            if a.startDate != b.startDate { return a.startDate > b.startDate }
            return a.endDate < b.endDate
        }
}

/// next の選択規則: 現在時刻より後に始まる最も早いもの。同時開始なら終了が早いもの
func pickUpcoming(from events: [EKEvent], at now: Date) -> EKEvent? {
    events
        .filter { $0.startDate > now }
        .min { a, b in
            if a.startDate != b.startDate { return a.startDate < b.startDate }
            return a.endDate < b.endDate
        }
}

// MARK: - 表示

let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter
}()

/// 残り時間の表記: 60分未満は "25m"、以上は "1h05m"
func remainingText(until date: Date, from now: Date) -> String {
    let minutes = max(1, Int((date.timeIntervalSince(now) / 60).rounded(.up)))
    if minutes < 60 { return "\(minutes)m" }
    return String(format: "%dh%02dm", minutes / 60, minutes % 60)
}

func title(of event: EKEvent) -> String {
    event.title ?? "(無題)"
}

// MARK: - main

let options = parseOptions()
debugEnabled = options.debug
debugLog("executable = \(CommandLine.arguments[0]), pid = \(getpid()), ppid = \(getppid())")
debugLog("options: calendars = \(options.calendarNames), threshold = \(options.thresholdMinutes)m")

var store = EKEventStore()
let requestedAccess = ensureCalendarAccess(store)
if requestedAccess {
    store = EKEventStore()
    debugLog("EKEventStore を権限許可後に作り直しました")
}
debugLog("利用可能なカレンダー: \(store.calendars(for: .event).map(\.title))")

let now = Date()
let startOfDay = Calendar.current.startOfDay(for: now)
guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else {
    fail("日付の計算に失敗しました")
}

var targetCalendars: [EKCalendar]? = nil
if !options.calendarNames.isEmpty {
    let matched = store.calendars(for: .event).filter { options.calendarNames.contains($0.title) }
    if matched.isEmpty {
        fail("指定されたカレンダーが見つかりません: \(options.calendarNames.joined(separator: ", "))")
    }
    targetCalendars = matched
}

// [現在時刻, 当日末] に重なるイベント = 進行中 + 当日のこれから
let predicate = store.predicateForEvents(withStart: now, end: endOfDay, calendars: targetCalendars)
let fetched = store.events(matching: predicate)
let candidates = fetched.filter { !$0.isAllDay && !isDeclined($0) }
debugLog("探索窓 = \(now) 〜 \(endOfDay)")
debugLog("取得 \(fetched.count) 件 → 判定対象 \(candidates.count) 件(終日・辞退を除外)")
for event in candidates {
    debugLog("  候補: \(title(of: event)) \(event.startDate!) 〜 \(event.endDate!)")
}

let current = pickCurrent(from: candidates, at: now)
let upcoming = pickUpcoming(from: candidates, at: now)
debugLog("now = \(current.map(title(of:)) ?? "なし"), next = \(upcoming.map(title(of:)) ?? "なし")")

var parts: [String] = []

if let current {
    let end = timeFormatter.string(from: current.endDate)
    parts.append("▶ \(title(of: current)) 〜\(end) (残\(remainingText(until: current.endDate, from: now)))")
}

if let upcoming {
    let secondsToStart = upcoming.startDate.timeIntervalSince(now)
    let withinThreshold = secondsToStart <= Double(options.thresholdMinutes) * 60
    // next を出すのは「now がない」か「30分ルール発動」のときだけ
    if current == nil || withinThreshold {
        let start = timeFormatter.string(from: upcoming.startDate)
        parts.append("\(start) \(title(of: upcoming)) (in \(remainingText(until: upcoming.startDate, from: now)))")
    }
}

if !parts.isEmpty {
    print(parts.joined(separator: " → "))
} else {
    print("予定がありません")
}
