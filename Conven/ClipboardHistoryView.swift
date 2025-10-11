import SwiftUI
import CoreData
import AppKit

struct ClipboardHistoryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Paste.time, ascending: false)],
        animation: .default)
    private var items: FetchedResults<Paste>
    
    @State private var hoveredItemID: NSManagedObjectID?
    @State private var copiedItemID: NSManagedObjectID?
    
    var body: some View {
        ZStack {
            // ========== ⭐ 优化：更通透的毛玻璃背景 ==========
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(0.95)  // 提高透明度，更通透
                .ignoresSafeArea()
            // ==============================================
            
            VStack(spacing: 0) {
                // 简洁标题栏
                HStack(spacing: 12) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue.gradient)
                    
                    Text("剪贴板")
                        .font(.system(size: 14, weight: .medium))
                    
                    Spacer()
                    
                    Text("\(items.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.secondary.opacity(0.15))
                        )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                // 内容区域
                if items.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 8) {
                            ForEach(items) { item in
                                ModernClipboardItem(
                                    item: item,
                                    isHovered: hoveredItemID == item.objectID,
                                    isCopied: copiedItemID == item.objectID,
                                    onHover: { isHovering in
                                        hoveredItemID = isHovering ? item.objectID : nil
                                    },
                                    onCopy: {
                                        copyToClipboard(item)
                                        copiedItemID = item.objectID
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                            if copiedItemID == item.objectID {
                                                copiedItemID = nil
                                            }
                                        }
                                    },
                                    onDelete: { deleteItem(item) }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }
                
                // 底部操作栏
                if !items.isEmpty {
                    bottomBar
                }
            }
        }
        .frame(width: 420, height: 560)
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("暂无记录")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var bottomBar: some View {
        HStack {
            // ========== ⭐ 优化：去掉绿框，改用普通按钮样式 ==========
            Button(action: clearAll) {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                    Text("清空")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.red.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red.opacity(0.1))
                )
            }
            .buttonStyle(.plain)  // 使用 plain 样式去掉边框
            .focusable(false)
            // =======================================================
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.05))
        )
    }
    
    private func copyToClipboard(_ item: Paste) {
        if let data = item.data {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(data, forType: .string)
        }
    }
    
    private func deleteItem(_ item: Paste) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            viewContext.delete(item)
            try? viewContext.save()
        }
    }
    
    private func clearAll() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            items.forEach { viewContext.delete($0) }
            try? viewContext.save()
        }
    }
}

// ========== ⭐ 优化：重新设计单项，加入原生 Popover 预览 ==========
struct ModernClipboardItem: View {
    let item: Paste
    let isHovered: Bool
    let isCopied: Bool
    let onHover: (Bool) -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void
    
    @State private var showPopover = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 状态指示器
            Circle()
                .fill(isCopied ? Color.green.gradient : Color.blue.gradient)
                .frame(width: 6, height: 6)
                .opacity(isCopied ? 1 : 0.4)
            
            // 内容
            VStack(alignment: .leading, spacing: 4) {
                Text(item.data ?? "")
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                if let time = item.time {
                    Text(formatTime(time))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // ========== ⭐ 新增：使用 popover 显示完整内容 ==========
            .popover(isPresented: $showPopover, arrowEdge: .trailing) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("完整内容")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Text(item.data ?? "")
                        .font(.system(size: 12))
                        .textSelection(.enabled)
                        .frame(maxWidth: 300)
                }
                .padding(12)
                .background(VisualEffectBlur(material: .popover, blendingMode: .behindWindow))
            }
            // ====================================================
            
            // 删除按钮
            if isHovered && !isCopied {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
            
            // 复制成功提示
            if isCopied {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? Color.white.opacity(0.5) : Color.white.opacity(0.2))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isHovered ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        // ========== ⭐ 优化：改用简单的悬停检测 ==========
        .onHover { hovering in
            onHover(hovering)
            // 悬停 0.5 秒后显示 popover
            if hovering {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if isHovered {
                        showPopover = true
                    }
                }
            } else {
                showPopover = false
            }
        }
        // ===============================================
        .onTapGesture {
            onCopy()
        }
        .cursor(.pointingHand)
    }
    
    private func formatTime(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd"
            return formatter.string(from: date)
        }
    }
}

#Preview {
    ClipboardHistoryView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
