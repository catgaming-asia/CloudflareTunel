import AppKit
import Foundation

enum TunnelStatus: Equatable {
    case stopped, starting, running(String)

    var url: String? {
        if case .running(let url) = self { return url }
        return nil
    }
}

/// One local port to publish. Saved in UserDefaults; status lives in `TunnelItem`.
struct TunnelEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var label = ""
    var port = 8080
    var originTLS = false
    var mode: CloudflareTunnel.Mode = .quick
    var hostname = ""
    var tunnelName = ""
}

extension CloudflareTunnel.Mode: Codable {}

@MainActor
final class TunnelItem: ObservableObject, Identifiable {
    @Published var entry: TunnelEntry { didSet { onChange() } }
    @Published fileprivate(set) var status: TunnelStatus = .stopped
    @Published fileprivate(set) var error: String?
    /// Something accepts connections on 127.0.0.1:<port>; nil = not checked yet.
    @Published fileprivate(set) var isPortOpen: Bool?

    nonisolated let id: UUID
    fileprivate var tunnel: CloudflareTunnel?
    fileprivate let onChange: () -> Void

    fileprivate init(entry: TunnelEntry, onChange: @escaping () -> Void) {
        self.id = entry.id
        self.entry = entry
        self.onChange = onChange
    }

    var title: String { entry.label.isEmpty ? "Port \(entry.port)" : entry.label }
    var isStopped: Bool { status == .stopped }
}

@MainActor
final class TunnelModel: ObservableObject {
    @Published private(set) var items: [TunnelItem] = []
    @Published private(set) var log: [String] = []
    @Published private(set) var isLoggingIn = false
    /// The Authorize page cloudflared opened, to open again if the browser tab got lost.
    @Published private(set) var loginURL: URL?
    @Published private(set) var loginError: String?
    @Published private(set) var isCloudflareLoggedIn = CloudflareTunnel.isLoggedIn
    let hasCloudflared = CloudflareTunnel.executable() != nil

    private let defaults = UserDefaults.standard
    private var loginProcess: Process?
    private var portTimer: Timer?
    private static let timeFormat: DateFormatter = {
        let format = DateFormatter()
        format.dateFormat = "HH:mm:ss"
        return format
    }()

    var runningCount: Int { items.filter { $0.status.url != nil }.count }

    init() {
        let saved = defaults.data(forKey: "entries").flatMap { try? JSONDecoder().decode([TunnelEntry].self, from: $0) }
        // First launch: the two Nakama ports.
        let entries = saved ?? [TunnelEntry(label: "Nakama API", port: 7350, tunnelName: "nakama-api"),
                                TunnelEntry(label: "Nakama Console", port: 7351, tunnelName: "nakama-console")]
        items = entries.map(makeItem)
        checkPorts()
        portTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkPorts() }
        }
        // Do not leave cloudflared running after the app quits.
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.items.forEach { $0.tunnel?.stop() }
                self?.loginProcess?.terminate()
            }
        }
    }

    private func makeItem(_ entry: TunnelEntry) -> TunnelItem {
        TunnelItem(entry: entry) { [weak self] in self?.save() }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items.map(\.entry)) { defaults.set(data, forKey: "entries") }
    }

    // MARK: - List

    func add() {
        let port = (items.map(\.entry.port).max() ?? 8079) + 1
        items.append(makeItem(TunnelEntry(port: port, tunnelName: "port-\(port)")))
        save()
        checkPorts()
    }

    func remove(_ item: TunnelItem) {
        item.tunnel?.stop()
        items.removeAll { $0.id == item.id }
        save()
    }

    // MARK: - Tunnels

    func start(_ item: TunnelItem) {
        guard item.tunnel == nil else { return }
        let entry = item.entry
        guard (1...65535).contains(entry.port) else { item.error = "Port must be 1–65535."; return }
        if let other = items.first(where: { $0.id != item.id && !$0.isStopped && $0.entry.mode == .domain && entry.mode == .domain
                                            && $0.entry.tunnelName == entry.tunnelName }) {
            item.error = "Tunnel name '\(entry.tunnelName)' is already used by \(other.title). Each domain needs its own tunnel name."
            return
        }
        let config = CloudflareTunnel.Config(mode: entry.mode, port: entry.port, originTLS: entry.originTLS,
                                             tunnelName: entry.tunnelName.trimmingCharacters(in: .whitespaces),
                                             hostname: entry.hostname.trimmingCharacters(in: .whitespaces).lowercased())
        let tunnel = CloudflareTunnel { [weak self, weak item] event in
            Task { @MainActor in
                guard let self, let item else { return }
                self.handle(event, for: item)
            }
        }
        item.tunnel = tunnel
        item.status = .starting
        item.error = nil
        if item.isPortOpen == false { appendLine("\(item.title): nothing is listening on port \(entry.port) yet") }
        tunnel.start(config)
    }

    func stop(_ item: TunnelItem) {
        item.tunnel?.stop()
    }

    func startAll() { items.filter(\.isStopped).forEach(start) }
    func stopAll() { items.forEach(stop) }

    private func handle(_ event: CloudflareTunnel.Event, for item: TunnelItem) {
        switch event {
        case .log(let line):
            appendLine("\(item.title): \(line)")
        case .ready(let url):
            item.status = .running(url)
            appendLine("\(item.title): up  \(url) → localhost:\(item.entry.port)")
        case .exited(let failure):
            item.tunnel = nil
            item.status = .stopped
            item.error = failure
            appendLine("\(item.title): " + (failure.map { "stopped: \($0)" } ?? "stopped"))
        }
    }

    // MARK: - Cloudflare login

    func loginCloudflare() {
        guard !isLoggingIn else { return }
        isLoggingIn = true
        loginURL = nil
        loginError = nil
        appendLine("cloudflared tunnel login — in the browser pick the domain's zone, then click Authorize")
        loginProcess = CloudflareTunnel.login(onLog: { [weak self] line in
            Task { @MainActor in self?.appendLine("login: \(line)") }
        }, onURL: { [weak self] url in
            Task { @MainActor in self?.loginURL = url }
        }, completion: { [weak self] failure in
            Task { @MainActor in
                guard let self else { return }
                self.loginProcess = nil
                self.isLoggingIn = false
                self.loginURL = nil
                self.loginError = failure
                self.isCloudflareLoggedIn = CloudflareTunnel.isLoggedIn
                self.appendLine(self.isCloudflareLoggedIn ? "Logged in, ~/.cloudflared/cert.pem saved" : "Login not finished")
            }
        })
    }

    func cancelLogin() {
        loginProcess?.terminate()
    }

    func openLoginPage() {
        if let loginURL { NSWorkspace.shared.open(loginURL) }
    }

    // MARK: - Helpers

    func refresh() {
        isCloudflareLoggedIn = CloudflareTunnel.isLoggedIn
        checkPorts()
    }

    func clearLog() { log.removeAll() }

    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func appendLine(_ text: String) {
        log.append("\(Self.timeFormat.string(from: Date())) \(text)")
        if log.count > 500 { log.removeFirst(log.count - 500) }
    }

    private func checkPorts() {
        let ports = Set(items.map(\.entry.port))
        Task.detached {
            let open = Dictionary(uniqueKeysWithValues: ports.map { ($0, Self.isListening($0)) })
            await MainActor.run { [weak self] in
                self?.items.forEach { if let value = open[$0.entry.port], $0.isPortOpen != value { $0.isPortOpen = value } }
            }
        }
    }

    /// Non-blocking connect to 127.0.0.1:<port> with a short timeout.
    nonisolated private static func isListening(_ port: Int) -> Bool {
        guard let port = UInt16(exactly: port), port > 0 else { return false }
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK)
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        if result == 0 { return true }
        guard errno == EINPROGRESS else { return false }
        var poller = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
        guard poll(&poller, 1, 300) == 1 else { return false }
        var error: Int32 = 0
        var length = socklen_t(MemoryLayout<Int32>.size)
        getsockopt(fd, SOL_SOCKET, SO_ERROR, &error, &length)
        return error == 0
    }
}
