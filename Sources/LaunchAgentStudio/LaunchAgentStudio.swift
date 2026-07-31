import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ReleaseInfo: Identifiable, Hashable {
    let tagName: String
    let name: String
    let htmlURL: URL

    var id: String { tagName }
    var versionText: String { tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV")) }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let name: String?
    let htmlURL: URL

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlURL = "html_url"
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case zhHans
    case english

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .zhHans: return "简体中文"
        case .english: return "English"
        }
    }
}

enum TaskActionType: String, CaseIterable, Identifiable {
    case application
    case script
    case command

    var id: String { rawValue }
}

enum TaskTriggerType: String, CaseIterable, Identifiable {
    case daily
    case login
    case interval

    var id: String { rawValue }
}

struct TaskDraft {
    var name = ""
    var actionType: TaskActionType = .application
    var targetPath = ""
    var command = ""
    var triggerType: TaskTriggerType = .daily
    var hour = 22
    var minute = 0
    var intervalMinutes = 60
    var enableAfterCreate = true
}

struct LaunchAgent: Identifiable, Hashable {
    let id: String
    let displayName: String
    let label: String
    let fileURL: URL
    let schedule: String
    let isLoaded: Bool
    let logURLs: [URL]
}

@MainActor
final class AgentStore: ObservableObject {
    @Published var agents: [LaunchAgent] = []
    @Published var selectedID: String?
    @Published var message = "正在读取用户任务…"
    @Published var isBusy = false
    @Published var language: AppLanguage
    @Published var availableUpdate: ReleaseInfo?

    private let uid = getuid()
    private var displayNames: [String: String] = [:]
    private var isCheckingForUpdates = false

    init() {
        let defaults = UserDefaults.standard
        let hasExplicitChoice = defaults.bool(forKey: "HasExplicitLanguageChoice")
        if hasExplicitChoice,
           let saved = defaults.string(forKey: "AppLanguage"),
           let savedLanguage = AppLanguage(rawValue: saved) {
            language = savedLanguage
        } else {
            language = Self.systemLanguage()
        }
        message = language == .zhHans ? "正在读取用户任务…" : "Reading user tasks…"
    }

    func tr(_ zhHans: String, _ english: String) -> String {
        language == .zhHans ? zhHans : english
    }

    func setLanguage(_ newLanguage: AppLanguage) {
        guard language != newLanguage else { return }
        language = newLanguage
        UserDefaults.standard.set(newLanguage.rawValue, forKey: "AppLanguage")
        UserDefaults.standard.set(true, forKey: "HasExplicitLanguageChoice")
        refresh()
    }

    func checkForUpdates() {
        guard !isCheckingForUpdates else { return }
        isCheckingForUpdates = true

        Task { [weak self] in
            defer { self?.isCheckingForUpdates = false }
            guard let self else { return }

            do {
                var request = URLRequest(url: URL(string: "https://api.github.com/repos/firzen/launchagent-studio/releases/latest")!)
                request.setValue("LaunchAgent-Studio", forHTTPHeaderField: "User-Agent")
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else { return }

                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                guard Self.isNewer(release.tagName, than: Self.currentVersion) else { return }

                let update = ReleaseInfo(
                    tagName: release.tagName,
                    name: release.name?.isEmpty == false ? release.name! : release.tagName,
                    htmlURL: release.htmlURL
                )
                let defaults = UserDefaults.standard
                guard defaults.string(forKey: "LastNotifiedReleaseTag") != update.tagName else { return }
                defaults.set(update.tagName, forKey: "LastNotifiedReleaseTag")
                availableUpdate = update
            } catch {
                // Update checks are best-effort and should not interrupt normal app use.
            }
        }
    }

    func openRelease(_ release: ReleaseInfo) {
        NSWorkspace.shared.open(release.htmlURL)
        availableUpdate = nil
    }

    private static let currentVersion: String = {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.5.0"
    }()

    private static func isNewer(_ remote: String, than local: String) -> Bool {
        func components(_ version: String) -> [Int] {
            version
                .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                .split(separator: ".")
                .map { part in Int(part.prefix { $0.isNumber }) ?? 0 }
        }
        let remoteParts = components(remote)
        let localParts = components(local)
        for index in 0..<max(remoteParts.count, localParts.count) {
            let remoteValue = index < remoteParts.count ? remoteParts[index] : 0
            let localValue = index < localParts.count ? localParts[index] : 0
            if remoteValue != localValue { return remoteValue > localValue }
        }
        return false
    }

    private static func systemLanguage() -> AppLanguage {
        guard let preferred = Locale.preferredLanguages.first else {
            return .english
        }
        let identifier = Locale(identifier: preferred)
        if identifier.language.languageCode?.identifier == "zh" {
            return .zhHans
        }
        return .english
    }

    func actionTitle(_ action: TaskActionType) -> String {
        switch action {
        case .application: return tr("打开应用", "Open Application")
        case .script: return tr("运行 Shell 脚本", "Run Shell Script")
        case .command: return tr("执行命令", "Run Command")
        }
    }

    func triggerTitle(_ trigger: TaskTriggerType) -> String {
        switch trigger {
        case .daily: return tr("每天固定时间", "Daily at a Fixed Time")
        case .login: return tr("登录或启用时", "At Login or When Enabled")
        case .interval: return tr("固定间隔", "Fixed Interval")
        }
    }
    private var launchAgentsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
    }
    private var supportURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/LaunchAgentStudio", isDirectory: true)
    }
    private var metadataURL: URL {
        supportURL.appendingPathComponent("TaskNames.plist")
    }

    func refresh() {
        isBusy = true
        defer { isBusy = false }

        do {
            loadDisplayNames()
            let files = try FileManager.default.contentsOfDirectory(
                at: launchAgentsURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            let plistFiles = files
                .filter { $0.pathExtension.lowercased() == "plist" }
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

            agents = plistFiles.compactMap(makeAgent).sorted {
                if $0.isLoaded != $1.isLoaded {
                    return $0.isLoaded && !$1.isLoaded
                }
                return $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
            }
            if let selectedID, !agents.contains(where: { $0.id == selectedID }) {
                self.selectedID = nil
            }
            message = tr("共 \(agents.count) 个用户任务", "\(agents.count) user tasks")
        } catch {
            agents = []
            message = tr("读取失败：\(error.localizedDescription)", "Failed to read tasks: \(error.localizedDescription)")
        }
    }

    func loadSelected() {
        guard let agent = selected else { return }
        perform(
            executable: "/bin/launchctl",
            arguments: ["bootstrap", "gui/\(uid)", agent.fileURL.path],
            success: tr("已启用 \(agent.displayName)", "Enabled \(agent.displayName)")
        )
    }

    func unloadSelected() {
        guard let agent = selected else { return }
        perform(
            executable: "/bin/launchctl",
            arguments: ["bootout", "gui/\(uid)", agent.fileURL.path],
            success: tr("已禁用 \(agent.displayName)", "Disabled \(agent.displayName)")
        )
    }

    func runSelected() {
        guard let agent = selected else { return }
        perform(
            executable: "/bin/launchctl",
            arguments: ["kickstart", "-k", "gui/\(uid)/\(agent.label)"],
            success: tr("已触发 \(agent.displayName)", "Started \(agent.displayName)")
        )
    }

    func revealSelected() {
        guard let agent = selected else { return }
        NSWorkspace.shared.activateFileViewerSelecting([agent.fileURL])
    }

    func openLog() {
        guard let agent = selected else { return }
        if let existing = agent.logURLs.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            NSWorkspace.shared.open(existing)
        } else {
            let logs = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Logs", isDirectory: true)
            NSWorkspace.shared.open(logs)
            message = tr(
                "尚未找到该任务的日志文件，已打开日志目录",
                "No log file was found. The Logs folder has been opened."
            )
        }
    }

    func deleteSelected() {
        guard let agent = selected else { return }
        let expectedDirectory = launchAgentsURL.standardizedFileURL.path + "/"
        let target = agent.fileURL.standardizedFileURL
        guard target.path.hasPrefix(expectedDirectory) else {
            message = tr("无法删除任务：配置文件不在用户任务目录中", "Cannot delete task: its configuration is outside the user task folder")
            return
        }

        isBusy = true
        defer { isBusy = false }

        if agent.isLoaded {
            let result = run(
                executable: "/bin/launchctl",
                arguments: ["bootout", "gui/\(uid)", target.path]
            )
            if result.status != 0 {
                let detail = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
                message = detail.isEmpty
                    ? tr("禁用失败，任务未删除", "The task could not be disabled and was not deleted")
                    : tr("禁用失败，任务未删除：\(detail)", "The task could not be disabled and was not deleted: \(detail)")
                return
            }
        }

        do {
            var trashedURL: NSURL?
            try FileManager.default.trashItem(at: target, resultingItemURL: &trashedURL)
            displayNames.removeValue(forKey: agent.label)
            try? saveDisplayNames()
            selectedID = nil
            refresh()
            message = tr(
                "已将任务「\(agent.displayName)」移到废纸篓",
                "Moved “\(agent.displayName)” to the Trash"
            )
        } catch {
            message = tr(
                "删除失败：\(error.localizedDescription)",
                "Failed to delete task: \(error.localizedDescription)"
            )
        }
    }

    func createTask(_ draft: TaskDraft) -> String? {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return tr("任务名称不能为空", "Task name is required") }

        let arguments: [String]
        switch draft.actionType {
        case .application:
            guard !draft.targetPath.isEmpty else {
                return tr("请选择需要打开的应用", "Select an application to open")
            }
            guard FileManager.default.fileExists(atPath: draft.targetPath) else {
                return tr("选择的应用不存在", "The selected application does not exist")
            }
            arguments = ["/usr/bin/open", draft.targetPath]
        case .script:
            guard !draft.targetPath.isEmpty else {
                return tr("请选择需要运行的 Shell 脚本", "Select a Shell script to run")
            }
            guard FileManager.default.fileExists(atPath: draft.targetPath) else {
                return tr("选择的脚本不存在", "The selected script does not exist")
            }
            arguments = ["/bin/zsh", draft.targetPath]
        case .command:
            let command = draft.command.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !command.isEmpty else { return tr("命令不能为空", "Command is required") }
            arguments = ["/bin/zsh", "-lc", command]
        }

        guard (0...23).contains(draft.hour), (0...59).contains(draft.minute) else {
            return tr("执行时间无效", "The scheduled time is invalid")
        }
        guard draft.intervalMinutes >= 1 else {
            return tr("执行间隔不能小于 1 分钟", "The interval must be at least 1 minute")
        }

        let label = makeLabel(name)
        let fileURL = launchAgentsURL.appendingPathComponent("\(label).plist")
        let logURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/\(label).log")

        var plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": arguments,
            "StandardOutPath": logURL.path,
            "StandardErrorPath": logURL.path
        ]

        switch draft.triggerType {
        case .daily:
            plist["StartCalendarInterval"] = [
                "Hour": draft.hour,
                "Minute": draft.minute
            ]
        case .login:
            plist["RunAtLoad"] = true
        case .interval:
            plist["StartInterval"] = draft.intervalMinutes * 60
        }

        do {
            try FileManager.default.createDirectory(
                at: launchAgentsURL,
                withIntermediateDirectories: true
            )
            try FileManager.default.createDirectory(
                at: logURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try PropertyListSerialization.data(
                fromPropertyList: plist,
                format: .xml,
                options: 0
            )
            try data.write(to: fileURL, options: .atomic)

            displayNames[label] = name
            try saveDisplayNames()

            var enableError: String?
            if draft.enableAfterCreate {
                let result = run(
                    executable: "/bin/launchctl",
                    arguments: ["bootstrap", "gui/\(uid)", fileURL.path]
                )
                if result.status != 0 {
                    let detail = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
                    enableError = detail.isEmpty
                        ? tr("创建成功，但启用失败", "Task created, but it could not be enabled")
                        : tr("创建成功，但启用失败：\(detail)", "Task created, but it could not be enabled: \(detail)")
                }
            }

            refresh()
            selectedID = label
            message = enableError ?? tr("已创建任务「\(name)」", "Created task “\(name)”")
            return nil
        } catch {
            return tr("创建失败：\(error.localizedDescription)", "Failed to create task: \(error.localizedDescription)")
        }
    }

    var selected: LaunchAgent? {
        guard let selectedID else { return nil }
        return agents.first { $0.id == selectedID }
    }

    private func makeAgent(from url: URL) -> LaunchAgent? {
        guard
            let data = try? Data(contentsOf: url),
            let object = try? PropertyListSerialization.propertyList(from: data, format: nil),
            let plist = object as? [String: Any]
        else { return nil }

        let label = (plist["Label"] as? String) ?? url.deletingPathExtension().lastPathComponent
        let loaded = run(
            executable: "/bin/launchctl",
            arguments: ["print", "gui/\(uid)/\(label)"]
        ).status == 0

        var logs: [URL] = []
        for key in ["StandardOutPath", "StandardErrorPath"] {
            if let path = plist[key] as? String {
                let expanded = NSString(string: path).expandingTildeInPath
                let logURL = URL(fileURLWithPath: expanded)
                if !logs.contains(logURL) { logs.append(logURL) }
            }
        }

        return LaunchAgent(
            id: label,
            displayName: friendlyName(label: label, plist: plist),
            label: label,
            fileURL: url,
            schedule: describeSchedule(plist),
            isLoaded: loaded,
            logURLs: logs
        )
    }

    private func friendlyName(label: String, plist: [String: Any]) -> String {
        if let displayName = displayNames[label], !displayName.isEmpty {
            return displayName
        }
        let lower = label.lowercased()

        if lower.contains("citrolabs") {
            if lower.contains("wake") { return tr("Ego Lite · 定时检查更新", "Ego Lite · Scheduled Update Check") }
            if lower.contains("xpcservice") { return tr("Ego Lite · 更新后台服务", "Ego Lite · Update Service") }
            if lower.contains("keystone") { return tr("Ego Lite · 更新代理", "Ego Lite · Update Agent") }
            return "Ego Lite"
        }
        if lower.contains("google") {
            if lower.contains("wake") { return tr("Google 软件 · 定时检查更新", "Google Software · Scheduled Update Check") }
            if lower.contains("xpcservice") { return tr("Google 软件 · 更新后台服务", "Google Software · Update Service") }
            if lower.contains("keystone") { return tr("Google 软件 · 更新代理", "Google Software · Update Agent") }
            return tr("Google 软件", "Google Software")
        }
        if lower.contains("tencent") && lower.contains("lemon") {
            return tr("腾讯柠檬清理 · 垃圾桶监控", "Tencent Lemon · Trash Monitor")
        }
        if lower.contains("valvesoftware") || lower.contains("steam") {
            return tr("Steam · 清理服务", "Steam · Cleanup Service")
        }
        if lower.contains("netdisk") || programPath(plist).lowercased().contains("baidunetdisk") {
            return tr("百度网盘 · 后台服务", "Baidu Netdisk · Background Service")
        }

        let path = programPath(plist)
        if let appName = appNameFromPath(path), !appName.isEmpty {
            return tr("\(appName) · 后台任务", "\(appName) · Background Task")
        }

        let pieces = label.split(separator: ".")
        if let last = pieces.last, !last.isEmpty {
            return humanize(String(last))
        }
        return label
    }

    private func programPath(_ plist: [String: Any]) -> String {
        if let program = plist["Program"] as? String { return program }
        if let arguments = plist["ProgramArguments"] as? [String],
           let first = arguments.first {
            return first
        }
        return ""
    }

    private func appNameFromPath(_ path: String) -> String? {
        guard !path.isEmpty else { return nil }
        let components = path.split(separator: "/").map(String.init)
        let appComponents = components.filter { $0.lowercased().hasSuffix(".app") }
        guard let component = appComponents.first else { return nil }
        let raw = String(component.dropLast(4))
        return humanize(raw)
    }

    private func humanize(_ value: String) -> String {
        let spaced = value
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        return spaced
            .split(separator: " ")
            .map { word in
                let text = String(word)
                return text.prefix(1).uppercased() + text.dropFirst()
            }
            .joined(separator: " ")
    }

    private func makeLabel(_ name: String) -> String {
        let latin = name
            .applyingTransform(.toLatin, reverse: false)?
            .applyingTransform(.stripDiacritics, reverse: false) ?? name
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789")
        let slug = latin.lowercased().unicodeScalars.map {
            allowed.contains($0) ? String($0) : "-"
        }
        .joined()
        .split(separator: "-")
        .filter { !$0.isEmpty }
        .joined(separator: "-")
        let safeName = slug.isEmpty ? "task" : String(slug.prefix(36))
        let suffix = UUID().uuidString.prefix(6).lowercased()
        return "local.user.\(safeName).\(suffix)"
    }

    private func loadDisplayNames() {
        guard
            let data = try? Data(contentsOf: metadataURL),
            let object = try? PropertyListSerialization.propertyList(from: data, format: nil),
            let names = object as? [String: String]
        else {
            displayNames = [:]
            return
        }
        displayNames = names
    }

    private func saveDisplayNames() throws {
        try FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(
            fromPropertyList: displayNames,
            format: .xml,
            options: 0
        )
        try data.write(to: metadataURL, options: .atomic)
    }

    private func describeSchedule(_ plist: [String: Any]) -> String {
        if let intervals = plist["StartCalendarInterval"] as? [[String: Any]] {
            let values = intervals.compactMap(describeCalendar)
            if !values.isEmpty { return values.joined(separator: tr("、", ", ")) }
        }
        if let interval = plist["StartCalendarInterval"] as? [String: Any],
           let value = describeCalendar(interval) {
            return value
        }
        if let seconds = plist["StartInterval"] as? Int {
            if seconds >= 60 && seconds.isMultiple(of: 60) {
                return tr("每 \(seconds / 60) 分钟", "Every \(seconds / 60) min")
            }
            return tr("每 \(seconds) 秒", "Every \(seconds) sec")
        }
        if (plist["RunAtLoad"] as? Bool) == true {
            return tr("登录时运行", "At Login")
        }
        if (plist["KeepAlive"] as? Bool) == true || plist["KeepAlive"] is [String: Any] {
            return tr("持续运行", "Keep Running")
        }
        return tr("按条件触发", "Conditional")
    }

    private func describeCalendar(_ value: [String: Any]) -> String? {
        let hour = value["Hour"] as? Int
        let minute = value["Minute"] as? Int
        let weekday = value["Weekday"] as? Int

        guard hour != nil || minute != nil || weekday != nil else { return nil }
        var parts: [String] = []
        if let weekday {
            let zhNames = ["", "周日", "周一", "周二", "周三", "周四", "周五", "周六"]
            let enNames = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            let names = language == .zhHans ? zhNames : enNames
            parts.append((1...7).contains(weekday) ? names[weekday] : tr("星期 \(weekday)", "Weekday \(weekday)"))
        } else {
            parts.append(tr("每天", "Daily"))
        }
        if let hour {
            parts.append(String(format: "%02d:%02d", hour, minute ?? 0))
        } else if let minute {
            parts.append(tr("每小时第 \(minute) 分", "Minute \(minute) of each hour"))
        }
        return parts.joined(separator: " ")
    }

    private func perform(executable: String, arguments: [String], success: String) {
        isBusy = true
        let result = run(executable: executable, arguments: arguments)
        isBusy = false
        if result.status == 0 {
            message = success
        } else {
            let detail = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            message = detail.isEmpty
                ? tr("操作失败（状态码 \(result.status)）", "Operation failed (status \(result.status))")
                : tr("操作失败：\(detail)", "Operation failed: \(detail)")
        }
        refresh()
    }

    private func run(executable: String, arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
        } catch {
            return (-1, error.localizedDescription)
        }
    }
}

struct ContentView: View {
    @StateObject private var store = AgentStore()
    @State private var isCreatingTask = false
    @State private var isConfirmingDelete = false
    @State private var isShowingUpdateAlert = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            list
            Divider()
            footer
        }
        .frame(minWidth: 760, minHeight: 460)
        .onAppear { store.refresh() }
        .task { store.checkForUpdates() }
        .onReceive(store.$availableUpdate) { update in
            isShowingUpdateAlert = update != nil
        }
        .sheet(isPresented: $isCreatingTask) {
            NewTaskView(store: store, isPresented: $isCreatingTask)
        }
        .alert(
            store.tr("删除任务", "Delete Task"),
            isPresented: $isConfirmingDelete,
            presenting: store.selected
        ) { _ in
            Button(store.tr("取消", "Cancel"), role: .cancel) {}
            Button(store.tr("移到废纸篓", "Move to Trash"), role: .destructive) {
                store.deleteSelected()
            }
        } message: { agent in
            Text(store.tr(
                "任务「\(agent.displayName)」将先被禁用，再移到废纸篓。",
                "“\(agent.displayName)” will be disabled and moved to the Trash."
            ))
        }
        .alert(
            store.tr("发现新版本", "New Version Available"),
            isPresented: $isShowingUpdateAlert,
            presenting: store.availableUpdate
        ) { release in
            Button(store.tr("更新", "Update")) {
                store.openRelease(release)
            }
            Button(store.tr("稍后", "Later"), role: .cancel) {}
        } message: { release in
            Text(store.tr(
                "LaunchAgent Studio \(release.versionText) 已发布。是否打开 Release 下载页面？",
                "LaunchAgent Studio \(release.versionText) is available. Open the Release download page?"
            ))
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 24))
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("LaunchAgent Studio")
                    .font(.title2.weight(.semibold))
                Text("~/Library/LaunchAgents")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker(
                store.tr("界面语言", "Language"),
                selection: Binding(
                    get: { store.language },
                    set: { store.setLanguage($0) }
                )
            ) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 160)
            Button {
                isCreatingTask = true
            } label: {
                Label(store.tr("新增任务", "New Task"), systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(store.isBusy)
            Button {
                store.refresh()
            } label: {
                Label(store.tr("刷新", "Refresh"), systemImage: "arrow.clockwise")
            }
            .disabled(store.isBusy)
        }
        .padding(16)
    }

    private var list: some View {
        List(store.agents, selection: $store.selectedID) { agent in
            HStack(spacing: 12) {
                Circle()
                    .fill(agent.isLoaded ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 9, height: 9)
                VStack(alignment: .leading, spacing: 4) {
                    Text(agent.displayName)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    Text("\(agent.label) · \(agent.fileURL.lastPathComponent)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(agent.schedule)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(width: 170, alignment: .trailing)
                Text(agent.isLoaded ? store.tr("启用", "Enabled") : store.tr("禁用", "Disabled"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(agent.isLoaded ? .green : .secondary)
                    .frame(width: 60, alignment: .trailing)
            }
            .padding(.vertical, 5)
            .tag(agent.id)
        }
        .listStyle(.inset)
        .overlay {
            if store.agents.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                    Text(store.tr("没有找到用户任务", "No User Tasks Found"))
                        .font(.headline)
                    Text(store.tr(
                        "~/Library/LaunchAgents 中没有可读取的 plist",
                        "No readable plist files were found in ~/Library/LaunchAgents"
                    ))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            HStack {
                Button(store.tr("启用", "Enable")) { store.loadSelected() }
                    .disabled(store.selected == nil || store.selected?.isLoaded == true || store.isBusy)
                Button(store.tr("禁用", "Disable")) { store.unloadSelected() }
                    .disabled(store.selected == nil || store.selected?.isLoaded == false || store.isBusy)
                Button(store.tr("立即运行", "Run Now")) { store.runSelected() }
                    .disabled(store.selected == nil || store.selected?.isLoaded == false || store.isBusy)
                Divider().frame(height: 18)
                Button(store.tr("显示配置", "Show Configuration")) { store.revealSelected() }
                    .disabled(store.selected == nil)
                Button(store.tr("打开日志", "Open Log")) { store.openLog() }
                    .disabled(store.selected == nil)
                Button(store.tr("删除", "Delete"), role: .destructive) {
                    isConfirmingDelete = true
                }
                .disabled(store.selected == nil || store.isBusy)
                Spacer()
                if store.isBusy {
                    ProgressView().controlSize(.small)
                }
            }
            HStack {
                Text(store.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer()
            }
        }
        .padding(14)
    }
}

struct NewTaskView: View {
    @ObservedObject var store: AgentStore
    @Binding var isPresented: Bool
    @State private var draft = TaskDraft()
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.tr("新增定时任务", "New Scheduled Task"))
                        .font(.title2.weight(.semibold))
                    Text(store.tr(
                        "任务配置将保存到 ~/Library/LaunchAgents",
                        "The task configuration will be saved to ~/Library/LaunchAgents"
                    ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(20)

            Divider()

            Form {
                Section(store.tr("基本信息", "Basic Information")) {
                    TextField(store.tr("任务名称", "Task Name"), text: $draft.name)
                }

                Section(store.tr("执行动作", "Action")) {
                    Picker(store.tr("动作类型", "Action Type"), selection: $draft.actionType) {
                        ForEach(TaskActionType.allCases) { action in
                            Text(store.actionTitle(action)).tag(action)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch draft.actionType {
                    case .application:
                        targetPicker(
                            title: store.tr("应用路径", "Application Path"),
                            placeholder: store.tr("选择需要打开的 .app", "Select an application"),
                            buttonTitle: store.tr("选择应用", "Choose Application"),
                            chooseApplication: true
                        )
                    case .script:
                        targetPicker(
                            title: store.tr("脚本路径", "Script Path"),
                            placeholder: store.tr("选择需要运行的 Shell 脚本", "Select a Shell script"),
                            buttonTitle: store.tr("选择脚本", "Choose Script"),
                            chooseApplication: false
                        )
                    case .command:
                        TextField(store.tr("输入 Shell 命令", "Enter a Shell command"), text: $draft.command)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                Section(store.tr("触发时间", "Schedule")) {
                    Picker(store.tr("触发方式", "Trigger"), selection: $draft.triggerType) {
                        ForEach(TaskTriggerType.allCases) { trigger in
                            Text(store.triggerTitle(trigger)).tag(trigger)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch draft.triggerType {
                    case .daily:
                        HStack {
                            Stepper(
                                store.tr(
                                    "小时：\(String(format: "%02d", draft.hour))",
                                    "Hour: \(String(format: "%02d", draft.hour))"
                                ),
                                value: $draft.hour,
                                in: 0...23
                            )
                            Spacer()
                            Stepper(
                                store.tr(
                                    "分钟：\(String(format: "%02d", draft.minute))",
                                    "Minute: \(String(format: "%02d", draft.minute))"
                                ),
                                value: $draft.minute,
                                in: 0...59
                            )
                        }
                    case .login:
                        Text(store.tr(
                            "任务会在登录账户或手动启用时运行一次。",
                            "The task runs once at login or when it is manually enabled."
                        ))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    case .interval:
                        Stepper(
                            store.tr(
                                "每 \(draft.intervalMinutes) 分钟运行一次",
                                "Run every \(draft.intervalMinutes) minutes"
                            ),
                            value: $draft.intervalMinutes,
                            in: 1...10080
                        )
                    }
                }

                Section {
                    Toggle(store.tr("创建后立即启用", "Enable After Creation"), isOn: $draft.enableAfterCreate)
                }

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button(store.tr("取消", "Cancel")) {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                Button(store.tr("创建任务", "Create Task")) {
                    if let error = store.createTask(draft) {
                        errorMessage = error
                    } else {
                        isPresented = false
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 620, height: 560)
    }

    @ViewBuilder
    private func targetPicker(
        title: String,
        placeholder: String,
        buttonTitle: String,
        chooseApplication: Bool
    ) -> some View {
        HStack {
            TextField(placeholder, text: $draft.targetPath)
                .textFieldStyle(.roundedBorder)
            Button(buttonTitle) {
                let panel = NSOpenPanel()
                panel.canChooseDirectories = false
                panel.canChooseFiles = true
                panel.allowsMultipleSelection = false
                panel.prompt = store.tr("选择", "Choose")
                if chooseApplication {
                    panel.allowedContentTypes = [.applicationBundle]
                    panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
                } else {
                    panel.allowedContentTypes = [.item]
                }
                if panel.runModal() == .OK, let url = panel.url {
                    draft.targetPath = url.path
                }
            }
        }
        .accessibilityLabel(title)
    }
}

@main
struct LaunchAgentStudioApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
