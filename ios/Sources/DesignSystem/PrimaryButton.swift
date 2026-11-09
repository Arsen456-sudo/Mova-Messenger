import UIKit

final class PrimaryButton: UIButton {
    init(title: String) {
        super.init(frame: .zero)
        var config = UIButton.Configuration.filled()
        config.title = title
        config.cornerStyle = .large
        config.baseBackgroundColor = DesignTokens.Color.accent
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18)
        configuration = config
        titleLabel?.font = .preferredFont(forTextStyle: .headline)
        heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
