import SwiftUI

struct ChatTableViewTuner: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        UIView()
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            guard let tableView = uiView.findChatTableView() else { return }
            let minTopGap: CGFloat = 24
            let gap = max(0, tableView.bounds.height - tableView.contentSize.height)
            let fillerHeight = max(0, gap - minTopGap)
            let desiredInsets = UIEdgeInsets.zero
            if tableView.contentInset != desiredInsets {
                tableView.contentInset = desiredInsets
                tableView.scrollIndicatorInsets = desiredInsets
            }
            if tableView.contentInsetAdjustmentBehavior != .never {
                tableView.contentInsetAdjustmentBehavior = .never
            }
            if #available(iOS 15.0, *) {
                if tableView.sectionHeaderTopPadding != 0 {
                    tableView.sectionHeaderTopPadding = 0
                }
            }
            if tableView.estimatedSectionHeaderHeight != 0 {
                tableView.estimatedSectionHeaderHeight = 0
            }
            if tableView.estimatedSectionFooterHeight != 0 {
                tableView.estimatedSectionFooterHeight = 0
            }
#if DEBUG
            if tableView.tableHeaderView?.frame.height != fillerHeight {
                print("[ChatTableView] filler=\(fillerHeight) gap=\(gap) content=\(tableView.contentSize.height) bounds=\(tableView.bounds.height)")
            }
#endif
            if fillerHeight > 0 {
                if tableView.tableHeaderView?.frame.height != fillerHeight {
                    let spacer = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: fillerHeight))
                    spacer.backgroundColor = .clear
                    tableView.tableHeaderView = spacer
                }
            } else if tableView.tableHeaderView != nil {
                tableView.tableHeaderView = UIView(frame: .zero)
            }
        }
    }
}

private extension UIView {
    func findChatTableView() -> UITableView? {
        let rootViews = window?.subviews ?? [self]
        for root in rootViews {
            if let table = root.findRotatedTableView() {
                return table
            }
        }
        return nil
    }

    func findRotatedTableView() -> UITableView? {
        if let table = self as? UITableView {
            if table.isInverted {
                return table
            }
        }
        for subview in subviews {
            if let match = subview.findRotatedTableView() {
                return match
            }
        }
        return nil
    }
}

private extension UITableView {
    var isInverted: Bool {
        abs(transform.a + 1) < 0.01 && abs(transform.d + 1) < 0.01
    }
}
