// ================================
// CatScheduleView.swift - 完整代码
// ================================

import SwiftUI
import Combine

struct CatScheduleView: View {
    @Environment(\.dismiss) var dismiss
    @State private var schedule: DailySchedule?
    @State private var isRefreshing = false
    @State private var currentTime = Date()
    
    // 定时器，每分钟更新一次当前时间
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(1)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 标题栏
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue.gradient)
                    
                    Text("小猫的一天")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Spacer()
                    
                    // 显示已发生/总数
                    if let schedule = schedule {
                        let happenedCount = schedule.events.filter {
                            $0.getTodayTimestamp() <= currentTime
                        }.count
                        Text("\(happenedCount)/\(schedule.events.count)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(0.1)))
                    }
                    
                    Button(action: refreshSchedule) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                            .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                    .disabled(isRefreshing)
                    
                    Button(action: { dismiss() }) {
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
                
                if let schedule = schedule {
                    let (visibleEvents, nextEvent) = filterEvents(schedule.events)
                    
                    if visibleEvents.isEmpty {
                        // 没有可显示的事件
                        emptyStateView(nextEvent: nextEvent)
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                // 已发生的事件
                                ForEach(visibleEvents) { event in
                                    EventRow(event: event, currentTime: currentTime)
                                        .transition(.asymmetric(
                                            insertion: .scale.combined(with: .opacity),
                                            removal: .opacity
                                        ))
                                }
                                
                                // 下一个即将到来的事件
                                if let next = nextEvent {
                                    NextEventCard(event: next, currentTime: currentTime)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .padding(20)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: visibleEvents.count)
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("正在生成小猫的日程...")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(width: 400, height: 500)
        .focusable(false)
        .onAppear {
            loadSchedule()
            setupNotificationObserver()
        }
        .onReceive(timer) { _ in
            // 每分钟更新当前时间
            currentTime = Date()
        }
    }
    
    // MARK: - Helper Views
    
    private func emptyStateView(nextEvent: CatScheduleEvent?) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.fill")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("小猫的一天还没开始")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
            
            if let next = nextEvent {
                VStack(spacing: 8) {
                    Text("即将到来")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Text(next.time)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.blue)
                        
                        Text(next.description)
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue.opacity(0.1))
                    )
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Methods
    
    private func filterEvents(_ events: [CatScheduleEvent]) -> ([CatScheduleEvent], CatScheduleEvent?) {
        let now = currentTime
        
        // 已发生的事件（时间已过）
        let visible = events.filter { $0.getTodayTimestamp() <= now }
        
        // 下一个未发生的事件
        let nextEvent = events.first { $0.getTodayTimestamp() > now }
        
        return (visible, nextEvent)
    }
    
    private func loadSchedule() {
        schedule = CatAIScheduleService.shared.getCurrentSchedule()
    }
    
    private func refreshSchedule() {
        isRefreshing = true
        CatAIScheduleService.shared.refreshSchedule()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isRefreshing = false
        }
    }
    
    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: .catScheduleUpdated,
            object: nil,
            queue: .main
        ) { notification in
            if let newSchedule = notification.object as? DailySchedule {
                schedule = newSchedule
            }
        }
    }
}

// MARK: - 事件行组件
struct EventRow: View {
    let event: CatScheduleEvent
    let currentTime: Date
    
    private var isHappening: Bool {
        let eventTime = event.getTodayTimestamp()
        let calendar = Calendar.current
        
        // 判断是否在当前这一小时内
        let eventHour = calendar.component(.hour, from: eventTime)
        let currentHour = calendar.component(.hour, from: currentTime)
        
        return eventHour == currentHour && eventTime <= currentTime
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 时间
            VStack(spacing: 4) {
                Text(event.time)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(isHappening ? .green : .blue)
                
                if isHappening {
                    Text("进行中")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.green)
                }
            }
            .frame(width: 60, alignment: .leading)
            
            // 分隔线
            Rectangle()
                .fill((isHappening ? Color.green : Color.blue).opacity(0.3))
                .frame(width: 2, height: 40)
            
            // 内容
            VStack(alignment: .leading, spacing: 4) {
                Text(event.description)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                
                HStack(spacing: 6) {
                    if isHappening {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("正在进行")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.green.opacity(0.2)))
                    } else if event.isNotified {
                        Text("已通知")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.blue.opacity(0.2)))
                    } else {
                        Text("已过期")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.gray.opacity(0.2)))
                    }
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHappening ? Color.green.opacity(0.08) : Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isHappening ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
    }
}

// MARK: - 下一个事件卡片
struct NextEventCard: View {
    let event: CatScheduleEvent
    let currentTime: Date
    
    private var timeUntil: String {
        let eventTime = event.getTodayTimestamp()
        let interval = eventTime.timeIntervalSince(currentTime)
        let minutes = Int(interval / 60)
        
        if minutes < 60 {
            return "\(minutes)分钟后"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hours)小时后"
            }
            return "\(hours)小时\(mins)分钟后"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                
                Text("即将到来")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.orange)
                
                Spacer()
                
                Text(timeUntil)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.1))
            
            // 内容
            HStack(spacing: 12) {
                Text(event.time)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
                    .frame(width: 60, alignment: .leading)
                
                Rectangle()
                    .fill(Color.orange.opacity(0.3))
                    .frame(width: 2, height: 40)
                
                Text(event.description)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}
