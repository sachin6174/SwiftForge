import SwiftUI

/// A brief, tasteful celebration shown the first time a question is solved:
/// a confetti burst radiating from center plus a bouncing checkmark badge,
/// both auto-dismissing. Purely an overlay — it can't disturb the layout
/// underneath, and `allowsHitTesting(false)` keeps it from ever blocking a
/// click on the real UI.
public struct SolvedCelebrationView: View {
    let accentColor: Color

    @State private var badgeScale: CGFloat = 0.4
    @State private var badgeOpacity: Double = 0
    @State private var particles: [ConfettiParticle] = ConfettiParticle.burst(count: 20)

    public init(accentColor: Color) {
        self.accentColor = accentColor
    }

    public var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color(accent: accentColor))
                    .frame(width: particle.size, height: particle.size)
                    .offset(x: particle.settled ? particle.dx : 0, y: particle.settled ? particle.dy : 0)
                    .opacity(particle.settled ? 0 : 1)
                    .rotationEffect(.degrees(particle.settled ? particle.spin : 0))
            }

            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [accentColor, accentColor.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 64, height: 64)
                        .shadow(color: accentColor.opacity(0.65), radius: 18)
                    Image(systemName: "checkmark")
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(.white)
                }

                Text("Solved!")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
            }
            .scaleEffect(badgeScale)
            .opacity(badgeOpacity)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.bouncy) {
                badgeScale = 1.0
                badgeOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.9)) {
                for i in particles.indices { particles[i].settled = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    badgeOpacity = 0
                    badgeScale = 0.85
                }
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let hueIndex: Int
    let size: CGFloat
    let dx: CGFloat
    let dy: CGFloat
    let spin: Double
    var settled = false

    func color(accent: Color) -> Color {
        [accent, .yellow, .white, .green, .pink][hueIndex % 5]
    }

    static func burst(count: Int) -> [ConfettiParticle] {
        (0..<count).map { i in
            let angle = (Double(i) / Double(count)) * 2 * .pi + Double.random(in: -0.18...0.18)
            let distance = CGFloat.random(in: 70...150)
            return ConfettiParticle(
                hueIndex: i,
                size: CGFloat.random(in: 5...9),
                dx: cos(angle) * distance,
                dy: sin(angle) * distance,
                spin: Double.random(in: -180...180)
            )
        }
    }
}
