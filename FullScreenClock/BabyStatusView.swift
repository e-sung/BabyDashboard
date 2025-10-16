//
//  BabyStatusView.swift
//  FullScreenClock
//
//  Created by 류성두 on 10/15/25.
//

import SwiftUI
import Then

struct BabyStatusView2: View {
    @ObservedObject var babyState: BabyState
    @Binding var isFeedAnimating: Bool
    @Binding var isDiaperAnimating: Bool
    let onFeedTimeTap: () -> Void
    let onDiaperTap: () -> Void
    let onNameTap: () -> Void

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private var feedingTime: String {
        if let date = babyState.feedState.feededAt { return timeFormatter.string(from: date) }
        return String(localized: "--:--")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: -8) {
            Text("\(babyState.profile.name)")
                .font(.system(size: 40))
                .fontWeight(.bold)
                .onTapGesture(perform: onNameTap)
            VStack(alignment: .leading, spacing: 6) {
                feedStateView
                diaperStateView
            }
            .font(.system(size: 60))
        }
    }

    var feedStateView: some View {
        HStack(alignment: .center) {
            Text("🍼")
                .font(.system(size: 50))
            VStack(alignment: .leading) {
                Text(feedingTime)
                    .fontWeight(.heavy)
                    .foregroundColor(babyState.feedState.shouldWarn ? .red : .primary)
                Text(babyState.feedState.elapsedTimeFormatted)
                    .font(.title)
            }
        }
        .onTapGesture {
            onFeedTimeTap()
        }
        .scaleEffect(isFeedAnimating ? 0.9 : 1)
        .animation(.easeInOut(duration: 0.3), value: isFeedAnimating)
    }

    private var diaperImageSize: CGFloat {
        return 50
    }

    var diaperStateView: some View {
        HStack(alignment: .center, spacing: 15) {
            Image("diaper")
                .resizable()
                .frame(width: diaperImageSize, height: diaperImageSize)
                .foregroundStyle(.primary)
            Text(babyState.diaperState.elapsedTimeFormatted)
                .fontWeight(babyState.diaperState.shouldWarn ? .heavy : .regular)
                .font(.title)
                .foregroundStyle(babyState.diaperState.shouldWarn ? .yellow : .primary)
        }
        .onTapGesture {
            onDiaperTap()
        }
        .scaleEffect(isDiaperAnimating ? 0.9 : 1)
        .animation(.easeInOut(duration: 0.3), value: isDiaperAnimating)
    }
}


#Preview {
    HStack(spacing: 200) {
        BabyStatusView2(
            babyState: BabyState(
                profile: BabyProfile(id: UUID(), name: "연두"),
                feedState: FeedState(feededAt: Date.now.addingTimeInterval(-3840)), diaperState: DiaperState(diaperChangedAt: Date.now.addingTimeInterval(-3800))
            ), isFeedAnimating: .constant(false), isDiaperAnimating: .constant(false), onFeedTimeTap: {}, onDiaperTap: {}, onNameTap: {}
        )
        BabyStatusView2(
            babyState: BabyState(
                profile: BabyProfile(id: UUID(), name: "초원"),
                feedState: FeedState(feededAt: Date.now.addingTimeInterval(-3840)), diaperState: DiaperState(diaperChangedAt: Date.now.addingTimeInterval(-840))
            ), isFeedAnimating: .constant(false), isDiaperAnimating: .constant(false), onFeedTimeTap: {}, onDiaperTap: {}, onNameTap: {}
        )
    }


}
