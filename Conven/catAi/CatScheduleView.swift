//
//  CatScheduleView.swift
//  Conven
//
//  Created by 土豆星球 on 2025/10/14.
//


import SwiftUI

struct CatScheduleView: View {
    @Environment(\.dismiss) var dismiss
    @State private var schedule: DailySchedule?
    @State private var isRefreshing = false
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(0.95)
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
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(schedule.events) { event in
                                EventRow(event: event)
                            }
                        }
                        .padding(20)
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

struct EventRow: View {
    let event: CatScheduleEvent
    
    var body: some View {
        HStack(spacing: 12) {
            // 时间
            Text(event.time)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.blue)
                .frame(width: 50, alignment: .leading)
            
            // 分隔线
            Rectangle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 2, height: 40)
            
            // 内容
            VStack(alignment: .leading, spacing: 4) {
                Text(event.description)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                
                if event.isNotified {
                    Text("已通知")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.green.opacity(0.2)))
                } else if event.getTodayTimestamp() < Date() {
                    Text("已过期")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.gray.opacity(0.2)))
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.1))
        )
    }
}
