import SwiftUI
import UIKit

// Logs actual UIKit callbacks, rather than printing Android callback names.
class LifecycleHostingController<Content: View>: UIHostingController<Content> {
    private let lifecycleName: String
    init(name: String, rootView: Content) {
        lifecycleName = name
        super.init(rootView: rootView)
    }
    @MainActor required dynamic init?(coder aDecoder: NSCoder) { fatalError("Use init(name:rootView:)") }
    override func loadView() { super.loadView(); log("loadView") }
    override func viewDidLoad() { super.viewDidLoad(); log("viewDidLoad") }
    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); log("viewWillAppear") }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); log("viewDidAppear") }
    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); log("viewWillDisappear") }
    override func viewDidDisappear(_ animated: Bool) { super.viewDidDisappear(animated); log("viewDidDisappear") }
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if parent == nil { log("removedFromParent (view detached; not an onDestroyView callback)") }
    }
    private func log(_ method: String) { print("[Lifecycle] \(lifecycleName).\(method)") }
    deinit { print("[Lifecycle] \(lifecycleName).deinit") }
}

final class HomeViewController: LifecycleHostingController<HomeView> {
    init(store: WorkoutStore, onStart: @escaping () -> Void) {
        super.init(name: "HomeViewController", rootView: HomeView(store: store, onStartWorkout: onStart))
    }
    @MainActor required dynamic init?(coder aDecoder: NSCoder) { fatalError("Use init(store:onStart:)") }
}

final class ActiveWorkoutViewController: LifecycleHostingController<ActiveWorkoutView> {
    init(store: WorkoutStore, onHome: @escaping () -> Void) {
        super.init(name: "ActiveWorkoutViewController", rootView: ActiveWorkoutView(store: store, onHome: onHome))
    }
    @MainActor required dynamic init?(coder aDecoder: NSCoder) { fatalError("Use init(store:onHome:)") }
}

final class MainViewController: UIViewController {
    private let store: WorkoutStore
    private let content = UIView()
    private var screen: UIViewController?
    private var footer: UIHostingController<WorkoutTabBar>?
    private var selectedTab = 0

    init(store: WorkoutStore) { self.store = store; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("Use init(store:)") }

    override func loadView() { super.loadView(); log("loadView") }
    override func viewDidLoad() {
        super.viewDidLoad()
        log("viewDidLoad")
        view.backgroundColor = UIColor(FitTrackStyle.background)
        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content)
        let footer = UIHostingController(rootView: tabBar)
        self.footer = footer
        addChild(footer)
        footer.view.translatesAutoresizingMaskIntoConstraints = false
        footer.view.backgroundColor = .white
        view.addSubview(footer.view)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            content.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: footer.view.topAnchor),
            footer.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footer.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footer.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            footer.view.heightAnchor.constraint(equalToConstant: 62)
        ])
        footer.didMove(toParent: self)
        showScreen(0)
    }

    private var tabBar: WorkoutTabBar {
        WorkoutTabBar(selected: selectedTab) { [weak self] tab in self?.selectTab(tab) }
    }
    private func selectTab(_ tab: Int) {
        guard tab != selectedTab else { return }
        if tab == 1 && store.session == nil { store.startWorkout() }
        if presentedViewController != nil {
            dismiss(animated: true) { [weak self] in self?.showScreen(tab) }
        } else { showScreen(tab) }
    }

    private func showScreen(_ tab: Int) {
        let next: UIViewController
        if tab == 0 {
            next = HomeViewController(store: store) { [weak self] in self?.selectTab(1) }
        } else {
            next = ActiveWorkoutViewController(store: store) { [weak self] in self?.selectTab(0) }
        }
        let previous = screen
        // On visible tab changes, forward appearance transitions through UIKit.
        // Initial appearance is forwarded automatically by the container.
        let visible = view.window != nil
        previous?.willMove(toParent: nil)
        if visible { previous?.beginAppearanceTransition(false, animated: false) }
        addChild(next)
        if visible { next.beginAppearanceTransition(true, animated: false) }
        next.view.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(next.view)
        NSLayoutConstraint.activate([
            next.view.topAnchor.constraint(equalTo: content.topAnchor),
            next.view.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            next.view.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            next.view.trailingAnchor.constraint(equalTo: content.trailingAnchor)
        ])
        previous?.view.removeFromSuperview()
        if visible { previous?.endAppearanceTransition(); next.endAppearanceTransition() }
        previous?.removeFromParent()
        next.didMove(toParent: self)
        screen = next
        selectedTab = tab
        footer?.rootView = tabBar
    }

    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); log("viewWillAppear") }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); log("viewDidAppear") }
    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); log("viewWillDisappear") }
    override func viewDidDisappear(_ animated: Bool) { super.viewDidDisappear(animated); log("viewDidDisappear") }
    private func log(_ method: String) { print("[Lifecycle] MainViewController.\(method)") }
    deinit { print("[Lifecycle] MainViewController.deinit") }
}

private struct WorkoutTabBar: View {
    let selected: Int
    let onSelect: (Int) -> Void
    private let tabs = [("Home", "⌂"), ("Workout", "●"), ("Calendar", "▦"), ("Profile", "○")]
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button { if index < 2 { onSelect(index) } } label: {
                    VStack(spacing: 4) {
                        Text(tabs[index].1).font(.system(size: 22)).frame(height: 25)
                        Text(tabs[index].0).font(.system(size: 11, weight: index == selected ? .bold : .regular))
                    }.frame(maxWidth: .infinity, minHeight: 56)
                }.foregroundStyle(index == selected ? FitTrackStyle.accent : FitTrackStyle.tabMuted)
                    .accessibilityHint(index > 1 ? "Available in a future checkpoint" : "Open \(tabs[index].0)")
                    .accessibilityAddTraits(index == selected ? .isSelected : [])
            }
        }.background(.white).overlay(alignment: .top) { Rectangle().fill(FitTrackStyle.line).frame(height: 1) }
            .preferredColorScheme(.light)
    }
}

struct MainControllerView: UIViewControllerRepresentable {
    let store: WorkoutStore
    func makeUIViewController(context: Context) -> MainViewController { MainViewController(store: store) }
    func updateUIViewController(_ uiViewController: MainViewController, context: Context) { }
}
