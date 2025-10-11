import SwiftUI
import CoreData
import AppKit

struct ClipboardHistoryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.time, ascending: false)],
        animation: .default)
    private var items: FetchedResults<Item>
    
    @State private var hoveredItemID: NSManagedObjectID?
    @State private var copiedItemID: NSManagedObjectID?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Image(systemName: "doc.on.clipboard")
                    .foregroundColor(.blue)
                Text("剪贴板历史")
                    .font(.headline)
                Spacer()
                
                Text("\(items.count) 条记录")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // 列表内容
            if items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("还没有剪贴板历史")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(items) { item in
                            ClipboardItemRow(
                                item: item,
                                isHovered: hoveredItemID == item.objectID,
                                isCopied: copiedItemID == item.objectID,
                                onHover: { hoveredItemID = $0 ? item.objectID : nil },
                                onCopy: {
                                    copyToClipboard(item)
                                    copiedItemID = item.objectID
                                    // 0.5 秒后重置复制状态
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        if copiedItemID == item.objectID {
                                            copiedItemID = nil
                                        }
                                    }
                                },
                                onDelete: { deleteItem(item) }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            
            Divider()
            
            // 底部操作栏
            HStack {
                Button(action: clearAll) {
                    Label("清空全部", systemImage: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
                .disabled(items.isEmpty)
                
                Spacer()
                
                Button("关闭") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 500, height: 600)
    }
    
    // 复制到剪贴板
    private func copyToClipboard(_ item: Item) {
        if let data = item.data {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(data, forType: .string)
            print("✅ 已复制: \(data.prefix(30))...")
        }
    }
    
    // 删除单条记录
    private func deleteItem(_ item: Item) {
        withAnimation {
            viewContext.delete(item)
            do {
                try viewContext.save()
                print("🗑️ 已删除记录")
            } catch {
                print("❌ 删除失败: \(error.localizedDescription)")
            }
        }
    }
    
    // 清空所有记录
    private func clearAll() {
        withAnimation {
            for item in items {
                viewContext.delete(item)
            }
            do {
                try viewContext.save()
                print("🗑️ 已清空所有记录")
            } catch {
                print("❌ 清空失败: \(error.localizedDescription)")
            }
        }
    }
}

// 单个剪贴板项目行
struct ClipboardItemRow: View {
    let item: Item
    let isHovered: Bool
    let isCopied: Bool
    let onHover: (Bool) -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 左侧图标
            Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                .foregroundColor(isCopied ? .green : .blue)
                .frame(width: 20)
            
            // 内容区域
            VStack(alignment: .leading, spacing: 4) {
                Text(item.data ?? "无内容")
                    .lineLimit(3)
                    .font(.body)
                    .foregroundColor(.primary)
                
                if let time = item.time {
                    Text(formatDate(time))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // 右侧删除按钮
            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.gray.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            onHover(hovering)
        }
        .onTapGesture {
            onCopy()
        }
        .cursor(.pointingHand) // 鼠标悬停时显示手型
    }
    
    // 格式化日期
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "今天 " + formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "昨天 " + formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
}

// 自定义鼠标样式扩展
extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { inside in
            if inside {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

// 预览
#Preview {
    ClipboardHistoryView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}