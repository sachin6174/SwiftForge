import SwiftUI

public struct SidebarView: View {
    @ObservedObject var appState: AppState
    let onDSASelect: (Question) -> Void
    let onSwiftSelect: (Question) -> Void
    
    public init(appState: AppState, onDSASelect: @escaping (Question) -> Void, onSwiftSelect: @escaping (Question) -> Void) {
        self.appState = appState
        self.onDSASelect = onDSASelect
        self.onSwiftSelect = onSwiftSelect
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Logo Banner
            HStack(spacing: 10) {
                Image(systemName: "swift")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.orange, Color.red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.orange.opacity(0.4), radius: 6)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("SwiftPrep")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Interview Practice")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 24)
            
            Divider()
                .background(Color.gray.opacity(0.2))
                .padding(.horizontal, 12)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // DSA Group
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DSA CHALLENGES")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 12)
                        
                        ForEach(appState.dsaQuestions) { question in
                            let isSelected = appState.selectedTab == .dsa && appState.selectedDSAQuestion?.id == question.id
                            
                            SidebarButton(
                                title: question.title,
                                icon: "square.grid.3x3.fill",
                                isSelected: isSelected
                            ) {
                                appState.selectedTab = .dsa
                                appState.selectedDSAQuestion = question
                                onDSASelect(question)
                            }
                        }
                    }
                    
                    // Swift Group
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SWIFT BASICS")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 12)
                        
                        ForEach(appState.swiftQuestions) { question in
                            let isSelected = appState.selectedTab == .swiftPractice && appState.selectedSwiftQuestion?.id == question.id
                            
                            SidebarButton(
                                title: question.title,
                                icon: "network",
                                isSelected: isSelected
                            ) {
                                appState.selectedTab = .swiftPractice
                                appState.selectedSwiftQuestion = question
                                onSwiftSelect(question)
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            
            Spacer()
            
            // Footer Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .shadow(color: Color.green.opacity(0.6), radius: 3)
                    Text("Local Compiler")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.8))
                }
                Text("Version 6.0 | Resilient DB")
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .frame(width: 200)
        .background(Color(red: 0.08, green: 0.09, blue: 0.12))
    }
}
