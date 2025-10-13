import SwiftUI
import CoreData
import LocalAuthentication

// MARK: - 主视图 (PasswordManagerView)
struct PasswordManagerView: View {
    @State private var isUnlocked = false

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            if isUnlocked {
                CredentialsListView()
            } else {
                UnlockView(isUnlocked: $isUnlocked)
            }
        }
        .frame(width: 700, height: 560) // 调整宽度以适应主从视图
        .focusable(false)
    }
}

// MARK: - 解锁视图 (UnlockView)
struct UnlockView: View {
    @Binding var isUnlocked: Bool
    @State private var authError: String?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue.gradient)
            
            Text("密码本已锁定")
                .font(.title2.bold())
            
            Button(action: authenticate) {
                Label("使用指纹解锁", systemImage: "touchid")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
            
            if let error = authError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 10)
            }
        }
        .onAppear(perform: authenticate)
    }
    
    private func authenticate() {
        authError = nil
        LocalAuthManager.shared.authenticate(reason: "请使用指纹来访问密码本") { success, error in
            if success {
                withAnimation(.spring()) {
                    isUnlocked = true
                }
            } else {
                authError = "认证失败，请重试"
            }
        }
    }
}

// MARK: - 密码列表主视图 (CredentialsListView)
struct CredentialsListView: View {
    @State private var selectedCredentialID: Credential.ID?
    @State private var showingAddSheet = false

    var body: some View {
        NavigationView {
            CredentialsSidebar(
                selectedCredentialID: $selectedCredentialID,
                onAdd: { showingAddSheet = true }
            )
            .frame(minWidth: 220, idealWidth: 250)
            
            CredentialDetailPlaceholderView()
        }
        .sheet(isPresented: $showingAddSheet) {
            AddCredentialView(credentialToEdit: nil)
        }
    }
}

// MARK: - 左侧边栏 (CredentialsSidebar)
struct CredentialsSidebar: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var selectedCredentialID: Credential.ID?
    let onAdd: () -> Void
    
    @State private var searchText = ""
    @FetchRequest var credentials: FetchedResults<Credential>
    
    // 自定义 init 以便未来可以传入动态的 predicate
    init(selectedCredentialID: Binding<Credential.ID?>, onAdd: @escaping () -> Void) {
        _selectedCredentialID = selectedCredentialID
        self.onAdd = onAdd
        
        let request: NSFetchRequest<Credential> = Credential.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Credential.createdAt, ascending: true)]
        _credentials = FetchRequest(fetchRequest: request, animation: .default)
    }
    
    // 搜索过滤后的结果
    private var filteredCredentials: [Credential] {
        if searchText.isEmpty {
            return Array(credentials)
        } else {
            return credentials.filter {
                ($0.platform ?? "").localizedCaseInsensitiveContains(searchText) ||
                ($0.account ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
                .padding(.bottom, 4)
            
            List(selection: $selectedCredentialID) {
                ForEach(filteredCredentials) { credential in
                    NavigationLink(destination: CredentialDetailView(credential: credential), tag: credential.id!, selection: $selectedCredentialID) {
                        CredentialRowView(credential: credential)
                    }
                    .contextMenu { contextMenuItems(for: credential) }
                }
            }
            .listStyle(SidebarListStyle())
            
            bottomBar
        }
    }
    
    // [修复 1] 将多个视图包裹在 VStack 中
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("密码本").font(.headline)
                Spacer()
                Text("\(credentials.count) 条").font(.caption2).foregroundColor(.secondary)
            }
            .padding([.top, .horizontal])
            
            TextField("搜索平台或账号...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
        }
    }
    
    private var bottomBar: some View {
        HStack {
            Button(action: onAdd) {
                Label("添加新密码", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ModernButtonStylePas())
        }
        .padding()
    }
    
    @ViewBuilder
    private func contextMenuItems(for credential: Credential) -> some View {
        Button(action: { copyPassword(credential) }) {
            Label("复制密码", systemImage: "doc.on.doc")
        }
        Button(role: .destructive, action: { deleteCredential(credential) }) {
            Label("删除", systemImage: "trash")
        }
    }

    private func copyPassword(_ credential: Credential) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(credential.password ?? "", forType: .string)
    }

    private func deleteCredential(_ credential: Credential) {
        withAnimation {
            if credential.id == selectedCredentialID {
                selectedCredentialID = nil
            }
            viewContext.delete(credential)
            try? viewContext.save()
        }
    }
}

// MARK: - 密码详情页 (CredentialDetailView)
struct CredentialDetailView: View {
    @ObservedObject var credential: Credential
    @State private var showPassword = false
    @State private var copied = false
    @State private var showingEditSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            
            CredentialInfoRow(label: "平台", value: credential.platform ?? "N/A")
            CredentialInfoRow(label: "账号", value: credential.account ?? "N/A", canCopy: true)
            passwordRow
            
            if let notes = credential.notes, !notes.isEmpty {
                VStack(alignment: .leading) {
                    Text("备注").font(.caption).foregroundColor(.secondary)
                    ScrollView {
                        Text(notes).frame(maxWidth: .infinity, alignment: .leading)
                    }.textSelection(.enabled)
                }
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingEditSheet) {
            AddCredentialView(credentialToEdit: credential)
        }
    }
    
    private var header: some View {
        HStack {
            Text(credential.platform ?? "密码详情")
                .font(.largeTitle.bold())
            Spacer()
            Button("编辑") { showingEditSheet = true }
        }
    }

    private var passwordRow: some View {
        VStack(alignment: .leading) {
            Text("密码").font(.caption).foregroundColor(.secondary)
            HStack {
                Text(showPassword ? (credential.password ?? "") : "••••••••")
                    .font(.system(size: 14, design: .monospaced))
                Spacer()
                Button(action: { showPassword.toggle() }) {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                }.buttonStyle(.plain)
                
                Button(action: copyAndNotify) {
                    Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                        .foregroundColor(copied ? .green : .secondary)
                }.buttonStyle(.plain)
            }
        }
    }
    
    private func copyAndNotify() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(credential.password ?? "", forType: .string)
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { copied = false }
        }
    }
}

// MARK: - 新增/编辑视图 (AddCredentialView)
struct AddCredentialView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    
    let credentialToEdit: Credential?
    
    @State private var platform = ""
    @State private var account = ""
    @State private var password = ""
    @State private var notes = ""
    @State private var passwordStrength: PasswordStrength?
    
    private var isEditing: Bool { credentialToEdit != nil }

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow).ignoresSafeArea()
            VStack(spacing: 0) {
                 HStack {
                    Image(systemName: isEditing ? "pencil.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 16))
                        // [修复 2] 使用纯色代替渐变色解决类型推断问题
                        .foregroundStyle(isEditing ? Color.orange : Color.green)
                    Text(isEditing ? "编辑密码" : "添加新密码").font(.system(size: 16, weight: .semibold))
                    Spacer()
                }.padding(20)
                
                Divider()
                
                VStack(spacing: 16) {
                    TextField("平台 (例如: Google)", text: $platform)
                    TextField("账号 (必填)", text: $account)
                    VStack(alignment: .leading) {
                        SecureField("密码 (必填)", text: $password)
                            .onChange(of: password) {
                                passwordStrength = PasswordStrengthChecker.checkStrength(for: $0)
                            }
                        if let strength = passwordStrength, !password.isEmpty {
                            Text(strength.description)
                                .font(.caption2)
                                .foregroundColor(strength == .weak ? .red : .secondary)
                        }
                    }
                    
                    TextEditor(text: $notes)
                        .frame(height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .textFieldStyle(.plain)
                .padding(20)
                
                Spacer()
                Divider()
                
                HStack {
                    Button("取消") { dismiss() }.buttonStyle(ModernButtonStylePas(style: .danger))
                    Spacer()
                    Button("保存", action: saveCredential)
                        .buttonStyle(ModernButtonStylePas())
                        .disabled(account.isEmpty || password.isEmpty)
                }.padding(20)
            }
        }
        .frame(width: 400, height: 480)
        .onAppear(perform: loadDataForEditing)
    }

    private func loadDataForEditing() {
        guard let credential = credentialToEdit else { return }
        platform = credential.platform ?? ""
        account = credential.account ?? ""
        password = credential.password ?? ""
        notes = credential.notes ?? ""
    }

    private func saveCredential() {
        let itemToSave = credentialToEdit ?? Credential(context: viewContext)
        if !isEditing {
            itemToSave.id = UUID()
            itemToSave.createdAt = Date()
        }
        itemToSave.platform = platform.isEmpty ? nil : platform
        itemToSave.account = account
        itemToSave.password = password
        itemToSave.notes = notes.isEmpty ? nil : notes
        
        try? viewContext.save()
        dismiss()
    }
}


// MARK: - 辅助视图
struct CredentialRowView: View {
    let credential: Credential
    var body: some View {
        HStack {
            Image(systemName: "key.fill")
                .foregroundColor(.accentColor)
                .frame(width: 20)
            VStack(alignment: .leading) {
                Text(credential.platform ?? "未命名平台").font(.headline)
                Text(credential.account ?? "").font(.subheadline).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CredentialDetailPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("请从左侧选择项目")
                .font(.title2)
                .foregroundColor(.secondary)
        }
    }
}

struct CredentialInfoRow: View {
    let label: String
    let value: String
    var canCopy: Bool = false
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(label).font(.caption).foregroundColor(.secondary)
            HStack {
                Text(value).textSelection(.enabled)
                Spacer()
                if canCopy {
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(value, forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct ModernButtonStylePas: ButtonStyle {
    enum Style { case execute, danger, accent }
    var style: Style = .execute
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
    
    private func backgroundColor(isPressed: Bool) -> Color {
        let baseColor: Color = {
            switch style {
            case .execute: return .blue
            case .danger: return .red
            case .accent: return .green
            }
        }()
        return isPressed ? baseColor.opacity(0.8) : baseColor
    }
}
