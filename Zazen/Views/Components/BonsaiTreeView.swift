//
//  BonsaiTreeView.swift
//  Zazen
//
//  An algorithmically-generated bonsai tree that grows one line segment
//  per streak day, completing at 365 days. Rendered as minimal line art
//  on the app's washi paper background.
//

import SwiftUI

// MARK: - Tree Segment

/// A single line segment of the bonsai tree, in normalized coordinates (0..1).
struct TreeSegment {
    let start: CGPoint
    let end: CGPoint
    let thickness: CGFloat
    /// 0.0 = trunk brown, 1.0 = foliage green. Interpolated at render time.
    let colorMix: Double
}

// MARK: - Bonsai Generator

/// Produces a deterministic bonsai tree as exactly 365 ordered line segments.
///
/// The tree uses recursive branching with:
/// - A thick, S-curved trunk (parametric sine)
/// - Nearly-horizontal branches with upward-curving tips (classic bonsai form)
/// - Dense canopy pads of small elongated brush-stroke marks (golden-angle fill)
///
/// Growth ordering interleaves branches and foliage: a branch's canopy starts
/// appearing while neighboring branches are still extending, creating natural,
/// organic growth rather than a rigid "all branches then all leaves" sequence.
private final class BonsaiGenerator {

    static let targetCount = 365

    private struct Tagged {
        let segment: TreeSegment
        let depth: Int
        let branchId: Int
        let position: Int
    }

    private struct Cluster {
        let center: CGPoint
        let angle: Double
        let weight: Double
        let parentDepth: Int   // depth of the terminal branch that spawned this cluster
    }

    private var tagged: [Tagged] = []
    private var clusters: [Cluster] = []
    private var nextId = 0

    // MARK: - Public

    static func generate() -> [TreeSegment] {
        let gen = BonsaiGenerator()
        gen.buildStructure()
        gen.buildFoliage()
        gen.orderForGrowth()
        return Array(gen.tagged.prefix(targetCount)).map(\.segment)
    }

    // MARK: - Trunk & Branches

    private func buildStructure() {
        let trunkSegs = 20
        let trunkId = freshId()
        var trunkPoints: [CGPoint] = []

        for i in 0...trunkSegs {
            let t = Double(i) / Double(trunkSegs)
            let y = mix(0.78, 0.26, t: t)
            let x = 0.48 + sin(t * .pi * 1.3) * 0.09
            trunkPoints.append(CGPoint(x: x, y: y))
        }

        for i in 0..<trunkSegs {
            let t = Double(i) / Double(trunkSegs)
            tagged.append(Tagged(
                segment: TreeSegment(
                    start: trunkPoints[i],
                    end: trunkPoints[i + 1],
                    thickness: CGFloat(mix(5.0, 2.0, t: t)),
                    colorMix: t * 0.10
                ),
                depth: 0, branchId: trunkId, position: i
            ))
        }

        let specs: [(frac: Double, angle: Double, len: Double, sub: Int, wt: Double)] = [
            (0.28,  1.35, 0.14, 0, 0.70),   // right-lower
            (0.50, -1.40, 0.18, 1, 1.40),   // left-large (dominant canopy)
            (0.68,  1.25, 0.14, 0, 0.90),   // right-mid
            (0.88, -1.05, 0.12, 0, 1.00),   // crown-left
            (0.88,  0.80, 0.10, 0, 0.80),   // crown-right
            (0.97,  0.10, 0.05, 0, 0.70),   // crown-top (covers trunk tip)
        ]

        for s in specs {
            let idx = min(Int(s.frac * Double(trunkSegs)), trunkSegs - 1)
            let origin = trunkPoints[idx]
            let prev = trunkPoints[max(0, idx - 1)]
            let trunkAngle = atan2(origin.y - prev.y, origin.x - prev.x)
            let thickness = mix(5.0, 2.0, t: s.frac) * 0.45

            growBranch(
                from: origin,
                angle: trunkAngle + s.angle,
                length: s.len,
                thickness: thickness,
                depth: 1,
                remaining: s.sub,
                weight: s.wt,
                curve: s.angle > 0 ? -0.05 : 0.05
            )
        }
    }

    private func growBranch(from start: CGPoint, angle: Double, length: Double,
                            thickness: Double, depth: Int, remaining: Int,
                            weight: Double, curve: Double) {
        let id = freshId()
        let segCount = max(2, Int(length / 0.030))
        let segLen = length / Double(segCount)

        var current = start
        var curAngle = angle

        for i in 0..<segCount {
            let t = Double(i) / Double(segCount)
            curAngle += curve * (1.0 - t * 0.5)

            let next = CGPoint(
                x: current.x + cos(curAngle) * segLen,
                y: current.y + sin(curAngle) * segLen
            )
            tagged.append(Tagged(
                segment: TreeSegment(
                    start: current,
                    end: next,
                    thickness: CGFloat(thickness * (1.0 - t * 0.25)),
                    colorMix: min(0.45, Double(depth) * 0.18 + t * 0.06)
                ),
                depth: depth, branchId: id, position: i
            ))
            current = next
        }

        if remaining <= 0 {
            clusters.append(Cluster(
                center: current, angle: curAngle,
                weight: weight, parentDepth: depth
            ))
        } else {
            let spread = 0.50
            let seed = Double(depth * 17 + id * 7)
            let wiggle = sin(seed) * 0.08

            for j in 0..<2 {
                let side = Double(j) - 0.5
                growBranch(
                    from: current,
                    angle: curAngle + side * spread + wiggle,
                    length: length * 0.58,
                    thickness: thickness * 0.55,
                    depth: depth + 1,
                    remaining: remaining - 1,
                    weight: weight * 0.65,
                    curve: curve * 0.35 + side * 0.03
                )
            }
        }
    }

    // MARK: - Foliage

    /// Fill remaining segment budget with canopy pads made of small elongated
    /// brush-stroke marks. Each mark is a short line with round caps, giving
    /// it an organic seed/rice-grain shape. Angles follow a golden-ratio spiral
    /// with sinusoidal variation for natural feel.
    ///
    /// Foliage depth = parentDepth + 1, so leaves interleave with neighboring
    /// branches at the same depth rather than all appearing at the end.
    private func buildFoliage() {
        let budget = max(0, BonsaiGenerator.targetCount - tagged.count)
        guard budget > 0, !clusters.isEmpty else { return }

        let totalWeight = clusters.reduce(0.0) { $0 + $1.weight }
        let goldenAngle = 2.39996323
        var remaining = budget

        for (ci, cluster) in clusters.enumerated() {
            let share: Int
            if ci == clusters.count - 1 {
                share = remaining
            } else {
                share = max(1, Int(Double(budget) * cluster.weight / totalWeight))
            }
            remaining = max(0, remaining - share)

            let id = freshId()
            let radius = 0.065 + cluster.weight * 0.05
            let foliageDepth = cluster.parentDepth + 1

            for i in 0..<share {
                let fi = Double(i)
                let angle = fi * goldenAngle
                let r = radius * sqrt((fi + 1.0) / Double(share + 1))

                // Position shifted upward so canopy sits on top of branch
                let cx = cluster.center.x + cos(angle) * r
                let cy = cluster.center.y + sin(angle) * r - radius * 0.25

                // Small elongated brush-stroke: golden-ratio rotation + sine wobble
                let normalizedR = r / max(radius, 0.001)
                let leafAngle = fi * goldenAngle * 0.618 + sin(fi * 0.9) * 1.0
                let lineLen = 0.006 + (1.0 - normalizedR) * 0.005

                tagged.append(Tagged(
                    segment: TreeSegment(
                        start: CGPoint(
                            x: cx - cos(leafAngle) * lineLen * 0.5,
                            y: cy - sin(leafAngle) * lineLen * 0.5
                        ),
                        end: CGPoint(
                            x: cx + cos(leafAngle) * lineLen * 0.5,
                            y: cy + sin(leafAngle) * lineLen * 0.5
                        ),
                        thickness: CGFloat(1.6 + (1.0 - normalizedR) * 0.7),
                        colorMix: 0.75 + normalizedR * 0.20
                    ),
                    depth: foliageDepth, branchId: id, position: i
                ))
            }
        }
    }

    // MARK: - Ordering

    /// Sort for natural growth. Depth is the primary key, so trunk (0) comes first,
    /// then main branches (1), then sub-branches AND early foliage (2), then deeper
    /// foliage (3). Within each depth, position interleaves branches so they grow
    /// simultaneously, and foliage mixes in alongside neighboring branch growth.
    private func orderForGrowth() {
        tagged.sort { a, b in
            if a.depth != b.depth { return a.depth < b.depth }
            if a.position != b.position { return a.position < b.position }
            return a.branchId < b.branchId
        }
    }

    // MARK: - Helpers

    private func freshId() -> Int { let id = nextId; nextId += 1; return id }
    private func mix(_ a: Double, _ b: Double, t: Double) -> Double { a + (b - a) * t }
}

// MARK: - Bonsai Tree View

struct BonsaiTreeView: View {
    let streakDays: Int

    /// Computed once and cached (the tree is deterministic).
    private static let treeSegments: [TreeSegment] = BonsaiGenerator.generate()

    // Trunk brown → foliage green (muted, warm tones for washi paper)
    private static let trunkRGB  = (r: 0.42, g: 0.36, b: 0.28)
    private static let foliageRGB = (r: 0.38, g: 0.53, b: 0.37)

    var body: some View {
        Canvas { context, size in
            let drawArea = CGRect(
                x: size.width * 0.05,
                y: size.height * 0.02,
                width: size.width * 0.90,
                height: size.height * 0.96
            )
            let scale = min(size.width, size.height) / 200.0

            func px(_ p: CGPoint) -> CGPoint {
                CGPoint(
                    x: drawArea.minX + p.x * drawArea.width,
                    y: drawArea.minY + p.y * drawArea.height
                )
            }

            // Pot (always visible)
            drawPot(in: &context, px: px, scale: scale)

            // Tree segments (1 per streak day)
            let count = min(max(streakDays, 0), Self.treeSegments.count)
            for seg in Self.treeSegments.prefix(count) {
                var path = Path()
                path.move(to: px(seg.start))
                path.addLine(to: px(seg.end))

                context.stroke(
                    path,
                    with: .color(Self.color(for: seg.colorMix)),
                    style: StrokeStyle(
                        lineWidth: seg.thickness * scale,
                        lineCap: .round
                    )
                )
            }
        }
        .aspectRatio(1.0, contentMode: .fit)
    }

    // MARK: - Pot

    private func drawPot(in context: inout GraphicsContext,
                         px: (CGPoint) -> CGPoint,
                         scale: CGFloat) {
        let color = Color.textMuted.opacity(0.55)
        let lw = 1.2 * scale

        let rimY  = 0.81
        let rimL  = 0.30,  rimR  = 0.70
        let bodyL = 0.34,  bodyR = 0.66
        let botY  = 0.87
        let sag   = 0.012

        func line(_ a: CGPoint, _ b: CGPoint) {
            var p = Path()
            p.move(to: px(a)); p.addLine(to: px(b))
            context.stroke(p, with: .color(color),
                           style: StrokeStyle(lineWidth: lw, lineCap: .round))
        }

        line(CGPoint(x: rimL, y: rimY), CGPoint(x: rimR, y: rimY))
        line(CGPoint(x: rimL, y: rimY), CGPoint(x: bodyL, y: botY))
        line(CGPoint(x: rimR, y: rimY), CGPoint(x: bodyR, y: botY))
        for i in 0..<4 {
            let t0 = Double(i) / 4.0
            let t1 = Double(i + 1) / 4.0
            line(
                CGPoint(x: bodyL + (bodyR - bodyL) * t0,
                        y: botY + sin(t0 * .pi) * sag),
                CGPoint(x: bodyL + (bodyR - bodyL) * t1,
                        y: botY + sin(t1 * .pi) * sag)
            )
        }
    }

    // MARK: - Color

    private static func color(for mix: Double) -> Color {
        let t = min(max(mix, 0), 1)
        return Color(
            red:   trunkRGB.r + (foliageRGB.r - trunkRGB.r) * t,
            green: trunkRGB.g + (foliageRGB.g - trunkRGB.g) * t,
            blue:  trunkRGB.b + (foliageRGB.b - trunkRGB.b) * t
        )
    }
}

#Preview("Full tree") {
    ZStack {
        PaperTextureBackground().ignoresSafeArea()
        BonsaiTreeView(streakDays: 365)
            .frame(maxHeight: 280)
            .padding()
    }
}

#Preview("Half grown") {
    ZStack {
        PaperTextureBackground().ignoresSafeArea()
        BonsaiTreeView(streakDays: 180)
            .frame(maxHeight: 280)
            .padding()
    }
}

#Preview("Empty pot") {
    ZStack {
        PaperTextureBackground().ignoresSafeArea()
        BonsaiTreeView(streakDays: 0)
            .frame(maxHeight: 280)
            .padding()
    }
}
