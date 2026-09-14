import SwiftUI
import AppKit

/// Segmented control that fills the width it is given.
///
/// SwiftUI's `.pickerStyle(.segmented)` sizes itself to its labels and centres
/// inside whatever frame it is handed, so `.frame(maxWidth: .infinity)` widens
/// the frame but not the control. `NSSegmentedControl` can distribute its
/// segments across the full width, which SwiftUI does not expose.
struct FilledSegmentedPicker<Value: Hashable>: NSViewRepresentable {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value
    var isEnabled: Bool = true
    var accessibilityLabel: String

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl(
            labels: options.map(\.title),
            trackingMode: .selectOne,
            target: context.coordinator,
            action: #selector(Coordinator.selectionChanged(_:))
        )
        control.segmentDistribution = .fillEqually
        control.setAccessibilityLabel(accessibilityLabel)
        // Let the surrounding layout stretch it rather than hug its labels.
        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        control.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        context.coordinator.parent = self

        if let index = options.firstIndex(where: { $0.value == selection }) {
            control.selectedSegment = index
        }
        control.isEnabled = isEnabled
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject {
        var parent: FilledSegmentedPicker

        init(_ parent: FilledSegmentedPicker) { self.parent = parent }

        @objc func selectionChanged(_ sender: NSSegmentedControl) {
            let index = sender.selectedSegment
            guard parent.options.indices.contains(index) else { return }
            parent.selection = parent.options[index].value
        }
    }
}
