//
//  Components.swift
//  Mafia
//
//  Created by Jack Friar on 10/11/25.
//

import SwiftUI

struct Chip: View {
    let text: String
    var body: some View {
        Text(text)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.2))
            .clipShape(Capsule())
    }
}

struct Wrap<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable, Data.Element: Hashable {
    var data: [Data.Element]
    @ViewBuilder var content: (Data.Element) -> Content

    init(_ c: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = Array(c)
        self.content = content
    }

    var body: some View {
        FlexibleView(data: data, spacing: 8, content: content)
    }
}

struct FlexibleView<Data: Collection, Content: View, T: Hashable>: View where Data.Element == T {
    let data: [T]
    let spacing: CGFloat
    let content: (T) -> Content

    init(data: Data, spacing: CGFloat, @ViewBuilder content: @escaping (T) -> Content) {
        self.data = Array(data)
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        GeometryReader { geo in
            var width = CGFloat.zero
            var height = CGFloat.zero

            ZStack(alignment: .topLeading) {
                // ✅ Only ONE backslash here:
                ForEach(data, id: \.self) { item in
                    content(item)
                        .padding(4)
                        .alignmentGuide(.leading) { d in
                            if abs(width - d.width) > geo.size.width {
                                width = 0; height -= d.height + spacing
                            }
                            let result = width
                            width -= d.width + spacing
                            return result
                        }
                        .alignmentGuide(.top) { _ in height }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

