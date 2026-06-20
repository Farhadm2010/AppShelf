import SwiftUI
import UniformTypeIdentifiers

struct PageDotsView: View {
    @ObservedObject var vm: AppShelfViewModel
    let onDropToPage: (UUID, Int) -> Void

    @State private var hoveredDot: Int? = nil

    var pageCount: Int { vm.pages.count }
    var currentIndex: Int { vm.currentPageIndex }
    var isDragging: Bool { vm.draggingAppID != nil }

    func abbreviation(for title: String) -> String {
        let words = title.trimmingCharacters(in: .whitespaces)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        if words.count == 2,
           let num = Int(words[1]) {
            return "P" + String(format: "%02d", num)
        }
        if words.count >= 2 {
            return String(words.prefix(3).map { $0.prefix(1) }.joined()).uppercased()
        }
        let word = words[0]
        var digits = ""
        var letters = ""
        for ch in word {
            if ch.isNumber { digits.append(ch) }
            else { letters.append(ch) }
        }
        if !digits.isEmpty, let num = Int(digits) {
            return letters.prefix(1).uppercased() + String(format: "%02d", num)
        }
        return String(word.prefix(3)).uppercased()
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 20) {

            ForEach(0..<pageCount, id: \.self) { index in
                VStack(spacing: 2) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(
                                isDragging && hoveredDot == index ? 0.18 : 0
                            ))
                            .frame(
                                width: isDragging && hoveredDot == index ? 64 : 0,
                                height: isDragging && hoveredDot == index ? 64 : 0
                            )
                            .animation(.spring(response: 0.2, dampingFraction: 0.55), value: hoveredDot)

                        Circle()
                            .stroke(
                                Color.white.opacity(isDragging && hoveredDot == index ? 0.7 : 0),
                                lineWidth: 3
                            )
                            .frame(
                                width: isDragging && hoveredDot == index ? 64 : 0,
                                height: isDragging && hoveredDot == index ? 64 : 0
                            )
                            .animation(.spring(response: 0.2, dampingFraction: 0.55), value: hoveredDot)

                        Circle()
                            .fill(dotColor(for: index))
                            .frame(width: dotSize(for: index), height: dotSize(for: index))
                            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: hoveredDot)
                            .animation(.easeInOut(duration: 0.2), value: currentIndex)
                    }
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                            hoveredDot = hovering ? index : nil
                        }
                    }
                    .onTapGesture { vm.goToPage(index) }
                    .onDrop(
                        of: [UTType.plainText],
                        isTargeted: Binding(
                            get: { hoveredDot == index },
                            set: { v in withAnimation { hoveredDot = v ? index : nil } }
                        )
                    ) { providers in
                        guard let provider = providers.first else {
                            vm.endDrag()
                            return false
                        }
                        provider.loadObject(ofClass: NSString.self) { item, _ in
                            DispatchQueue.main.async {
                                if let str = item as? String,
                                   let uuid = UUID(uuidString: str) {
                                    onDropToPage(uuid, index)
                                } else {
                                    // Couldn't parse the payload — still clear drag
                                    // state so the app doesn't appear to freeze.
                                    vm.endDrag()
                                }
                                withAnimation { hoveredDot = nil }
                            }
                        }
                        return true
                    }

                    Text(abbreviation(for: vm.pages[index].title))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(index == currentIndex
                            ? .white.opacity(0.9)
                            : .white.opacity(0.35))
                        .animation(.easeInOut(duration: 0.2), value: currentIndex)
                }
            }

            // + Add page
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(hoveredDot == -1 ? 0.2 : 0.08))
                        .frame(width: 26, height: 26)
                        .animation(.easeInOut(duration: 0.15), value: hoveredDot)
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
                .onHover { hovering in
                    withAnimation { hoveredDot = hovering ? -1 : nil }
                }
                .onTapGesture { vm.addPage() }

                Text("NEW")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.25))
            }
        }
        .padding(.bottom, 100)
    }

    func dotColor(for index: Int) -> Color {
        if isDragging && hoveredDot == index { return .white }
        return index == currentIndex ? .white : .white.opacity(0.35)
    }

    func dotSize(for index: Int) -> CGFloat {
        if isDragging && hoveredDot == index { return 52 }
        if hoveredDot == index { return 38 }
        return index == currentIndex ? 18 : 14
    }
}
