import SwiftUI

// MARK: - Reusable UI Components

public struct SidebarButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false

    public init(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Glowing left accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected
                        ? LinearGradient(colors: [Color.orange, Color.red], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [Color.clear, Color.clear], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 3, height: 18)
                    .shadow(color: isSelected ? Color.orange.opacity(0.7) : Color.clear, radius: 4)

                Image(systemName: icon)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(
                        isSelected
                            ? LinearGradient(colors: [Color.orange, Color.red], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Color.gray.opacity(0.7), Color.gray.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 15)

                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : Color(white: 0.55))
                    .lineLimit(1)

                Spacer()
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 6)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.13), Color.red.opacity(0.07)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(Color.orange.opacity(0.18), lineWidth: 0.5)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.white.opacity(isPressed ? 0.04 : 0.0))
                    }
                }
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeOut(duration: 0.1)) { isPressed = true } }
                .onEnded { _ in withAnimation(.easeOut(duration: 0.15)) { isPressed = false } }
        )
    }
}


public struct ConstraintBullet: View {
    let text: String
    
    public init(text: String) {
        self.text = text
    }
    
    public var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.orange)
            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.65))
        }
    }
}


public struct FieldRow: View {
    let name: String
    let type: String
    let value: String
    
    public init(name: String, type: String, value: String) {
        self.name = name
        self.type = type
        self.value = value
    }
    
    public var body: some View {
        HStack {
            Text(name)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.95))
            Text(":")
                .foregroundColor(.gray)
                .font(.system(size: 9))
            Text(type)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.blue.opacity(0.7))
            Spacer()
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.orange)
        }
    }
}

public struct LineConnector: View {
    let isActive: Bool
    let isForward: Bool
    
    @State private var offset: CGFloat = 0.0
    
    public init(isActive: Bool, isForward: Bool) {
        self.isActive = isActive
        self.isForward = isForward
    }
    
    public var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.12))
                .frame(height: 2)
            
            if isActive {
                Circle()
                    .fill(isForward ? Color.orange : Color.blue)
                    .frame(width: 4, height: 4)
                    .shadow(color: isForward ? Color.orange : Color.blue, radius: 2)
                    .offset(x: offset)
                    .onAppear {
                        offset = isForward ? -15.0 : 15.0
                        withAnimation(Animation.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                            offset = isForward ? 15.0 : -15.0
                        }
                    }
                    .onDisappear {
                        offset = 0.0
                    }
            }
        }
        .frame(width: 30, height: 20)
    }
}

public struct DSARunButton: View {
    let isRunning: Bool
    let action: () -> Void

    public init(isRunning: Bool, action: @escaping () -> Void) {
        self.isRunning = isRunning
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isRunning {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10, weight: .bold))
                }
                Text(isRunning ? "Running..." : "Run Code")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [Color.green.opacity(0.85), Color.teal.opacity(0.75)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shadow(color: Color.green.opacity(0.3), radius: 5, x: 0, y: 2)
        }
        .disabled(isRunning)
        .buttonStyle(PlainButtonStyle())
    }
}
