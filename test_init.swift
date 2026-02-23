import Foundation

enum JunkCategory { case purgeableSpace }
struct JunkItem {
    let path: String
    let size: Int64
    let category: JunkCategory
    var isSelected: Bool = true
}

let item = JunkItem(path: "A", size: 1, category: .purgeableSpace)
print("isSelected: \(item.isSelected)")
