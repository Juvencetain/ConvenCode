import SwiftUI
import CoreData
import AppKit

struct ClipboardHistoryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    // 使用 NSFetchedResultsController 样式的请求，支持分页
    @FetchRequest private var items: FetchedResults<Paste>
    
    @State private var hoveredItemID: NSManagedObjectID?
    @State private var copiedItemID: NSManagedObjectID?
    @State private var selectedItem: Paste?
    @State private var searchText = ""
    @State private var isSearching = false
    
    // 性能优化：虚拟滚动，只显示可见项
    @State private var displayLimit = 50  // 初始只加载50条
    
    init() {
        _items = FetchRequest<Paste>(
            sortDescriptors: [NSSortDescriptor(keyPath: \Paste.time, ascending: false)],
            animation: .default
        )
    }
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerSection
                Divider().padding(.horizontal, 16)
                
                if isSearching {
                    searchBar
                }
                
                if items.isEmpty {
                    emptyState
                } else if isSearching && searchText.count >= 2 {
                    // 搜索模式：使用新的 FetchRequest
                    SearchResultsView(
                        searchText: searchText,
                        onCopy: { item in copyToClipboard(item) },
                        onDetail: { item in selectedItem = item },
                        onDelete: { item in deleteItem(item) }
                    )
                    .environment(\.managedObjectContext, viewContext)
                } else {
                    contentSection
                }
                
                if !items.isEmpty {
                    Divider().padding(.horizontal, 16)
                    bottomBar
                }
            }
        }
        .frame(width: 420, height: 560)
        .sheet(item: $selectedItem) { item in
            DetailView(item: item, onCopy: {
                copyToClipboard(item)
                selectedItem = nil
            })
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 16))
                .foregroundStyle(.blue.gradient)
            
            Text("剪贴板历史")
                .font(.system(size: 14, weight: .medium))
            
            Spacer()
            
            // 搜索按钮
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isSearching.toggle()
                    if !isSearching {
                        searchText = ""
                    }
                }
            }) {
                Image(systemName: isSearching ? "xmark.circle.fill" : "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
            
            // 计数徽章
            Text("\(items.count)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.secondary.opacity(0.15)))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            TextField("搜索剪贴板内容 (至少2个字符)...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.1))
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // MARK: - Content Section (带分页加载)
    private var contentSection: some View {
        ZStack {
            // 添加背景毛玻璃效果
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(0.3)
            
            ScrollView(showsIndicators: true) {
                LazyVStack(spacing: 8) {
                    // 只显示前 displayLimit 条数据
                    ForEach(Array(items.prefix(displayLimit)), id: \.objectID) { item in
                        ClipboardItemCard(
                            item: item,
                            isHovered: hoveredItemID == item.objectID,
                            isCopied: copiedItemID == item.objectID,
                            onHover: { hovering in
                                hoveredItemID = hovering ? item.objectID : nil
                            },
                            onCopy: {
                                copyToClipboard(item)
                                copiedItemID = item.objectID
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                    if copiedItemID == item.objectID {
                                        copiedItemID = nil
                                    }
                                }
                            },
                            onDetail: {
                                selectedItem = item
                            },
                            onDelete: {
                                deleteItem(item)
                            }
                        )
                    }
                    
                    // 加载更多按钮
                    if displayLimit < items.count {
                        Button(action: {
                            withAnimation {
                                displayLimit = min(displayLimit + 50, items.count)
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 14))
                                Text("加载更多 (剩余 \(items.count - displayLimit) 条)")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.accentColor)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.accentColor.opacity(0.1))
                            )
                        }
                        .buttonStyle(.plain)
                        .pointingHandCursor()
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            
            Text("暂无记录")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
            
            Text("复制的内容会自动保存在这里")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Bottom Bar
    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button(action: clearAll) {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                    Text("清空全部")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .buttonStyle(ModernButtonStyle(style: .danger))
            
            Spacer()
            
            Button(action: exportRecent) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 11))
                    Text("导出前100条")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .buttonStyle(ModernButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
    // MARK: - Actions
    private func copyToClipboard(_ item: Paste) {
        if let data = item.data {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(data, forType: .string)
        }
    }
    
    private func deleteItem(_ item: Paste) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            viewContext.delete(item)
            try? viewContext.save()
        }
    }
    
    private func clearAll() {
        let alert = NSAlert()
        alert.messageText = "确认清空"
        alert.informativeText = "将删除所有 \(items.count) 条剪贴板记录，此操作不可撤销。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        
        if alert.runModal() == .alertFirstButtonReturn {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                items.forEach { viewContext.delete($0) }
                try? viewContext.save()
            }
        }
    }
    
    private func exportRecent() {
        let recentItems = items.prefix(100)
        let allText = recentItems.compactMap { $0.data }.joined(separator: "\n\n---\n\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(allText, forType: .string)
    }
}

// MARK: - 搜索结果视图 (使用 Core Data 谓词优化)
struct SearchResultsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let searchText: String
    let onCopy: (Paste) -> Void
    let onDetail: (Paste) -> Void
    let onDelete: (Paste) -> Void
    
    @State private var searchResults: [Paste] = []
    @State private var isLoading = false
    @State private var hoveredItemID: NSManagedObjectID?
    @State private var copiedItemID: NSManagedObjectID?
    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("搜索中...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("未找到匹配内容")
                        .font(.system(size: 14, weight: .medium))
                    Text("试试其他搜索词")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: true) {
                    LazyVStack(spacing: 8) {
                        ForEach(searchResults, id: \.objectID) { item in
                            ClipboardItemCard(
                                item: item,
                                isHovered: hoveredItemID == item.objectID,
                                isCopied: copiedItemID == item.objectID,
                                onHover: { hovering in
                                    hoveredItemID = hovering ? item.objectID : nil
                                },
                                onCopy: {
                                    onCopy(item)
                                    copiedItemID = item.objectID
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                        copiedItemID = nil
                                    }
                                },
                                onDetail: { onDetail(item) },
                                onDelete: { onDelete(item) }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .onChange(of: searchText) { newValue in
            performSearch(newValue)
        }
        .onAppear {
            performSearch(searchText)
        }
    }
    
    private func performSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            searchResults = []
            return
        }
        
        isLoading = true
        
        // 使用异步搜索避免阻塞 UI
        DispatchQueue.global(qos: .userInitiated).async {
            let fetchRequest: NSFetchRequest<Paste> = Paste.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "data CONTAINS[cd] %@", trimmed)
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Paste.time, ascending: false)]
            fetchRequest.fetchLimit = 100  // 限制搜索结果
            
            do {
                let results = try viewContext.fetch(fetchRequest)
                DispatchQueue.main.async {
                    searchResults = results
                    isLoading = false
                    print("🔍 搜索 '\(trimmed)' 找到 \(results.count) 条结果")
                }
            } catch {
                DispatchQueue.main.async {
                    searchResults = []
                    isLoading = false
                    print("❌ 搜索失败: \(error)")
                }
            }
        }
    }
}

// MARK: - 剪贴板项目卡片（完全无缩放版本）
struct ClipboardItemCard: View {
    let item: Paste
    let isHovered: Bool
    let isCopied: Bool
    let onHover: (Bool) -> Void
    let onCopy: () -> Void
    let onDetail: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 内容预览
            HStack(alignment: .top, spacing: 10) {
                // 状态指示器
                Circle()
                    .fill(isCopied ? Color.green.gradient : Color.blue.gradient)
                    .frame(width: 6, height: 6)
                    .opacity(isCopied ? 1 : 0.4)
                    .padding(.top, 6)
                
                // 文本内容
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.data ?? "")
                        .font(.system(size: 13))
                        .lineLimit(3)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 8) {
                        if let time = item.time {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 9))
                                Text(formatTime(time))
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(.secondary.opacity(0.7))
                        }
                        
                        if let data = item.data {
                            Text("·")
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("\(data.count) 字符")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                    }
                }
            }
            
            // 操作按钮（悬停时显示）
            if isHovered || isCopied {
                HStack(spacing: 8) {
                    ActionIconButton(
                        icon: isCopied ? "checkmark.circle.fill" : "doc.on.doc",
                        label: isCopied ? "已复制" : "复制",
                        color: isCopied ? .green : .blue,
                        action: onCopy
                    )
                    
                    ActionIconButton(
                        icon: "eye",
                        label: "查看",
                        color: .purple,
                        action: onDetail
                    )
                    
                    Spacer()
                    
                    ActionIconButton(
                        icon: "trash",
                        label: "删除",
                        color: .red,
                        action: onDelete
                    )
                }
                .transition(
                    .asymmetric(
                        insertion: .opacity.animation(.easeOut(duration: 0.25)),
                        removal: .opacity.animation(.easeIn(duration: 0.2))
                    )
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? Color.white.opacity(0.12) : Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isHovered ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.3), value: isHovered)
        .animation(.easeInOut(duration: 0.25), value: isCopied)
        .onHover { hovering in
            onHover(hovering)
        }
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

// MARK: - 操作图标按钮
struct ActionIconButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                isPressed = true
            }
            action()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    isPressed = false
                }
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(0.12))
            )
            .scaleEffect(isPressed ? 0.92 : 1.0)
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
    }
}

// MARK: - 详情视图
struct DetailView: View {
    let item: Paste
    let onCopy: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var copied = false
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "doc.text")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue.gradient)
                    
                    Text("详细内容")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                
                Divider()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            if let time = item.time {
                                InfoChip(icon: "clock", text: formatFullTime(time))
                            }
                            
                            if let data = item.data {
                                InfoChip(icon: "textformat", text: "\(data.count) 字符")
                            }
                        }
                        
                        Divider()
                        
                        Text(item.data ?? "")
                            .font(.system(size: 14, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.08))
                            )
                    }
                    .padding(20)
                }
                
                Divider()
                
                HStack {
                    Button(action: {
                        onCopy()
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            copied = false
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                                .font(.system(size: 11))
                            Text(copied ? "已复制" : "复制内容")
                        }
                    }
                    .buttonStyle(ModernButtonStyle(style: copied ? .accent : .execute))
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .frame(width: 480, height: 520)
    }
    
    private func formatFullTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - 信息芯片
struct InfoChip: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 11))
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.secondary.opacity(0.12))
        )
    }
}

#Preview {
    ClipboardHistoryView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
