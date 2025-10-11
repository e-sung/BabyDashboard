
import SwiftUI

struct BabyStatusEmptyView: View {
    let onAdd: () -> Void

    var body: some View {
        VStack {
            Button(action: onAdd) {
                VStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("Add Baby")
                        .font(.title)
                        .foregroundColor(.gray)
                }
            }
        }
    }
}
