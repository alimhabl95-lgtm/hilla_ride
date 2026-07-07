import SwiftUI

struct WelcomeSplashView: View {
    let onFinished: () -> Void

    @EnvironmentObject private var appState: AppState
    @State private var startDate = Date()

    private let totalDuration: TimeInterval = 3.4

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let vehicleWidth = size.width * 0.44

            TimelineView(.animation) { timeline in
                let elapsed = timeline.date.timeIntervalSince(startDate)
                let frac = min(max(elapsed / totalDuration, 0), 1)

                let drive = easeInOutCubic(progress(frac, from: 0.05, to: 0.82))
                let textReveal = easeOutCubic(progress(frac, from: 0.45, to: 0.78))
                let fadeOut = 1 - easeOut(progress(frac, from: 0.86, to: 1))

                let startX = -vehicleWidth * 1.1
                let endX = size.width * 0.5 - vehicleWidth * 0.5
                let vehicleX = startX + (endX - startX) * drive

                ZStack {
                    Color.white

                    diagonalBands(size: size)

                    roadCanvas(size: size, roadOffset: drive * size.width * 1.6)
                        .frame(width: size.width, height: size.height * 0.3)
                        .frame(maxHeight: .infinity, alignment: .bottom)

                    Image("AppLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: vehicleWidth, height: vehicleWidth)
                        .position(x: vehicleX + vehicleWidth / 2, y: size.height * 0.77 - vehicleWidth / 2)

                    VStack(spacing: 8) {
                        Text(L10n.string(.welcomeMessage, language: appState.language))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(BrandColors.navy)
                        Text(L10n.string(.appTitle, language: appState.language))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(BrandColors.tealDark)
                    }
                    .multilineTextAlignment(.center)
                    .opacity(textReveal)
                    .offset(y: (1 - textReveal) * 18)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, size.height * 0.08)
                }
                .opacity(fadeOut)
                .ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startDate = Date()
            Task {
                try? await Task.sleep(nanoseconds: UInt64(totalDuration * 1_000_000_000))
                onFinished()
            }
        }
    }

    private func diagonalBands(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height

            var gold = Path()
            gold.move(to: CGPoint(x: 0, y: h * 0.52))
            gold.addLine(to: CGPoint(x: w, y: h * 0.34))
            gold.addLine(to: CGPoint(x: w, y: h))
            gold.addLine(to: CGPoint(x: 0, y: h))
            gold.closeSubpath()
            context.fill(gold, with: .color(BrandColors.gold.opacity(0.14)))

            var teal = Path()
            teal.move(to: CGPoint(x: 0, y: h * 0.7))
            teal.addLine(to: CGPoint(x: w, y: h * 0.56))
            teal.addLine(to: CGPoint(x: w, y: h))
            teal.addLine(to: CGPoint(x: 0, y: h))
            teal.closeSubpath()
            context.fill(teal, with: .color(BrandColors.teal.opacity(0.1)))
        }
    }

    private func roadCanvas(size: CGSize, roadOffset: CGFloat) -> some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height

            context.fill(Path(CGRect(origin: .zero, size: canvasSize)), with: .color(BrandColors.surface))

            var edge = Path()
            edge.move(to: CGPoint(x: 0, y: h * 0.08))
            edge.addLine(to: CGPoint(x: w, y: h * 0.08))
            context.stroke(edge, with: .color(BrandColors.teal.opacity(0.22)), lineWidth: 2)

            let dashWidth: CGFloat = 22
            let dashGap: CGFloat = 16
            let y = h * 0.42
            var x = -(roadOffset.truncatingRemainder(dividingBy: dashWidth + dashGap))
            while x < w + dashWidth {
                var dash = Path()
                dash.move(to: CGPoint(x: x, y: y))
                dash.addLine(to: CGPoint(x: x + dashWidth, y: y))
                context.stroke(
                    dash,
                    with: .color(BrandColors.teal.opacity(0.45)),
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                )
                x += dashWidth + dashGap
            }
        }
    }

    private func progress(_ value: Double, from: Double, to: Double) -> Double {
        guard to > from else { return value >= to ? 1 : 0 }
        return min(max((value - from) / (to - from), 0), 1)
    }

    private func easeInOutCubic(_ t: Double) -> Double {
        t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
    }

    private func easeOutCubic(_ t: Double) -> Double {
        1 - pow(1 - t, 3)
    }

    private func easeOut(_ t: Double) -> Double {
        1 - pow(1 - t, 2)
    }
}

struct WelcomeSplashGate<Content: View>: View {
    @AppStorage("welcome_splash_seen") private var welcomeSplashSeen = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        if welcomeSplashSeen {
            content()
        } else {
            WelcomeSplashView {
                welcomeSplashSeen = true
            }
        }
    }
}
