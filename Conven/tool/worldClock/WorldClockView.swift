//
//  WorldClockView.swift
//  Conven
//
//  Created by 土豆星球 on 2025/10/17.
//


import SwiftUI

// MARK: - WorldClock View
struct WorldClockView: View {
    @StateObject private var worldClockViewModel = WorldClockViewModel()
    @State private var worldClockSearchText = ""
    @State private var worldClockShowAddCity = false
    
    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.3),
                    Color.indigo.opacity(0.1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                worldClockHeaderSection
                Divider().padding(.horizontal, 16)
                
                if worldClockViewModel.worldClockCities.isEmpty {
                    worldClockEmptyState
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(worldClockViewModel.worldClockCities) { city in
                                WorldClockCityCard(
                                    city: city,
                                    currentTime: worldClockViewModel.worldClockCurrentTime,
                                    onDelete: {
                                        worldClockViewModel.removeWorldClockCity(city)
                                    }
                                )
                            }
                        }
                        .padding(20)
                    }
                }
            }
        }
        .focusable(false)
        .frame(width: 480, height: 620)
        .sheet(isPresented: $worldClockShowAddCity) {
            WorldClockAddCityView(
                viewModel: worldClockViewModel,
                isPresented: $worldClockShowAddCity
            )
        }
        .onAppear {
            worldClockViewModel.startWorldClockTimer()
        }
        .onDisappear {
            worldClockViewModel.stopWorldClockTimer()
        }
    }
    
    // MARK: - Header Section
    private var worldClockHeaderSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.indigo.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "globe.americas.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.indigo.gradient)
                    .rotationEffect(.degrees(worldClockViewModel.worldClockIsRotating ? 360 : 0))
                    .animation(worldClockViewModel.worldClockIsRotating ? .linear(duration: 20).repeatForever(autoreverses: false) : .default, value: worldClockViewModel.worldClockIsRotating)
            }
            
            Text("世界时间")
                .font(.system(size: 16, weight: .semibold))
            
            Spacer()
            
            // 当前本地时间
            VStack(alignment: .trailing, spacing: 2) {
                Text(worldClockViewModel.worldClockLocalTimeString)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                Text("本地时间")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            
            // 添加按钮
            Button(action: {
                worldClockShowAddCity = true
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.indigo.gradient)
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
    
    // MARK: - Empty State
    private var worldClockEmptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.indigo.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "globe.americas")
                    .font(.system(size: 50))
                    .foregroundStyle(.indigo.gradient)
            }
            
            VStack(spacing: 8) {
                Text("还没有添加城市")
                    .font(.system(size: 16, weight: .semibold))
                
                Text("点击右上角 + 添加世界各地城市")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Button(action: {
                worldClockShowAddCity = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("添加城市")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.indigo.gradient)
                .cornerRadius(20)
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - City Card
struct WorldClockCityCard: View {
    let city: WorldClockCity
    let currentTime: Date
    let onDelete: () -> Void
    @State private var worldClockCardScale: CGFloat = 1.0
    @State private var worldClockCardHovered = false
    
    var body: some View {
        HStack(spacing: 16) {
            // 左侧时间显示
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(city.worldClockFlag)
                        .font(.system(size: 28))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(city.worldClockCityName)
                            .font(.system(size: 15, weight: .semibold))
                        Text(city.worldClockCountry)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(worldClockTimeZoneOffset)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 右侧模拟时钟和数字时间
            VStack(spacing: 8) {
                // 模拟时钟
                WorldClockAnalogClock(date: worldClockCityTime, size: 60)
                
                // 数字时间
                VStack(spacing: 2) {
                    Text(worldClockFormattedTime)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.indigo.gradient)
                    Text(worldClockFormattedDate)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(worldClockCardHovered ? 0.08 : 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.indigo.opacity(worldClockCardHovered ? 0.3 : 0.2), lineWidth: 1)
                )
        )
        .shadow(color: Color.indigo.opacity(0.1), radius: 10, x: 0, y: 4)
        .scaleEffect(worldClockCardScale)
        .contextMenu {
            Button(action: {
                // 复制时区信息
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(city.worldClockTimeZone, forType: .string)
            }) {
                Label("复制时区", systemImage: "doc.on.doc")
            }
            
            Button(role: .destructive, action: {
                // 删除功能通过外部传入
            }) {
                Label("删除", systemImage: "trash")
            }
        }
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                worldClockCardHovered = hovering
                worldClockCardScale = hovering ? 1.02 : 1.0
            }
        }
    }
    
    private var worldClockCityTime: Date {
        let timezone = TimeZone(identifier: city.worldClockTimeZone) ?? TimeZone.current
        let offset = timezone.secondsFromGMT(for: currentTime)
        let localOffset = TimeZone.current.secondsFromGMT(for: currentTime)
        return currentTime.addingTimeInterval(Double(offset - localOffset))
    }
    
    private var worldClockFormattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: city.worldClockTimeZone)
        return formatter.string(from: currentTime)
    }
    
    private var worldClockFormattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd EEEE"
        formatter.timeZone = TimeZone(identifier: city.worldClockTimeZone)
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: currentTime)
    }
    
    private var worldClockTimeZoneOffset: String {
        let timezone = TimeZone(identifier: city.worldClockTimeZone) ?? TimeZone.current
        let offset = timezone.secondsFromGMT(for: currentTime) / 3600
        let sign = offset >= 0 ? "+" : ""
        return "UTC\(sign)\(offset)"
    }
}

// MARK: - Analog Clock
struct WorldClockAnalogClock: View {
    let date: Date
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // 表盘
            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: size, height: size)
            
            Circle()
                .stroke(Color.indigo.opacity(0.3), lineWidth: 2)
                .frame(width: size, height: size)
            
            // 刻度
            ForEach(0..<12) { index in
                Rectangle()
                    .fill(Color.secondary)
                    .frame(width: 1.5, height: index % 3 == 0 ? 6 : 4)
                    .offset(y: -size / 2 + 6)
                    .rotationEffect(.degrees(Double(index) * 30))
            }
            
            // 时针
            Rectangle()
                .fill(Color.primary)
                .frame(width: 2, height: size * 0.25)
                .offset(y: -size * 0.125)
                .rotationEffect(.degrees(worldClockHourAngle))
            
            // 分针
            Rectangle()
                .fill(Color.primary)
                .frame(width: 1.5, height: size * 0.35)
                .offset(y: -size * 0.175)
                .rotationEffect(.degrees(worldClockMinuteAngle))
            
            // 秒针
            Rectangle()
                .fill(Color.indigo)
                .frame(width: 1, height: size * 0.4)
                .offset(y: -size * 0.2)
                .rotationEffect(.degrees(worldClockSecondAngle))
            
            // 中心点
            Circle()
                .fill(Color.indigo)
                .frame(width: 4, height: 4)
        }
        .frame(width: size, height: size)
    }
    
    private var worldClockHourAngle: Double {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return Double(hour % 12) * 30 + Double(minute) * 0.5
    }
    
    private var worldClockMinuteAngle: Double {
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: date)
        let second = calendar.component(.second, from: date)
        return Double(minute) * 6 + Double(second) * 0.1
    }
    
    private var worldClockSecondAngle: Double {
        let calendar = Calendar.current
        let second = calendar.component(.second, from: date)
        return Double(second) * 6
    }
}

// MARK: - Add City View
struct WorldClockAddCityView: View {
    @ObservedObject var viewModel: WorldClockViewModel
    @Binding var isPresented: Bool
    @State private var worldClockSearchQuery = ""
    
    var worldClockFilteredCities: [WorldClockCity] {
        if worldClockSearchQuery.isEmpty {
            return viewModel.worldClockAvailableCities
        }
        return viewModel.worldClockAvailableCities.filter {
            $0.worldClockCityName.localizedCaseInsensitiveContains(worldClockSearchQuery) ||
            $0.worldClockCountry.localizedCaseInsensitiveContains(worldClockSearchQuery)
        }
    }
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 标题栏
                HStack {
                    Text("添加城市")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Spacer()
                    
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Divider()
                
                // 搜索栏
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("搜索城市或国家", text: $worldClockSearchQuery)
                        .textFieldStyle(.plain)
                    
                    if !worldClockSearchQuery.isEmpty {
                        Button(action: {
                            worldClockSearchQuery = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                
                // 城市列表
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(worldClockFilteredCities) { city in
                            WorldClockCityListItem(
                                city: city,
                                isAdded: viewModel.worldClockCities.contains(where: { $0.id == city.id }),
                                onAdd: {
                                    viewModel.addWorldClockCity(city)
                                }
                            )
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 420, height: 560)
        .focusable(false)
    }
}

// MARK: - City List Item
struct WorldClockCityListItem: View {
    let city: WorldClockCity
    let isAdded: Bool
    let onAdd: () -> Void
    @State private var worldClockItemHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            Text(city.worldClockFlag)
                .font(.system(size: 24))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(city.worldClockCityName)
                    .font(.system(size: 13, weight: .medium))
                Text(city.worldClockCountry)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isAdded {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.green.gradient)
            } else {
                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.indigo.gradient)
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(worldClockItemHovered ? 0.08 : 0.03))
        )
        .onHover { hovering in
            worldClockItemHovered = hovering
        }
    }
}

#Preview {
    WorldClockView()
}
