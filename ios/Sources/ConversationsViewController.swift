import UIKit
import MessengerShared

final class ConversationsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var conversations: [Conversation] = []
    private var loadError: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Чати"
        view.backgroundColor = DesignTokens.Color.background
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "Знайти", style: .plain, target: self, action: #selector(searchUsers)),
            UIBarButtonItem(title: "Вийти", style: .plain, target: self, action: #selector(signOut)),
        ]
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ConversationCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Task { @MainActor in await reload() }
    }

    private func reload() async {
        do {
            conversations = try await AppServices.repository.loadConversations()
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
        tableView.reloadData()
    }

    @objc private func searchUsers() {
        navigationController?.pushViewController(UserSearchViewController(), animated: true)
    }

    @objc private func signOut() {
        Task { @MainActor in
            do {
                try await AppServices.repository.signOut()
                navigationController?.setViewControllers([RegistrationViewController()], animated: true)
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if conversations.isEmpty { return 1 }
        return conversations.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ConversationCell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        if conversations.isEmpty {
            content.text = loadError == nil ? "«Нотатник» з’явиться після підтвердження email" : "Не вдалося завантажити чати"
            content.secondaryText = loadError
            cell.selectionStyle = .none
        } else {
            let conversation = conversations[indexPath.row]
            content.text = conversation.title.isEmpty ? (conversation.kind == "notes" ? "Нотатник" : "Особистий чат") : conversation.title
            content.secondaryText = conversation.kind == "notes" ? "Твої особисті нотатки" : "Особисте листування"
            content.image = UIImage(systemName: conversation.kind == "notes" ? "note.text" : "bubble.left.and.bubble.right")
            cell.accessoryType = .disclosureIndicator
        }
        cell.contentConfiguration = content
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard conversations.indices.contains(indexPath.row) else { return }
        let conversation = conversations[indexPath.row]
        let fallback = conversation.kind == "notes" ? "Нотатник" : "Особистий чат"
        let title = conversation.title.isEmpty ? fallback : conversation.title
        navigationController?.pushViewController(ConversationViewController(conversationID: conversation.id, title: title), animated: true)
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Помилка", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Добре", style: .default))
        present(alert, animated: true)
    }
}

final class UserSearchViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {
    private let searchBar = UISearchBar()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var results: [UserSearchResult] = []
    private var searchTask: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Пошук людей"
        view.backgroundColor = DesignTokens.Color.background
        searchBar.placeholder = "@нік або ім’я"
        searchBar.autocapitalizationType = .none
        searchBar.delegate = self
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "UserCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchBar)
        view.addSubview(tableView)
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchTask?.cancel()
        guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else {
            results = []
            tableView.reloadData()
            return
        }
        searchTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            do {
                results = try await AppServices.repository.searchUsers(query: searchText)
                tableView.reloadData()
            } catch {
                results = []
                tableView.reloadData()
            }
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { results.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "UserCell", for: indexPath)
        let user = results[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = user.handle
        content.secondaryText = [user.firstName, user.surname].compactMap { $0 }.joined(separator: " ")
        content.image = UIImage(systemName: "person.crop.circle")
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let user = results[indexPath.row]
        Task { @MainActor in
            do {
                let conversationID = try await AppServices.repository.startDirectChat(otherUserId: user.id)
                let chat = ConversationViewController(conversationID: conversationID, title: user.handle)
                navigationController?.pushViewController(chat, animated: true)
            } catch {
                let alert = UIAlertController(title: "Не вдалося відкрити чат", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Добре", style: .default))
                present(alert, animated: true)
            }
        }
    }
}

final class ConversationViewController: UIViewController, UITableViewDataSource {
    private let conversationID: String
    private let titleText: String
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let composer = UITextField()
    private var messages: [Message] = []

    init(conversationID: String, title: String) {
        self.conversationID = conversationID
        self.titleText = title
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = titleText
        view.backgroundColor = DesignTokens.Color.background
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "MessageCell")
        tableView.transform = CGAffineTransform(scaleX: 1, y: -1)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        composer.placeholder = "Повідомлення"
        composer.borderStyle = .roundedRect
        composer.returnKeyType = .send
        composer.delegate = self
        let sendButton = PrimaryButton(title: "Надіслати")
        sendButton.addTarget(self, action: #selector(sendMessage), for: .touchUpInside)
        let input = UIStackView(arrangedSubviews: [composer, sendButton])
        input.axis = .horizontal
        input.spacing = DesignTokens.Spacing.sm
        input.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        view.addSubview(input)
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: input.topAnchor, constant: -DesignTokens.Spacing.sm),
            input.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.md),
            input.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.md),
            input.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -DesignTokens.Spacing.md),
            sendButton.widthAnchor.constraint(equalToConstant: 112),
        ])
        Task { @MainActor in
            do {
                messages = try await AppServices.repository.loadMessages(conversationId: conversationID)
                tableView.reloadData()
            } catch { }
        }
        AppServices.repository.observeMessages(conversationId: conversationID) { [weak self] freshMessages in
            DispatchQueue.main.async {
                self?.messages = freshMessages
                self?.tableView.reloadData()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        AppServices.repository.stopObservingMessages(conversationId: conversationID)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { messages.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let message = messages[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = message.body
        content.textProperties.numberOfLines = 0
        cell.contentConfiguration = content
        cell.transform = CGAffineTransform(scaleX: 1, y: -1)
        return cell
    }

    @objc private func sendMessage() {
        let body = (composer.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        composer.text = nil
        Task { @MainActor in
            do { try await AppServices.repository.sendMessage(conversationId: conversationID, body: body) }
            catch {
                composer.text = body
                let alert = UIAlertController(title: "Не вдалося надіслати", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Добре", style: .default))
                present(alert, animated: true)
            }
        }
    }
}

extension ConversationViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendMessage()
        return true
    }
}
