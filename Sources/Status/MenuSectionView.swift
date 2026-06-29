import AppKit

/// 菜单内一个区块视图：标题 + 详情值。手写 frame 布局，避免 autolayout 在菜单里的边角问题。
@MainActor
final class MenuSectionView: NSView {
    private let titleField: NSTextField
    private let valueField: NSTextField

    static let width: CGFloat = 280
    static let height: CGFloat = 44

    init(title: String) {
        titleField = NSTextField(labelWithString: title)
        valueField = NSTextField(labelWithString: "")
        super.init(frame: NSRect(x: 0, y: 0, width: Self.width, height: Self.height))

        for field in [titleField, valueField] {
            field.isBezeled = false
            field.drawsBackground = false
            field.isEditable = false
            field.isSelectable = false
        }
        titleField.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        titleField.textColor = .secondaryLabelColor
        valueField.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        valueField.textColor = .labelColor

        addSubview(titleField)
        addSubview(valueField)

        let inset: CGFloat = 14
        titleField.frame = NSRect(x: inset, y: Self.height - 20,
                                  width: Self.width - inset * 2, height: 14)
        valueField.frame = NSRect(x: inset, y: 8,
                                  width: Self.width - inset * 2, height: 20)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setValue(_ text: String) {
        valueField.stringValue = text
    }
}
