import UIKit

final class StandardTextField: UITextField {
    init(placeholder: String) {
        super.init(frame: .zero)
        self.placeholder = placeholder
        borderStyle = .roundedRect
        autocorrectionType = .no
        heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        font = .preferredFont(forTextStyle: .body)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
