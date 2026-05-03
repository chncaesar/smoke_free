import SwiftUI

struct ProgressRingView: View {
    let progress: Double
    var size: CGFloat = 60
    var lineWidth: CGFloat = 6
    var color: Color = .green

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: progress)
        }
        .frame(width: size, height: size)
    }
}
