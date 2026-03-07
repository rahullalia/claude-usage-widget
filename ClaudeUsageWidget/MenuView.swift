import AppKit

// MARK: - UsageRowView

class UsageRowView: NSView {

    private let nameLabel: NSTextField
    private let progressBar: NSProgressIndicator
    private let percentLabel: NSTextField
    private let resetLabel: NSTextField

    init(label: String) {
        nameLabel = NSTextField(labelWithString: label)
        progressBar = NSProgressIndicator()
        percentLabel = NSTextField(labelWithString: "—%")
        resetLabel = NSTextField(labelWithString: "—")
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    private func setupUI() {
        // Name label
        nameLabel.font = .systemFont(ofSize: 11, weight: .medium)
        nameLabel.textColor = .secondaryLabelColor
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        // Progress bar
        progressBar.style = .bar
        progressBar.minValue = 0
        progressBar.maxValue = 1.0
        progressBar.isIndeterminate = false
        progressBar.doubleValue = 0
        progressBar.translatesAutoresizingMaskIntoConstraints = false

        // Percent label
        percentLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        percentLabel.textColor = .labelColor
        percentLabel.alignment = .right
        percentLabel.translatesAutoresizingMaskIntoConstraints = false

        // Reset label
        resetLabel.font = .systemFont(ofSize: 11, weight: .regular)
        resetLabel.textColor = .tertiaryLabelColor
        resetLabel.alignment = .right
        resetLabel.translatesAutoresizingMaskIntoConstraints = false
        resetLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        // Bottom row: progress + percent + reset
        let bottomRow = NSStackView(views: [progressBar, percentLabel, resetLabel])
        bottomRow.orientation = .horizontal
        bottomRow.spacing = 6
        bottomRow.alignment = .centerY
        bottomRow.translatesAutoresizingMaskIntoConstraints = false

        // Fix percent label width so it doesn't resize
        percentLabel.widthAnchor.constraint(equalToConstant: 34).isActive = true

        // Main stack
        let stack = NSStackView(views: [nameLabel, bottomRow])
        stack.orientation = .vertical
        stack.spacing = 3
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            bottomRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    func update(stat: UsageStat, isSession: Bool) {
        progressBar.doubleValue = stat.percentUsed
        percentLabel.stringValue = String(format: "%.0f%%", stat.percentUsed * 100)
        if isSession {
            resetLabel.stringValue = stat.resetsInDisplay
        } else {
            resetLabel.stringValue = stat.resetsAtDisplay ?? "—"
        }
    }
}

// MARK: - MenuViewController

class MenuViewController: NSViewController {

    // Callbacks set by AppDelegate
    var onRefresh: (() -> Void)?
    var onSignOut: (() -> Void)?

    // MARK: - UI Elements

    private let titleLabel = NSTextField(labelWithString: "Claude Usage")
    private let refreshButton = NSButton()
    private let sessionRow = UsageRowView(label: "Current Session")
    private let weeklyAllRow = UsageRowView(label: "Weekly — All Models")
    private let weeklySonnetRow = UsageRowView(label: "Weekly — Sonnet Only")
    private let lastUpdatedLabel = NSTextField(labelWithString: "Last updated: —")
    private let signOutButton = NSButton(title: "Sign Out", target: nil, action: nil)
    private let quitButton = NSButton(title: "Quit", target: nil, action: nil)
    private let separator1 = NSBox()
    private let separator2 = NSBox()

    // MARK: - View Lifecycle

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 260))
        view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        // Title label
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Refresh button
        refreshButton.bezelStyle = .inline
        refreshButton.title = "↻"
        refreshButton.font = .systemFont(ofSize: 14, weight: .regular)
        refreshButton.isBordered = false
        refreshButton.target = self
        refreshButton.action = #selector(refreshTapped)
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        refreshButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        // Header row
        let headerRow = NSStackView(views: [titleLabel, refreshButton])
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.distribution = .fill
        headerRow.translatesAutoresizingMaskIntoConstraints = false

        // Separators
        separator1.boxType = .separator
        separator1.translatesAutoresizingMaskIntoConstraints = false

        separator2.boxType = .separator
        separator2.translatesAutoresizingMaskIntoConstraints = false

        // Last updated
        lastUpdatedLabel.font = .systemFont(ofSize: 10, weight: .regular)
        lastUpdatedLabel.textColor = .tertiaryLabelColor
        lastUpdatedLabel.translatesAutoresizingMaskIntoConstraints = false

        // Sign Out button
        signOutButton.bezelStyle = .inline
        signOutButton.isBordered = false
        signOutButton.font = .systemFont(ofSize: 12, weight: .regular)
        signOutButton.contentTintColor = .secondaryLabelColor
        signOutButton.target = self
        signOutButton.action = #selector(signOutTapped)
        signOutButton.translatesAutoresizingMaskIntoConstraints = false

        // Quit button
        quitButton.bezelStyle = .inline
        quitButton.isBordered = false
        quitButton.font = .systemFont(ofSize: 12, weight: .regular)
        quitButton.contentTintColor = .secondaryLabelColor
        quitButton.target = self
        quitButton.action = #selector(quitTapped)
        quitButton.translatesAutoresizingMaskIntoConstraints = false

        // Footer row
        let footerRow = NSStackView(views: [signOutButton, NSView(), quitButton])
        footerRow.orientation = .horizontal
        footerRow.alignment = .centerY
        footerRow.distribution = .fill
        footerRow.translatesAutoresizingMaskIntoConstraints = false

        // Row views
        [sessionRow, weeklyAllRow, weeklySonnetRow].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        // Main vertical stack
        let mainStack = NSStackView(views: [
            headerRow,
            separator1,
            sessionRow,
            weeklyAllRow,
            weeklySonnetRow,
            lastUpdatedLabel,
            separator2,
            footerRow,
        ])
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.distribution = .fill
        mainStack.spacing = 8
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        // Separators need full width
        separator1.widthAnchor.constraint(equalTo: mainStack.widthAnchor).isActive = true
        separator2.widthAnchor.constraint(equalTo: mainStack.widthAnchor).isActive = true
        headerRow.widthAnchor.constraint(equalTo: mainStack.widthAnchor).isActive = true
        footerRow.widthAnchor.constraint(equalTo: mainStack.widthAnchor).isActive = true

        view.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            mainStack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -10),
        ])
    }

    // MARK: - Public Update Methods

    func update(with data: UsageData) {
        sessionRow.update(stat: data.currentSession, isSession: true)
        weeklyAllRow.update(stat: data.weeklyAllModels, isSession: false)
        weeklySonnetRow.update(stat: data.weeklySonnetOnly, isSession: false)

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        lastUpdatedLabel.stringValue = "Last updated: " + formatter.localizedString(for: data.lastUpdated, relativeTo: Date())
    }

    func showLoading() {
        lastUpdatedLabel.stringValue = "Fetching usage..."
    }

    func showError(_ message: String) {
        lastUpdatedLabel.stringValue = "Error: \(message)"
    }

    // MARK: - Actions

    @objc private func refreshTapped() { onRefresh?() }
    @objc private func signOutTapped() { onSignOut?() }
    @objc private func quitTapped() { NSApp.terminate(nil) }
}
