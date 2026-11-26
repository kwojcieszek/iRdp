/// Divides a desktop into 64×64 tiles and turns sets of tiles into rectangles.
struct TileGrid: Equatable {
    static let tileSize = 64

    let size: DesktopSize
    let columns: Int
    let rows: Int

    init(size: DesktopSize) {
        self.size = size
        columns = (size.width + Self.tileSize - 1) / Self.tileSize
        rows = (size.height + Self.tileSize - 1) / Self.tileSize
    }

    var allTiles: Set<Int> { Set(0..<(columns * rows)) }

    /// Pixel rectangle of a tile, clipped to the desktop: (left, top, width, height).
    func frame(ofTile index: Int) -> (left: Int, top: Int, width: Int, height: Int) {
        let left = (index % columns) * Self.tileSize
        let top = (index / columns) * Self.tileSize
        return (left, top, min(Self.tileSize, size.width - left), min(Self.tileSize, size.height - top))
    }

    /// Tiles whose pixels differ between two frames of this size.
    func changedTiles(_ frame: ScreenFrame, comparedTo previous: ScreenFrame, stoppingAfter limit: Int = .max) -> Set<Int> {
        var changed = Set<Int>()
        frame.pixels.withUnsafeBytes { current in
            for index in 0..<(columns * rows) {
                let tile = self.frame(ofTile: index)
                if ScreenUpdateEncoder.tileChanged(current, previous, frame: frame, left: tile.left, top: tile.top, width: tile.width, height: tile.height) {
                    changed.insert(index)
                    if changed.count >= limit { break }
                }
            }
        }
        return changed
    }

    /// Rectangles (exclusive right/bottom) covering the tiles, merging horizontal runs in each tile row.
    func rectangles(covering tiles: Set<Int>) -> [(left: Int, top: Int, right: Int, bottom: Int)] {
        var result: [(Int, Int, Int, Int)] = []
        for row in 0..<rows {
            var column = 0
            while column < columns {
                guard tiles.contains(row * columns + column) else { column += 1; continue }
                let start = column
                while column < columns, tiles.contains(row * columns + column) { column += 1 }
                let left = start * Self.tileSize
                let top = row * Self.tileSize
                result.append((left, top, min(column * Self.tileSize, size.width), min(top + Self.tileSize, size.height)))
            }
        }
        return result
    }
}
