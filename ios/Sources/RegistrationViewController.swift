import UIKit
import MessengerShared

final class RegistrationViewController: UIViewController {
    private let handle = StandardTextField(placeholder: "@нікнейм")
    private let firstName = StandardTextField(placeholder: "Ім’я")
    private let surname = StandardTextField(placeholder: "Прізвище · необов’язково")
    private let email = StandardTextField(placeholder: "Електронна пошта")
    private let password = StandardTextField(placeholder: "Пароль")
    private let birthDate = StandardTextField(placeholder: "Дата народження")
    private let primaryButton = PrimaryButton(title: "Створити акаунт")
    private let switchButton = UIButton(type: .system)
    private let status = UILabel()
    private let stack = UIStackView()
    private var registering = true
    private var selectedBirthDate = Date()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Mova"
        view.backgroundColor = DesignTokens.Color.background
        configureFields()
        configureLayout()
        updateForm()
    }

    private func configureFields() {
        email.keyboardType = .emailAddress
        email.textContentType = .emailAddress
        email.autocapitalizationType = .none
        email.autocorrectionType = .no
        password.isSecureTextEntry = true
        password.textContentType = .newPassword
        handle.autocapitalizationType = .none
        handle.autocorrectionType = .no
        firstName.textContentType = .givenName
        surname.textContentType = .familyName
        birthDate.inputView = datePicker
        birthDate.text = formatter.string(from: selectedBirthDate)
        primaryButton.addTarget(self, action: #selector(submit), for: .touchUpInside)
        switchButton.addTarget(self, action: #selector(toggleMode), for: .touchUpInside)
        [handle, firstName, surname, email, password, birthDate].forEach { $0.addTarget(self, action: #selector(validateForm), for: .editingChanged) }
        status.textColor = DesignTokens.Color.secondaryText
        status.font = .preferredFont(forTextStyle: .footnote)
        status.numberOfLines = 0
    }

    private lazy var datePicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .wheels
        picker.maximumDate = Date()
        picker.addTarget(self, action: #selector(dateChanged(_:)), for: .valueChanged)
        return picker
    }()

    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private func configureLayout() {
        let scroll = UIScrollView()
        scroll.keyboardDismissMode = .interactive
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.md
        stack.translatesAutoresizingMaskIntoConstraints = false
        let heading = UILabel()
        heading.font = .preferredFont(forTextStyle: .largeTitle).withWeight(.bold)
        heading.text = "Твій простір для розмов"
        heading.numberOfLines = 0
        let subtitle = UILabel()
        subtitle.font = .preferredFont(forTextStyle: .body)
        subtitle.textColor = DesignTokens.Color.secondaryText
        subtitle.text = "Створи акаунт або повернись до своїх чатів."
        subtitle.numberOfLines = 0
        [heading, subtitle, handle, firstName, surname, email, password, birthDate, primaryButton, switchButton, status].forEach(stack.addArrangedSubview)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: DesignTokens.Spacing.xl),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -DesignTokens.Spacing.xl),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: DesignTokens.Spacing.xl),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -DesignTokens.Spacing.xl),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -2 * DesignTokens.Spacing.xl),
        ])
    }

    private func updateForm() {
        title = registering ? "Створити акаунт" : "Увійти"
        handle.isHidden = !registering
        firstName.isHidden = !registering
        surname.isHidden = !registering
        birthDate.isHidden = !registering
        primaryButton.setTitle(registering ? "Створити акаунт" : "Увійти", for: .normal)
        switchButton.setTitle(registering ? "Уже маєш акаунт? Увійти" : "Створити новий акаунт", for: .normal)
        password.textContentType = registering ? .newPassword : .password
        validateForm()
    }

    @objc private func toggleMode() {
        registering.toggle()
        status.text = nil
        updateForm()
    }

    @objc private func dateChanged(_ picker: UIDatePicker) {
        selectedBirthDate = picker.date
        birthDate.text = formatter.string(from: picker.date)
        validateForm()
    }

    @objc private func validateForm() {
        let emailIsValid = email.text?.contains("@") == true && email.text?.contains(".") == true
        let passwordIsValid = (password.text?.count ?? 0) >= 8
        let profileIsValid = !registering || (
            normalizedHandle != nil && !(firstName.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
        primaryButton.isEnabled = emailIsValid && passwordIsValid && profileIsValid && !isBusy
    }

    private var normalizedHandle: String? {
        let raw = (handle.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = raw.hasPrefix("@") ? raw : "@" + raw
        guard candidate.range(of: "^@[A-Za-z0-9_]{3,24}$", options: .regularExpression) != nil else { return nil }
        return candidate.lowercased()
    }

    private var isBusy = false

    @objc private func submit() {
        guard !isBusy else { return }
        isBusy = true
        validateForm()
        status.text = "Під’єднуюся до Mova…"
        let cleanEmail = (email.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPassword = password.text ?? ""
        Task { @MainActor in
            do {
                if registering {
                    try await AppServices.repository.signUp(
                        email: cleanEmail,
                        password: cleanPassword,
                        handle: normalizedHandle ?? "",
                        firstName: (firstName.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                        surname: (surname.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : surname.text,
                        birthDate: birthDate.text ?? formatter.string(from: selectedBirthDate)
                    )
                    if AppServices.repository.currentUserId == nil {
                        status.text = "Лист підтвердження надіслано. Відкрий його, щоб активувати профіль і створити «Нотатник»."
                    } else {
                        showConversations()
                    }
                } else {
                    try await AppServices.repository.signIn(email: cleanEmail, password: cleanPassword)
                    showConversations()
                }
            } catch {
                status.text = error.localizedDescription
            }
            isBusy = false
            validateForm()
        }
    }

    private func showConversations() {
        navigationController?.setViewControllers([ConversationsViewController()], animated: true)
    }
}

private extension UIFont {
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        UIFont.systemFont(ofSize: pointSize, weight: weight)
    }
}
