import SwiftUI

// MARK: - Reusable UI Components

public struct SidebarButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    public init(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                // Subtle vertical accent bar on the left edge
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isSelected ? Color.orange : Color.clear)
                    .frame(width: 3, height: 16)
                    .shadow(color: isSelected ? Color.orange.opacity(0.4) : Color.clear, radius: 2)
                
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(isSelected ? Color.orange : .gray)
                    .frame(width: 16)
                    .padding(.leading, 4)
                
                Text(title)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .white : .gray.opacity(0.85))
                
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.trailing, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.white.opacity(0.06) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
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

public struct ConceptBullet: View {
    let title: String
    let text: String
    
    public init(title: String, text: String) {
        self.title = title
        self.text = text
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 11))
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            Text(text)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.55))
                .padding(.leading, 17)
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
                        withAnimation(Animation.linear(duration: 0.7).repeatForever(autoreverses: false)) {
                            offset = isForward ? 15.0 : -15.0
                        }
                    }
                    .onDisappear {
                        offset = 0.0
                    }
            }
        }
        .frame(width: 30)
    }
}
