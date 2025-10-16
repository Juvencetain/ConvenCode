import SwiftUI

// MARK: - 主机条目行视图
struct HostEntryRow: View {
    @Binding var entry: HostEntry
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: $entry.isEnabled)
                .toggleStyle(.checkbox)
                .labelsHidden()

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.ip)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(entry.isEnabled ? .primary : .secondary)
                  
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Text(entry.domain)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(entry.isEnabled ? .accentColor : .secondary)
                }

                if !entry.comment.isEmpty {
                    Text("# \(entry.comment)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
        .focusable(false)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.black.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Hosts 编辑器主视图
struct HostsView: View {
    @StateObject private var manager = HostsManager()
    @State private var showingAddSheet = false
    @State private var searchText = ""

    private var filteredEntries: [HostEntry] {
        if searchText.isEmpty {
            return manager.entries
        }
        return manager.entries.filter {
            $0.ip.localizedCaseInsensitiveContains(searchText) ||
            $0.domain.localizedCaseInsensitiveContains(searchText) ||
            $0.comment.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                searchBar
                Divider()

                if manager.isLoading && manager.entries.isEmpty {
                    Spacer()
                    ProgressView("正在加载 Hosts 文件...").padding()
                    Spacer()
                } else if let error = manager.error {
                    errorView(error)
                        .frame(maxHeight: .infinity) // MARK: - 修改点
                } else {
                    contentList
                        .frame(maxHeight: .infinity) // MARK: - 修改点
                }
                
                Divider().padding(.horizontal, 16)
                bottomBar
            }
        }
        .frame(width: 500, height: 600)
        .sheet(isPresented: $showingAddSheet) {
            AddHostEntryView { newEntry in
                manager.entries.append(newEntry)
            }
        }
        .onChange(of: manager.entries) { _ in
            manager.checkForChanges()
        }
    }

    private var headerBar: some View {
        HStack {
            Image(systemName: "pencil.and.ruler.fill")
                .font(.system(size: 16))
                .foregroundStyle(.green.gradient)
            Text("Hosts 文件编辑器").font(.system(size: 16, weight: .semibold))
            Spacer()
            Button(action: manager.loadHosts) { Image(systemName: "arrow.clockwise") }
            .buttonStyle(.plain).help("重新加载")
        }
        .padding([.top, .horizontal]).padding(.bottom, 8)
    }

    private var searchBar: some View {
        HStack {
            TextField("搜索 IP、域名或备注...", text: $searchText)
                .textFieldStyle(.plain).padding(8)
                .background(Color.black.opacity(0.1)).cornerRadius(8)
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) { Image(systemName: "xmark.circle.fill").foregroundColor(.secondary) }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal).padding(.bottom, 10)
    }

    private var contentList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach($manager.entries) { $entry in
                    if shouldShow(entry: entry) {
                        HostEntryRow(entry: $entry, onDelete: {
                            // MARK: - 修改点 1
                            // 使用 .default 动画以避免界面抖动
                            withAnimation(.default) {
                                manager.entries.removeAll { $0.id == entry.id }
                            }
                        })
                    }
                }
            }
            .padding()
        }
    }
    
    private func shouldShow(entry: HostEntry) -> Bool {
        if searchText.isEmpty {
            return true
        }
        return entry.ip.localizedCaseInsensitiveContains(searchText) ||
               entry.domain.localizedCaseInsensitiveContains(searchText) ||
               entry.comment.localizedCaseInsensitiveContains(searchText)
    }
    
    private var bottomBar: some View {
        HStack {
            Button("添加条目") { showingAddSheet = true }
                .buttonStyle(ModernButtonStyle(style: .normal))
                .keyboardShortcut("n", modifiers: .command)

            if manager.hasChanges && !manager.isLoading {
                Button("恢复") { manager.loadHosts() }
                    .buttonStyle(ModernButtonStyle(style: .danger))
                    .keyboardShortcut(".", modifiers: .command)
            }
            Spacer()
            
            // 修复：使用稳定的容器防止布局跳动
            ZStack {
                if manager.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .transition(.opacity) // 添加过渡效果
                } else {
                    Button("保存更改") { manager.saveHosts() }
                        .buttonStyle(ModernButtonStyle(style: .execute))
                        .disabled(!manager.hasChanges)
                        .transition(.opacity) // 添加过渡效果
                }
            }
            .animation(.easeInOut(duration: 0.2), value: manager.isLoading) // 添加动画
            .frame(width: 100, height: 24) // 固定尺寸防止跳动
        }
        .padding()
    }

    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 48)).foregroundColor(.red)
            Text("发生错误").font(.headline)
            Text(message).font(.footnote).multilineTextAlignment(.center).foregroundColor(.secondary)
            Button("重试", action: manager.loadHosts)
        }
        .padding(30).frame(maxHeight: .infinity)
    }
}


// MARK: - 添加条目视图
struct AddHostEntryView: View {
    @Environment(\.dismiss) var dismiss
    let onAdd: (HostEntry) -> Void

    @State private var ip = "127.0.0.1"
    @State private var domain = ""
    @State private var comment = ""
    @State private var isEnabled = true

    var body: some View {
        VStack(spacing: 20) {
            Text("添加新的 Hosts 条目").font(.title2)
            TextField("IP 地址", text: $ip).textFieldStyle(.roundedBorder)
            TextField("域名", text: $domain).textFieldStyle(.roundedBorder)
            TextField("备注 (可选)", text: $comment).textFieldStyle(.roundedBorder)
            Toggle("启用此条目", isOn: $isEnabled)
            HStack {
                Button("取消") { dismiss() }.buttonStyle(ModernButtonStyle(style: .normal))
                Spacer()
                Button("添加") {
                    onAdd(HostEntry(ip: ip, domain: domain, comment: comment, isEnabled: isEnabled))
                    dismiss()
                }
                .buttonStyle(ModernButtonStyle(style: .execute))
                .disabled(ip.isEmpty || domain.isEmpty)
            }
        }
        .padding(30).frame(width: 400)
    }
}
