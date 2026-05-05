import AppKit
import SwiftTerm
import SwiftUI

struct TerminalShell: Identifiable, Equatable {
    let path: String

    var id: String {
        path
    }

    var title: String {
        URL(fileURLWithPath: path).lastPathComponent.uppercased()
    }

    static func availableShells() -> [TerminalShell] {
        let fallback = ["/bin/zsh", "/bin/bash", "/bin/sh"]
        let content = try? String(contentsOfFile: "/etc/shells", encoding: .utf8)

        let rawPaths = content?
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }

        let candidates = (rawPaths?.isEmpty == false ? rawPaths! : fallback).filter {
            FileManager.default.isExecutableFile(atPath: $0)
        }

        let unique = Array(Set(candidates)).sorted()
        if unique.isEmpty {
            return fallback.map(TerminalShell.init(path:))
        }

        return unique.map(TerminalShell.init(path:))
    }

    static func defaultShell(in shells: [TerminalShell]) -> TerminalShell {
        let envShell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        return shells.first(where: { $0.path == envShell }) ?? shells.first ?? TerminalShell(path: "/bin/zsh")
    }
}

final class TerminalContainerView: NSView, LocalProcessTerminalViewDelegate {
    private let terminalView = LocalProcessTerminalView(frame: .zero)
    private var currentShell: TerminalShell?
    private let initialDirectory = FileManager.default.homeDirectoryForCurrentUser.path

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    deinit {
        stop()
    }

    func run(shell: TerminalShell) {
        guard currentShell != shell else {
            return
        }

        stop()
        currentShell = shell
        window?.title = "Embedded Terminal · \(shell.title)"
        terminalView.startProcess(executable: shell.path, currentDirectory: initialDirectory)
    }

    func stop() {
        terminalView.terminate()
    }

    private func setup() {
        wantsLayer = true
        terminalView.processDelegate = self
        terminalView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(terminalView)

        NSLayoutConstraint.activate([
            terminalView.leadingAnchor.constraint(equalTo: leadingAnchor),
            terminalView.trailingAnchor.constraint(equalTo: trailingAnchor),
            terminalView.topAnchor.constraint(equalTo: topAnchor),
            terminalView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        guard !title.isEmpty else {
            return
        }

        window?.title = title
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        window?.subtitle = "exit \(exitCode ?? 0)"
    }
}

struct EmbeddedTerminalView: NSViewRepresentable {
    let shell: TerminalShell

    func makeNSView(context: Context) -> TerminalContainerView {
        let view = TerminalContainerView()
        view.run(shell: shell)
        return view
    }

    func updateNSView(_ nsView: TerminalContainerView, context: Context) {
        nsView.run(shell: shell)
    }

    static func dismantleNSView(_ nsView: TerminalContainerView, coordinator: ()) {
        nsView.stop()
    }
}

struct ContentView: View {
    private let shells: [TerminalShell]
    @State private var selectedShellPath: String

    init() {
        let availableShells = TerminalShell.availableShells()
        shells = availableShells
        _selectedShellPath = State(initialValue: TerminalShell.defaultShell(in: availableShells).path)
    }

    private var selectedShell: TerminalShell {
        shells.first(where: { $0.path == selectedShellPath }) ?? TerminalShell.defaultShell(in: shells)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("Shell")
                    .font(.headline)

                Picker("Shell", selection: $selectedShellPath) {
                    ForEach(shells) { shell in
                        Text("\(shell.title)  \(shell.path)").tag(shell.path)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 320, alignment: .leading)

                Spacer()

                Text(selectedShell.path)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(12)

            Divider()

            EmbeddedTerminalView(shell: selectedShell)
        }
        .frame(minWidth: 720, minHeight: 480)
    }
}
