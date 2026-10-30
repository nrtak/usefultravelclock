import SwiftUI
import UIKit

enum DashboardTab: Int, CaseIterable, Identifiable {
    case home = 0, trip = 1, tools = 2
    var id: Int { rawValue }
    static let defaults = "0,1,2"
    var title: String {
        switch self { case .home: return "Home"; case .trip: return "My Trip"; case .tools: return "Tools" }
    }
    var symbol: String {
        switch self { case .home: return "house"; case .trip: return "suitcase"; case .tools: return "square.grid.2x2" }
    }
    static func decode(_ saved: String) -> [Self] {
        var seen = Set<Self>()
        let items = saved.split(separator: ",").compactMap { Int($0).flatMap(Self.init(rawValue:)) }
            .filter { seen.insert($0).inserted }
        return items.isEmpty ? allCases : items
    }
    static func encode(_ items: [Self]) -> String { items.map { String($0.rawValue) }.joined(separator: ",") }
    static func removing(_ item: Self, from saved: String) -> String {
        let items = decode(saved)
        guard items.count > 1 else { return saved }
        return encode(items.filter { $0 != item })
    }
    static func showing(_ item: Self, in saved: String) -> String {
        let items = decode(saved)
        return items.contains(item) ? saved : encode(items + [item])
    }
    static func moving(_ item: Self, to target: Self, in saved: String) -> String {
        var items = decode(saved)
        guard let from = items.firstIndex(of: item), let to = items.firstIndex(of: target), from != to else { return saved }
        items.remove(at: from); items.insert(item, at: to)
        return encode(items)
    }
}

struct TripReorderable: ViewModifier {
    let id: String
    let enabled: Bool
    let move: (String, String) -> Bool
    @ViewBuilder func body(content: Content) -> some View {
        if enabled {
            content.draggable(id).dropDestination(for: String.self) { items, _ in
                guard items.count == 1, let source = items.first else { return false }
                return move(source, id)
            }
        } else { content }
    }
}

struct TripEditingMotion: ViewModifier {
    let editing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var wobble = false
    private var animated: Bool { editing && !reduceMotion }
    func body(content: Content) -> some View {
        content.rotationEffect(.degrees(animated ? (wobble ? 0.5 : -0.5) : 0))
            .animation(animated ? .easeInOut(duration: 0.18).repeatForever(autoreverses: true) : nil, value: wobble)
            .onAppear { wobble = animated }
            .onChange(of: animated) { _, value in wobble = value }
    }
}

struct DashboardTabEditor: View {
    @Binding var savedTabs: String
    @Binding var selection: Int
    let done: () -> Void
    private var tabs: [DashboardTab] { DashboardTab.decode(savedTabs) }
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Edit tabs").font(.headline)
                Spacer()
                if tabs.count < DashboardTab.allCases.count {
                    Menu("Add tab") {
                        ForEach(DashboardTab.allCases.filter { !tabs.contains($0) }) { item in
                            Button(item.title) { savedTabs = DashboardTab.showing(item, in: savedTabs) }
                        }
                    }.frame(minHeight: 44)
                }
                Button("Done", action: done).fontWeight(.semibold).frame(minHeight: 44)
            }
            HStack(spacing: 12) {
                ForEach(tabs) { item in
                    Button { selection = item.rawValue } label: {
                        VStack(spacing: 6) {
                            Image(systemName: item.symbol).font(.title2)
                            Text(item.title).font(.subheadline.weight(.semibold))
                        }.frame(maxWidth: .infinity, minHeight: 64)
                            .foregroundStyle(selection == item.rawValue ? Color.blue : Color.primary)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    }.buttonStyle(.plain)
                    .overlay(alignment: .topLeading) {
                        if tabs.count > 1 {
                            Button { hide(item) } label: {
                                Image(systemName: "minus.circle.fill").symbolRenderingMode(.palette).font(.title3)
                                    .foregroundStyle(.white, .red).frame(width: 44, height: 44)
                            }.buttonStyle(.plain).offset(x: -10, y: -16)
                                .accessibilityLabel("Hide \(item.title) tab")
                        }
                    }
                    .modifier(TripReorderable(id: "tab:\(item.rawValue)", enabled: true) { source, target in
                        guard let from = tabID(source), let to = tabID(target), from != to else { return false }
                        withAnimation { savedTabs = DashboardTab.moving(from, to: to, in: savedTabs) }
                        return true
                    })
                    .modifier(TripEditingMotion(editing: true))
                    .accessibilityActions {
                        Button("Move earlier") { move(item, offset: -1) }
                        Button("Move later") { move(item, offset: 1) }
                        if tabs.count > 1 { Button("Hide tab") { hide(item) } }
                    }
                }
            }.padding(.top, 8)
            Text("Drag tabs to reorder. Hidden tabs can be added again here or in Settings.")
                .font(.footnote).foregroundStyle(.secondary)
        }.padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 12).padding(.bottom, 8)
    }
    private func tabID(_ value: String) -> DashboardTab? {
        guard value.hasPrefix("tab:"), let number = Int(value.dropFirst(4)) else { return nil }
        return DashboardTab(rawValue: number)
    }
    private func hide(_ item: DashboardTab) {
        savedTabs = DashboardTab.removing(item, from: savedTabs)
        if !DashboardTab.decode(savedTabs).contains(where: { $0.rawValue == selection }) {
            selection = DashboardTab.decode(savedTabs)[0].rawValue
        }
    }
    private func move(_ item: DashboardTab, offset: Int) {
        guard let index = tabs.firstIndex(of: item), tabs.indices.contains(index + offset) else { return }
        savedTabs = DashboardTab.moving(item, to: tabs[index + offset], in: savedTabs)
    }
}

struct DashboardTabSettings: View {
    @AppStorage("trip-tab-order") private var savedTabs = DashboardTab.defaults
    @AppStorage("trip-navigation-tab-v2") private var selection = 0
    private var tabs: [DashboardTab] { DashboardTab.decode(savedTabs) }
    var body: some View {
        List {
            Section {
                Text("Hold a bottom tab to reorder or hide tabs. Hiding a tab keeps its saved information. Keep at least one tab visible.")
            }
            Section("Visible tabs") {
                ForEach(tabs) { item in
                    Label(item.title, systemImage: item.symbol)
                        .deleteDisabled(tabs.count == 1)
                }.onMove { offsets, target in
                    var items = tabs; items.move(fromOffsets: offsets, toOffset: target)
                    savedTabs = DashboardTab.encode(items)
                }.onDelete { offsets in
                    let remaining = tabs.enumerated().filter { !offsets.contains($0.offset) }.map(\.element)
                    guard !remaining.isEmpty else { return }
                    savedTabs = DashboardTab.encode(remaining)
                    if !remaining.contains(where: { $0.rawValue == selection }) { selection = remaining[0].rawValue }
                }
            }
            Section("Hidden tabs") {
                ForEach(DashboardTab.allCases.filter { !tabs.contains($0) }) { item in
                    Button { savedTabs = DashboardTab.showing(item, in: savedTabs) } label: {
                        Label(item.title, systemImage: "plus.circle")
                    }
                }
            }
            Button("Restore all tabs") { savedTabs = DashboardTab.defaults }
        }.navigationTitle("Bottom tabs").toolbar { EditButton() }
    }
}

// Public UIKit APIs add a hold gesture to the native tab bar, preserving its
// standard navigation, accessibility, and Liquid Glass appearance when browsing.
struct TripTabBarHold: UIViewControllerRepresentable {
    var enabled: Bool
    var onHold: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIViewController(context: Context) -> Probe {
        let controller = Probe()
        controller.resolve = { [weak coordinator = context.coordinator] probe in coordinator?.install(from: probe) }
        return controller
    }
    func updateUIViewController(_ controller: Probe, context: Context) {
        _ = typeSize
        context.coordinator.enabled = enabled
        context.coordinator.onHold = onHold
        context.coordinator.install(from: controller)
    }
    static func dismantleUIViewController(_ controller: Probe, coordinator: Coordinator) {
        coordinator.remove(); coordinator.onHold = nil; controller.resolve = nil
    }
    final class Probe: UIViewController {
        var resolve: (@MainActor (Probe) -> Void)?
        override func loadView() { view = UIView(); view.isUserInteractionEnabled = false }
        override func didMove(toParent parent: UIViewController?) { super.didMove(toParent: parent); resolve?(self) }
        override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); resolve?(self) }
        override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); resolve?(self) }
    }
    @MainActor final class Coordinator: NSObject {
        weak var bar: UITabBar?
        var gesture: UILongPressGestureRecognizer?
        var lastFontSize: CGFloat?
        var lastItems: [ObjectIdentifier] = []
        var enabled = true
        var onHold: (() -> Void)?
        func install(from controller: UIViewController) {
            guard enabled else {
                if gesture?.isEnabled == true { gesture?.isEnabled = false }
                return
            }
            func find(_ candidate: UIViewController) -> UITabBarController? {
                if let tabs = candidate as? UITabBarController { return tabs }
                for child in candidate.children { if let found = find(child) { return found } }
                return nil
            }
            func findBar(_ view: UIView) -> UITabBar? {
                if let bar = view as? UITabBar { return bar }
                for child in view.subviews { if let bar = findBar(child) { return bar } }
                return nil
            }
            let root = controller.view.window?.rootViewController
            let controllerBar = (controller.tabBarController ?? root.flatMap { find($0) })?.tabBar
            guard let resolved = controllerBar ?? controller.view.window.flatMap({ findBar($0) }) else { return }
            if bar !== resolved {
                remove(); bar = resolved
                let hold = UILongPressGestureRecognizer(target: self, action: #selector(held(_:)))
                hold.minimumPressDuration = 0.8; hold.cancelsTouchesInView = true
                resolved.addGestureRecognizer(hold); gesture = hold
            }
            if gesture?.isEnabled == false { gesture?.isEnabled = true }
            let font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: .systemFont(ofSize: 13, weight: .medium), maximumPointSize: 20)
            let items = resolved.items ?? []
            let identities = items.map { ObjectIdentifier($0) }
            guard lastFontSize != font.pointSize || lastItems != identities else { return }
            // Updating identical title attributes on every layout can cause a layout loop.
            lastFontSize = font.pointSize; lastItems = identities
            for item in items {
                for state in [UIControl.State.normal, .selected] {
                    var attributes = item.titleTextAttributes(for: state) ?? [:]
                    attributes[.font] = font; item.setTitleTextAttributes(attributes, for: state)
                }
            }
        }
        @objc private func held(_ recognizer: UILongPressGestureRecognizer) {
            guard enabled, recognizer.state == .began else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            DispatchQueue.main.async { [weak self] in
                guard let self, self.enabled, UIApplication.shared.applicationState == .active else { return }
                self.onHold?()
            }
        }
        func remove() {
            if let gesture { bar?.removeGestureRecognizer(gesture) }
            gesture = nil; bar = nil; lastFontSize = nil; lastItems = []
        }
    }
}
