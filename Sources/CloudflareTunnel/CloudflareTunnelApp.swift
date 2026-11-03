import AppKit
import SwiftUI

@main
struct CloudflareTunnelApp: App {
    @StateObject private var model = TunnelModel()
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        Window("Cloudflare Tunnel", id: "main") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 760, minHeight: 560)
        }

        MenuBarExtra {
            MenuBarContent().environmentObject(model)
        } label: {
            Image(systemName: model.runningCount > 0 ? "cloud.fill" : "cloud")
        }
    }
}

/// `swift run` starts a plain executable; make it a regular app with a Dock icon and focus.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

struct MenuBarContent: View {
    @EnvironmentObject private var model: TunnelModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ForEach(model.items) { item in
            MenuBarRow(item: item)
        }
        Divider()
        Button("Start All") { model.startAll() }
        Button("Stop All") { model.stopAll() }
        Divider()
        Button("Open Window") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button("Quit") { NSApp.terminate(nil) }
    }
}

private struct MenuBarRow: View {
    @EnvironmentObject private var model: TunnelModel
    @ObservedObject var item: TunnelItem

    var body: some View {
        Menu("\(item.title) (\(item.entry.port))  \(item.status.url ?? (item.isStopped ? "stopped" : "starting…"))") {
            Button(item.isStopped ? "Start" : "Stop") { item.isStopped ? model.start(item) : model.stop(item) }
            if let url = item.status.url { Button("Copy URL") { model.copy(url) } }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var model: TunnelModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ports").font(.headline)
                Spacer()
                Button("Start All") { model.startAll() }.disabled(!model.hasCloudflared)
                Button("Stop All") { model.stopAll() }
                Button {
                    model.add()
                } label: {
                    Label("Add Port", systemImage: "plus")
                }
            }
            if !model.hasCloudflared {
                Label("cloudflared not found. Install it: brew install cloudflared, then reopen the app.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(model.items) { item in
                        TunnelRow(item: item)
                    }
                }
            }
            .frame(minHeight: 200)
            loginBox
            Text("Quick: random https://….trycloudflare.com, no account, changes every start. Custom domain: fixed https://<domain> on a zone of your Cloudflare account (Login once). WebSocket works on both; use wss://<host> where the client used ws://localhost:<port>.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            logBox
        }
        .padding(16)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in model.refresh() }
    }

    private var loginBox: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Cloudflare").font(.headline).frame(width: 90, alignment: .leading)
                    if model.isCloudflareLoggedIn {
                        Label("Logged in (~/.cloudflared/cert.pem), custom domains available", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Text("Not logged in, needed only for Custom domain").foregroundStyle(.secondary)
                    }
                    Spacer()
                    if model.isLoggingIn {
                        ProgressView().controlSize(.small)
                        Button("Open Page") { model.openLoginPage() }.disabled(model.loginURL == nil)
                        Button("Cancel") { model.cancelLogin() }
                    } else {
                        Button("Login…") { model.loginCloudflare() }
                            .disabled(model.isCloudflareLoggedIn || !model.hasCloudflared)
                    }
                }
                if model.isLoggingIn, let url = model.loginURL {
                    HStack {
                        Text("Login link").frame(width: 90, alignment: .leading)
                        Text(url.absoluteString).font(.caption.monospaced())
                            .lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                            .help(url.absoluteString)
                        Spacer()
                        Button("Copy") { model.copy(url.absoluteString) }
                    }
                }
                if model.isLoggingIn {
                    Text("Signing in is not enough: on the “Authorize Cloudflare Tunnel” page pick the zone of your domain (e.g. example.com for nakama.example.com) and click Authorize.")
                        .font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                }
                if let error = model.loginError {
                    Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
                }
            }
            .padding(4)
        }
    }

    private var logBox: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Log").font(.headline)
                Spacer()
                Button("Clear") { model.clearLog() }
            }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(model.log.enumerated()), id: \.offset) { index, line in
                            Text(line).font(.caption.monospaced()).textSelection(.enabled).id(index)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
                }
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onChange(of: model.log.count) { _, count in
                    if count > 0 { proxy.scrollTo(count - 1, anchor: .bottom) }
                }
            }
        }
        .frame(minHeight: 120, maxHeight: .infinity)
    }
}

struct TunnelRow: View {
    @EnvironmentObject private var model: TunnelModel
    @ObservedObject var item: TunnelItem

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: statusIcon).foregroundStyle(statusColor)
                    TextField("Name", text: $item.entry.label, prompt: Text("Port \(item.entry.port)"))
                        .frame(width: 150)
                    Text("Port")
                    TextField("7350", value: $item.entry.port, format: .number.grouping(.never)).frame(width: 64)
                        .disabled(!item.isStopped)
                    portBadge
                    Toggle("HTTPS origin", isOn: $item.entry.originTLS)
                        .help("Turn on when the local server itself speaks https (certificate is not verified).")
                        .disabled(!item.isStopped)
                    Picker("", selection: $item.entry.mode) {
                        Text("Quick").tag(CloudflareTunnel.Mode.quick)
                        Text("Custom domain").tag(CloudflareTunnel.Mode.domain)
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 190)
                    .disabled(!item.isStopped)
                    Spacer()
                    if item.status == .starting { ProgressView().controlSize(.small) }
                    if item.isStopped {
                        Button("Start") { model.start(item) }.disabled(!model.hasCloudflared)
                    } else {
                        Button("Stop") { model.stop(item) }
                    }
                    Button {
                        model.remove(item)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("Remove")
                }
                if item.entry.mode == .domain {
                    HStack {
                        Text("Domain").frame(width: 60, alignment: .leading)
                        TextField("nakama.example.com", text: $item.entry.hostname).frame(width: 240)
                        Text("Tunnel")
                        TextField("name", text: $item.entry.tunnelName).frame(width: 180)
                        Spacer()
                    }
                    .disabled(!item.isStopped)
                }
                if let url = item.status.url {
                    HStack {
                        Text("Public URL").frame(width: 70, alignment: .leading)
                        Text(url).font(.body.monospaced()).textSelection(.enabled)
                        Text("→ localhost:\(item.entry.port)").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Copy") { model.copy(url) }
                        Button("Open") { if let link = URL(string: url) { NSWorkspace.shared.open(link) } }
                    }
                }
                if let error = item.error {
                    Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
                }
            }
            .padding(4)
        }
    }

    @ViewBuilder private var portBadge: some View {
        switch item.isPortOpen {
        case true?:
            Text("listening").font(.caption).foregroundStyle(.green)
                .help("Something accepts connections on localhost:\(item.entry.port).")
        case false?:
            Text("not listening").font(.caption).foregroundStyle(.orange)
                .help("Nothing on localhost:\(item.entry.port) yet. The tunnel still starts; requests fail until the server runs.")
        case nil:
            EmptyView()
        }
    }

    private var statusIcon: String {
        switch item.status {
        case .stopped: "circle"
        case .starting: "circle.dotted"
        case .running: "circle.fill"
        }
    }

    private var statusColor: Color {
        switch item.status {
        case .stopped: .secondary
        case .starting: .orange
        case .running: .green
        }
    }
}
