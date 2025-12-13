import SwiftUI

/// Container view that hosts Trend and Correlation analysis views with a segmented control.
struct AnalysisView: View {
    enum AnalysisTab: String, CaseIterable, Identifiable {
        case trend = "Trend"
        case correlation = "Correlation"
        
        var id: String { rawValue }
    }
    
    @State private var selectedTab: AnalysisTab = .trend
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("Analysis Type", selection: $selectedTab) {
                ForEach(AnalysisTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            
            switch selectedTab {
            case .trend:
                TrendView()
            case .correlation:
                CorrelationAnalysisView()
            }
        }
        .navigationTitle("Analysis")
    }
}

#Preview {
    NavigationView {
        AnalysisView()
    }
}
