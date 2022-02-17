//
//  ContentView.swift
//  TreesWithAlignment
//
//  Created by Chris Eidhof on 07.02.22.
//

import SwiftUI

struct Tree<A>: Identifiable {
    init(_ value: A, children: [Tree<A>] = []) {
        self.value = value
        self.children = children
    }
    
    var value: A
    var children: [Tree<A>] = []
    let id = UUID()
}

extension Tree {
    mutating func insert(value: A, parent: UUID) {
        if id == parent {
            children.append(Tree(value))
        } else {
            for i in children.indices {
                children[i].insert(value: value, parent: parent)
            }
        }
    }
}

let sample = Tree("Root", children: [
    Tree("First Child With Some More Text"),
    Tree("Second"),
])

struct Line: Shape {
    var from: CGPoint
    var to: CGPoint
    
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: from)
            p.addLine(to: to)
        }
    }
}

struct FrameKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] { [:] }
    static func reduce(value: inout [UUID : CGRect], nextValue: () -> [UUID : CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

extension View {
    func measureFrame(in coordinateSpace: CoordinateSpace, id: UUID) -> some View {
        background(GeometryReader { proxy in
            Color.clear.preference(key: FrameKey.self, value: [id: proxy.frame(in: coordinateSpace)])
        })
    }
}

enum Zero { }
enum Suc<A> { }

struct NodeCenter<Level>: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> CGFloat {
        context[HorizontalAlignment.center]
    }
}

struct Diagram<A, Node: View>: View {
    var tree: Tree<A>
    @ViewBuilder var node: (Tree<A>) -> Node
    
    var body: some View {
        DiagramHelper<Zero, A, Node>(tree: tree, node: node, isMiddleChild: true)
            .coordinateSpace(name: coordinateSpaceName)
            .backgroundPreferenceValue(FrameKey.self) { frames in
                Vertices(tree: tree, frames: frames)
            }
    }
}

struct Vertices<A>: View {
    var tree: Tree<A>
    var frames: [UUID: CGRect]
    
    var body: some View {
        ZStack {
            let rootFrame = frames[tree.id]!
            ForEach(tree.children) { child in
                let childFrame = frames[child.id]!
                Line(from: rootFrame[.bottom], to: childFrame[.top])
                    .stroke(lineWidth: 1)
                Vertices(tree: child, frames: frames)
            }
        }
    }
}

let coordinateSpaceName = "diagram"

struct DiagramHelper<Level, A, Node: View>: View {
    var tree: Tree<A>
    @ViewBuilder var node: (Tree<A>) -> Node
    var isMiddleChild: Bool
    
    func computeGuideIDs() -> Set<UUID> {
        var ids: Set<UUID> = []
        let centerIdx = tree.children.count/2
        ids.insert(tree.children[centerIdx].id)
        if tree.children.count.isMultiple(of: 2) {
            ids.insert(tree.children[centerIdx - 1].id)
        }
        return ids
    }
    
    var body: some View {
        VStack(alignment: HorizontalAlignment(NodeCenter<Suc<Level>>.self), spacing: 20) {
            node(tree)
                .measureFrame(in: .named(coordinateSpaceName), id: tree.id)
                .alignmentGuide(isMiddleChild ? HorizontalAlignment(NodeCenter<Level>.self) : .center, computeValue: {
                    $0[HorizontalAlignment.center]
                })
            if !tree.children.isEmpty {
                let guideIDs = computeGuideIDs()
                HStack(alignment: .top, spacing: 20) {
                    ForEach(tree.children) { child in
                        let isMiddleChild = guideIDs.contains(child.id)
                        DiagramHelper<Suc<Level>, A, Node>(tree: child, node: node, isMiddleChild: isMiddleChild)
                    }
                }
            }
        }
    }
}

extension CGRect {
    subscript(point: UnitPoint) -> CGPoint {
        CGPoint(x: minX + point.x * width, y: minY + point.y * height)
    }
}

struct ContentView: View {
    @State var tree = sample
    var body: some View {
        Diagram(tree: tree) { subtree in
            Text(subtree.value)
                .fixedSize()
                .padding()
                .background(.tertiary)
                .onTapGesture(perform: {
                    tree.insert(value: "A New Node", parent: subtree.id)
                })
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
