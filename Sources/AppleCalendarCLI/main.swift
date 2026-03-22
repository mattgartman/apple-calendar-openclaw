import EventKit
import Foundation

enum CLIError: LocalizedError {
    case usage(String)
    case message(String)

    var errorDescription: String? {
        switch self {
        case .usage(let message), .message(let message):
            return message
        }
    }
}

struct ParsedArguments {
    let command: String
    let options: [String: String?]
}

struct CalendarPayload: Encodable {
    let id: String
    let title: String
    let source: String
    let sourceType: String
    let allowsContentModifications: Bool
}

struct EventPayload: Encodable {
    let id: String
    let externalId: String?
    let title: String
    let calendar: String
    let calendarId: String
    let start: String
    let end: String
    let allDay: Bool
    let location: String?
    let notes: String?
    let url: String?
    let hasRecurrenceRules: Bool
    let timezone: String?
}

struct StatusPayload: Encodable {
    let status: String
}

struct CalendarsResponse: Encodable {
    let calendars: [CalendarPayload]
}

struct EventsResponse: Encodable {
    let events: [EventPayload]
}

struct EventResponse: Encodable {
    let event: EventPayload
}

struct DeleteResponse: Encodable {
    let status: String
    let event: EventPayload
}

enum JSON {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    static func write<T: Encodable>(_ value: T) throws {
        let data = try encoder.encode(value)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }
}

enum DateCodec {
    static let outputFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    static let inputFormatters: [DateFormatter] = {
        let formats = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd",
        ]
        return formats.map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = format
            return formatter
        }
    }()

    static func parse(_ value: String) -> Date? {
        let internet = ISO8601DateFormatter()
        internet.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = internet.date(from: value) {
            return date
        }

        let internetNoFraction = ISO8601DateFormatter()
        internetNoFraction.formatOptions = [.withInternetDateTime]
        if let date = internetNoFraction.date(from: value) {
            return date
        }

        for formatter in inputFormatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }

    static func string(_ date: Date?) -> String {
        guard let date else {
            return ""
        }
        return outputFormatter.string(from: date)
    }
}

enum SpanOption: String {
    case this
    case future

    var ekSpan: EKSpan {
        switch self {
        case .this:
            return .thisEvent
        case .future:
            return .futureEvents
        }
    }
}

struct ArgumentParser {
    static func parse() throws -> ParsedArguments {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard let command = arguments.first else {
            throw CLIError.usage(Self.helpText)
        }

        if command == "help" || command == "--help" || command == "-h" {
            throw CLIError.usage(Self.helpText)
        }

        var options: [String: String?] = [:]
        var index = 1

        while index < arguments.count {
            let token = arguments[index]
            guard token.hasPrefix("--") else {
                throw CLIError.usage("Unexpected argument: \(token)\n\n\(Self.helpText)")
            }

            let key = String(token.dropFirst(2))
            var value: String?
            if index + 1 < arguments.count, !arguments[index + 1].hasPrefix("--") {
                value = arguments[index + 1]
                index += 1
            }
            options[key] = value
            index += 1
        }

        return ParsedArguments(command: command, options: options)
    }

    static let helpText = """
    Usage:
      apple-calendar-cli authorize
      apple-calendar-cli list-calendars
      apple-calendar-cli list-events --start <date> --end <date> [--calendar <name-or-id>] [--query <text>] [--limit <n>]
      apple-calendar-cli get-event --id <event-id>
      apple-calendar-cli create-event --calendar <name-or-id> --title <text> --start <date> --end <date> [--location <text>] [--notes <text>] [--url <url>] [--all-day [true|false]]
      apple-calendar-cli update-event --id <event-id> [--calendar <name-or-id>] [--title <text>] [--start <date>] [--end <date>] [--location <text>] [--notes <text>] [--url <url>] [--all-day [true|false]] [--span this|future]
      apple-calendar-cli delete-event --id <event-id> [--span this|future]

    Date formats:
      ISO 8601 is preferred, for example 2026-03-22T15:00:00-04:00
      Local formats also work: "2026-03-22 15:00", "2026-03-22"
    """
}

struct Options {
    let values: [String: String?]

    func has(_ key: String) -> Bool {
        values.keys.contains(key)
    }

    func string(_ key: String) -> String? {
        values[key] ?? nil
    }

    func requiredString(_ key: String) throws -> String {
        guard let value = string(key), !value.isEmpty else {
            throw CLIError.usage("Missing required option --\(key)\n\n\(ArgumentParser.helpText)")
        }
        return value
    }

    func date(_ key: String) throws -> Date? {
        guard let raw = string(key) else {
            return nil
        }
        guard let date = DateCodec.parse(raw) else {
            throw CLIError.usage("Invalid date for --\(key): \(raw)")
        }
        return date
    }

    func requiredDate(_ key: String) throws -> Date {
        guard let date = try date(key) else {
            throw CLIError.usage("Missing required option --\(key)\n\n\(ArgumentParser.helpText)")
        }
        return date
    }

    func int(_ key: String) throws -> Int? {
        guard let raw = string(key) else {
            return nil
        }
        guard let value = Int(raw) else {
            throw CLIError.usage("Invalid integer for --\(key): \(raw)")
        }
        return value
    }

    func bool(_ key: String) throws -> Bool? {
        guard has(key) else {
            return nil
        }
        guard let raw = string(key) else {
            return true
        }

        switch raw.lowercased() {
        case "true", "yes", "1":
            return true
        case "false", "no", "0":
            return false
        default:
            throw CLIError.usage("Invalid boolean for --\(key): \(raw)")
        }
    }

    func span() throws -> EKSpan {
        guard let raw = string("span") else {
            return .thisEvent
        }
        guard let value = SpanOption(rawValue: raw.lowercased()) else {
            throw CLIError.usage("Invalid span: \(raw). Use this or future.")
        }
        return value.ekSpan
    }
}

final class CalendarCLI {
    private let store = EKEventStore()

    func run(_ parsed: ParsedArguments) async throws {
        switch parsed.command {
        case "authorize":
            try await ensureFullAccess()
            try JSON.write(StatusPayload(status: "authorized"))
        case "list-calendars":
            try await ensureFullAccess()
            try listCalendars()
        case "list-events":
            try await ensureFullAccess()
            try listEvents(Options(values: parsed.options))
        case "get-event":
            try await ensureFullAccess()
            try getEvent(Options(values: parsed.options))
        case "create-event":
            try await ensureFullAccess()
            try createEvent(Options(values: parsed.options))
        case "update-event":
            try await ensureFullAccess()
            try updateEvent(Options(values: parsed.options))
        case "delete-event":
            try await ensureFullAccess()
            try deleteEvent(Options(values: parsed.options))
        default:
            throw CLIError.usage("Unknown command: \(parsed.command)\n\n\(ArgumentParser.helpText)")
        }
    }

    private func ensureFullAccess() async throws {
        let currentStatus = EKEventStore.authorizationStatus(for: .event)
        if statusAllowsFullAccess(currentStatus) {
            return
        }

        let granted: Bool
        if #available(macOS 14.0, *) {
            granted = try await store.requestFullAccessToEvents()
        } else {
            granted = try await withCheckedThrowingContinuation { continuation in
                store.requestAccess(to: .event) { accessGranted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: accessGranted)
                    }
                }
            }
        }

        if granted, statusAllowsFullAccess(EKEventStore.authorizationStatus(for: .event)) {
            return
        }

        throw CLIError.message("Calendar access was not granted. Allow full Calendar access for the invoking app in System Settings.")
    }

    private func statusAllowsFullAccess(_ status: EKAuthorizationStatus) -> Bool {
        if #available(macOS 14.0, *) {
            return status == .fullAccess
        }
        switch status {
        case .denied, .restricted, .notDetermined:
            return false
        default:
            return true
        }
    }

    private func listCalendars() throws {
        let calendars = store.calendars(for: .event)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            .map { calendar in
                CalendarPayload(
                    id: calendar.calendarIdentifier,
                    title: calendar.title,
                    source: calendar.source.title,
                    sourceType: sourceTypeName(calendar.source.sourceType),
                    allowsContentModifications: calendar.allowsContentModifications
                )
            }

        try JSON.write(CalendarsResponse(calendars: calendars))
    }

    private func listEvents(_ options: Options) throws {
        let start = try options.requiredDate("start")
        let end = try options.requiredDate("end")
        guard end >= start else {
            throw CLIError.usage("--end must be greater than or equal to --start")
        }

        let calendars = try resolvedCalendars(matching: options.string("calendar"))
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let query = options.string("query")?.lowercased()
        let limit = try options.int("limit")

        var events = store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .filter { event in
                guard let query else {
                    return true
                }
                return [event.title, event.location, event.notes]
                    .compactMap { $0?.lowercased() }
                    .contains { $0.contains(query) }
            }

        if let limit, limit >= 0 {
            events = Array(events.prefix(limit))
        }

        try JSON.write(EventsResponse(events: events.map(eventPayload)))
    }

    private func getEvent(_ options: Options) throws {
        let event = try resolvedEvent(id: options.requiredString("id"))
        try JSON.write(EventResponse(event: eventPayload(event)))
    }

    private func createEvent(_ options: Options) throws {
        let calendar = try resolvedCalendar(matching: options.requiredString("calendar"))
        let title = try options.requiredString("title")
        let start = try options.requiredDate("start")
        let end = try options.requiredDate("end")
        guard end >= start else {
            throw CLIError.usage("--end must be greater than or equal to --start")
        }

        let event = EKEvent(eventStore: store)
        event.calendar = calendar
        event.title = title
        event.startDate = start
        event.endDate = end
        event.isAllDay = try options.bool("all-day") ?? false
        event.location = normalizedOptionalText(options.string("location"))
        event.notes = normalizedOptionalText(options.string("notes"))

        if let rawURL = normalizedOptionalText(options.string("url")) {
            guard let url = URL(string: rawURL) else {
                throw CLIError.usage("Invalid URL: \(rawURL)")
            }
            event.url = url
        }

        try store.save(event, span: .thisEvent, commit: true)
        try JSON.write(EventResponse(event: eventPayload(event)))
    }

    private func updateEvent(_ options: Options) throws {
        let event = try resolvedEvent(id: options.requiredString("id"))

        if options.has("calendar") {
            event.calendar = try resolvedCalendar(matching: options.requiredString("calendar"))
        }
        if options.has("title") {
            event.title = try options.requiredString("title")
        }
        if options.has("start") {
            event.startDate = try options.requiredDate("start")
        }
        if options.has("end") {
            event.endDate = try options.requiredDate("end")
        }
        if options.has("all-day") {
            event.isAllDay = try options.bool("all-day") ?? true
        }
        if options.has("location") {
            event.location = normalizedOptionalText(options.string("location"))
        }
        if options.has("notes") {
            event.notes = normalizedOptionalText(options.string("notes"))
        }
        if options.has("url") {
            if let rawURL = normalizedOptionalText(options.string("url")) {
                guard let url = URL(string: rawURL) else {
                    throw CLIError.usage("Invalid URL: \(rawURL)")
                }
                event.url = url
            } else {
                event.url = nil
            }
        }

        guard event.endDate >= event.startDate else {
            throw CLIError.usage("Event end date must be greater than or equal to the start date")
        }

        try store.save(event, span: try options.span(), commit: true)
        try JSON.write(EventResponse(event: eventPayload(event)))
    }

    private func deleteEvent(_ options: Options) throws {
        let event = try resolvedEvent(id: options.requiredString("id"))
        let payload = eventPayload(event)
        try store.remove(event, span: try options.span(), commit: true)
        try JSON.write(DeleteResponse(status: "deleted", event: payload))
    }

    private func resolvedCalendars(matching query: String?) throws -> [EKCalendar]? {
        guard let query = normalizedOptionalText(query) else {
            return nil
        }
        return [try resolvedCalendar(matching: query)]
    }

    private func resolvedCalendar(matching query: String) throws -> EKCalendar {
        let calendars = store.calendars(for: .event)

        if let exactIdentifierMatch = calendars.first(where: { $0.calendarIdentifier == query }) {
            return exactIdentifierMatch
        }

        let exactTitleMatches = calendars.filter { $0.title.caseInsensitiveCompare(query) == .orderedSame }
        if exactTitleMatches.count == 1, let match = exactTitleMatches.first {
            return match
        }
        if exactTitleMatches.count > 1 {
            throw CLIError.message("Multiple calendars match title '\(query)'. Use a calendar identifier instead.")
        }

        let containsMatches = calendars.filter { $0.title.localizedCaseInsensitiveContains(query) }
        if containsMatches.count == 1, let match = containsMatches.first {
            return match
        }
        if containsMatches.count > 1 {
            let names = containsMatches.map(\.title).sorted().joined(separator: ", ")
            throw CLIError.message("Calendar '\(query)' is ambiguous. Matches: \(names)")
        }

        throw CLIError.message("No calendar found for '\(query)'")
    }

    private func resolvedEvent(id: String) throws -> EKEvent {
        guard let item = store.calendarItem(withIdentifier: id) as? EKEvent else {
            throw CLIError.message("No event found for id '\(id)'")
        }
        return item
    }

    private func eventPayload(_ event: EKEvent) -> EventPayload {
        EventPayload(
            id: event.calendarItemIdentifier,
            externalId: event.calendarItemExternalIdentifier,
            title: event.title ?? "",
            calendar: event.calendar.title,
            calendarId: event.calendar.calendarIdentifier,
            start: DateCodec.string(event.startDate),
            end: DateCodec.string(event.endDate),
            allDay: event.isAllDay,
            location: event.location,
            notes: event.notes,
            url: event.url?.absoluteString,
            hasRecurrenceRules: !(event.recurrenceRules ?? []).isEmpty,
            timezone: event.timeZone?.identifier
        )
    }

    private func normalizedOptionalText(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nil
        }
        return value
    }

    private func sourceTypeName(_ sourceType: EKSourceType) -> String {
        switch sourceType {
        case .local:
            return "local"
        case .exchange:
            return "exchange"
        case .calDAV:
            return "caldav"
        case .mobileMe:
            return "icloud"
        case .subscribed:
            return "subscribed"
        case .birthdays:
            return "birthdays"
        @unknown default:
            return "unknown"
        }
    }
}

@main
struct Main {
    static func main() async {
        do {
            let parsed = try ArgumentParser.parse()
            let cli = CalendarCLI()
            try await cli.run(parsed)
        } catch let error as CLIError {
            let message = error.errorDescription ?? "Unknown error"
            FileHandle.standardError.write(Data("\(message)\n".utf8))
            exit(1)
        } catch {
            FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
}
