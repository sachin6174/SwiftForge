import SwiftUI

public struct MatrixVisualizerView: View {
    let matrix: [[Character]]
    
    public init(matrix: [[Character]]) {
        self.matrix = matrix
    }
    
    public var body: some View {
        let maxSquare = findMaximalSquareCoordinates(in: matrix)
        
        VStack(spacing: 4) {
            if matrix.isEmpty {
                Text("Empty Matrix")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                    .frame(height: 60)
            } else {
                ForEach(0..<matrix.count, id: \.self) { r in
                    HStack(spacing: 4) {
                        ForEach(0..<matrix[r].count, id: \.self) { c in
                            let isOne = matrix[r][c] == "1"
                            let isInMaxSquare = checkIfInSquare(r: r, c: c, maxSquare: maxSquare)
                            
                            // Precompute layout values to prevent compiler type-check timeout
                            let fgColor: Color = isOne ? .white : .secondary
                            let cellBgColor: Color = isInMaxSquare ? Color.orange.opacity(0.85) : (isOne ? Color.blue.opacity(0.3) : Color.gray.opacity(0.15))
                            let cellStrokeColor: Color = isInMaxSquare ? Color.orange : (isOne ? Color.blue : Color.gray.opacity(0.3))
                            let strokeWidth: CGFloat = isInMaxSquare ? 2.0 : 1.0
                            let shadowColor: Color = isInMaxSquare ? Color.orange.opacity(0.6) : Color.clear
                            
                            Text(String(matrix[r][c]))
                                .font(.system(.caption, design: .monospaced))
                                .bold()
                                .foregroundColor(fgColor)
                                .frame(width: 24, height: 24)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(cellBgColor)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(cellStrokeColor, lineWidth: strokeWidth)
                                )
                                .shadow(color: shadowColor, radius: 4)
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.2))
        .cornerRadius(8)
    }
    
    func checkIfInSquare(r: Int, c: Int, maxSquare: (row: Int, col: Int, size: Int)?) -> Bool {
        guard let sq = maxSquare else { return false }
        return r >= sq.row && r < sq.row + sq.size && c >= sq.col && c < sq.col + sq.size
    }
    
    func findMaximalSquareCoordinates(in matrix: [[Character]]) -> (row: Int, col: Int, size: Int)? {
        guard !matrix.isEmpty else { return nil }
        let m = matrix.count
        let n = matrix[0].count
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        var maxLen = 0
        var maxRow = 0
        var maxCol = 0
        
        for i in 1...m {
            for j in 1...n {
                if matrix[i - 1][j - 1] == "1" {
                    dp[i][j] = min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]) + 1
                    if dp[i][j] > maxLen {
                        maxLen = dp[i][j]
                        maxRow = i - 1
                        maxCol = j - 1
                    }
                }
            }
        }
        
        if maxLen == 0 { return nil }
        return (maxRow - maxLen + 1, maxCol - maxLen + 1, maxLen)
    }
}
