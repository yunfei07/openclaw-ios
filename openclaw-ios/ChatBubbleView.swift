import SwiftUI

struct ChatBubbleView<Content: View>: View {
    let isOutgoing: Bool
    let showTail: Bool
    let content: Content

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var maxBubbleWidth: CGFloat {
        horizontalSizeClass == .regular ? 420 : 300
    }
    private var tailWidth: CGFloat { showTail ? 8 : 0 }
    private var tailHeight: CGFloat { showTail ? 10 : 0 }
    private var tailTipInset: CGFloat { showTail ? 1.5 : 0 }

    init(isOutgoing: Bool, showTail: Bool, @ViewBuilder content: () -> Content) {
        self.isOutgoing = isOutgoing
        self.showTail = showTail
        self.content = content()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            bubbleBody
                .fixedSize(horizontal: true, vertical: true)
            bubbleBody
                .frame(maxWidth: maxBubbleWidth, alignment: .leading)
        }
    }

    private var bubbleBody: some View {
        content
            .padding(.vertical, 8)
            .padding(.leading, isOutgoing ? 12 : 12 + tailWidth)
            .padding(.trailing, isOutgoing ? 12 + tailWidth : 12)
            .background(bubbleFill)
            .clipShape(bubbleShape)
            .overlay(
                bubbleShape
                    .stroke(bubbleBorder, lineWidth: 0.6)
            )
            .shadow(color: ChatUIStyle.bubbleShadow, radius: 2, x: 0, y: 1)
    }

    private var bubbleFill: Color {
        isOutgoing ? ChatUIStyle.bubbleOutgoing : ChatUIStyle.bubbleIncoming
    }

    private var bubbleBorder: Color {
        isOutgoing ? ChatUIStyle.bubbleOutgoingBorder : ChatUIStyle.bubbleIncomingBorder
    }

    private var bubbleShape: BubbleShape {
        BubbleShape(
            isOutgoing: isOutgoing,
            cornerRadius: ChatUIStyle.bubbleRadius,
            tailSize: CGSize(width: tailWidth, height: tailHeight),
            tailTipInset: tailTipInset
        )
    }
}

private struct BubbleShape: Shape {
    let isOutgoing: Bool
    let cornerRadius: CGFloat
    let tailSize: CGSize
    let tailTipInset: CGFloat

    func path(in rect: CGRect) -> Path {
        let tailWidth = tailSize.width
        let tailHeight = tailSize.height
        let radius = min(cornerRadius, min(rect.width, rect.height) * 0.5)
        let bubbleRect: CGRect
        if isOutgoing {
            bubbleRect = CGRect(
                x: rect.minX,
                y: rect.minY,
                width: rect.width - tailWidth,
                height: rect.height
            )
        } else {
            bubbleRect = CGRect(
                x: rect.minX + tailWidth,
                y: rect.minY,
                width: rect.width - tailWidth,
                height: rect.height
            )
        }
        let left = bubbleRect.minX
        let right = bubbleRect.maxX
        let top = bubbleRect.minY
        let bottom = bubbleRect.maxY
        let midY = bubbleRect.midY
        var path = Path()
        if isOutgoing {
            path.move(to: CGPoint(x: left + radius, y: top))
            path.addLine(to: CGPoint(x: right - radius, y: top))
            path.addArc(
                center: CGPoint(x: right - radius, y: top + radius),
                radius: radius,
                startAngle: .degrees(-90),
                endAngle: .degrees(0),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: right, y: midY - tailHeight / 2))
            path.addQuadCurve(
                to: CGPoint(x: right + tailWidth, y: midY),
                control: CGPoint(x: right + tailWidth - tailTipInset, y: midY - tailTipInset)
            )
            path.addQuadCurve(
                to: CGPoint(x: right, y: midY + tailHeight / 2),
                control: CGPoint(x: right + tailWidth - tailTipInset, y: midY + tailTipInset)
            )
            path.addLine(to: CGPoint(x: right, y: bottom - radius))
            path.addArc(
                center: CGPoint(x: right - radius, y: bottom - radius),
                radius: radius,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: left + radius, y: bottom))
            path.addArc(
                center: CGPoint(x: left + radius, y: bottom - radius),
                radius: radius,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: left, y: top + radius))
            path.addArc(
                center: CGPoint(x: left + radius, y: top + radius),
                radius: radius,
                startAngle: .degrees(180),
                endAngle: .degrees(270),
                clockwise: false
            )
        } else {
            path.move(to: CGPoint(x: left + radius, y: top))
            path.addLine(to: CGPoint(x: right - radius, y: top))
            path.addArc(
                center: CGPoint(x: right - radius, y: top + radius),
                radius: radius,
                startAngle: .degrees(-90),
                endAngle: .degrees(0),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: right, y: bottom - radius))
            path.addArc(
                center: CGPoint(x: right - radius, y: bottom - radius),
                radius: radius,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: left + radius, y: bottom))
            path.addArc(
                center: CGPoint(x: left + radius, y: bottom - radius),
                radius: radius,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: left, y: midY + tailHeight / 2))
            path.addQuadCurve(
                to: CGPoint(x: left - tailWidth, y: midY),
                control: CGPoint(x: left - tailWidth + tailTipInset, y: midY + tailTipInset)
            )
            path.addQuadCurve(
                to: CGPoint(x: left, y: midY - tailHeight / 2),
                control: CGPoint(x: left - tailWidth + tailTipInset, y: midY - tailTipInset)
            )
            path.addLine(to: CGPoint(x: left, y: top + radius))
            path.addArc(
                center: CGPoint(x: left + radius, y: top + radius),
                radius: radius,
                startAngle: .degrees(180),
                endAngle: .degrees(270),
                clockwise: false
            )
        }
        path.closeSubpath()
        return path
    }
}
