//
//  CatStatisticsView.swift
//  Conven
//
//  Created by 土豆星球 on 2025/10/11.
//


import SwiftUI

// MARK: - 统计详情视图
struct CatStatisticsView: View {
    @ObservedObject var viewModel: CatViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(1)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 标题栏
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue.gradient)
                    
                    Text("数据统计")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .cursor(.pointingHand)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Divider()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // 存活信息卡片
                        summaryCard
                        
                        // 当前状态
                        currentStatusCard
                        
                        // 互动统计
                        interactionStatsCard
                        
                        // 历史记录（预留）
                        historyCard
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 400, height: 550)
    }
    
    // MARK: - 概要卡片
    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.catName)
                        .font(.system(size: 20, weight: .bold))
                    
                    Text(viewModel.isAlive ? "健康成长中" : "已离世")
                        .font(.system(size: 12))
                        .foregroundColor(viewModel.isAlive ? .green : .secondary)
                }
                
                Spacer()
                
                Text(CatConfig.Info.emoji)
                    .font(.system(size: 48))
            }
            
            Divider()
            
            HStack(spacing: 20) {
                statItem(label: "存活天数", value: "\(viewModel.getLiveDays())", unit: "天")
                
                Divider()
                    .frame(height: 30)
                
                statItem(label: "总互动", value: "\(totalInteractions)", unit: "次")
                
                Divider()
                    .frame(height: 30)
                
                statItem(label: "平均状态", value: "\(averageStats)", unit: "%")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
    }
    
    // MARK: - 当前状态卡片
    private var currentStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("当前状态")
                .font(.system(size: 14, weight: .semibold))
            
            VStack(spacing: 12) {
                circularStatBar(label: "心情", value: viewModel.mood, color: .blue)
                circularStatBar(label: "饥饿", value: viewModel.hunger, color: .orange)
                circularStatBar(label: "清洁", value: viewModel.cleanliness, color: .green)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
    }
    
    // MARK: - 互动统计卡片
    private var interactionStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("互动统计")
                .font(.system(size: 14, weight: .semibold))
            
            VStack(spacing: 10) {
                interactionRow(icon: "gamecontroller.fill", label: "陪玩", count: viewModel.totalPlayCount, color: .blue)
                interactionRow(icon: "fork.knife", label: "喂食", count: viewModel.totalFeedCount, color: .orange)
                interactionRow(icon: "sparkles", label: "清洁", count: viewModel.totalCleanCount, color: .green)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
    }
    
    // MARK: - 历史记录卡片（预留）
    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("历史记录")
                .font(.system(size: 14, weight: .semibold))
            
            VStack(spacing: 8) {
                ForEach(recentActivities, id: \.self) { activity in
                    HStack {
                        Circle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 6, height: 6)
                        
                        Text(activity)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.05))
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
    }
    
    // MARK: - Helper Views
    private func statItem(label: String, value: String, unit: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .monospacedDigit()
            
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func circularStatBar(label: String, value: Double, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 60, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(0.15))
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.gradient)
                        .frame(width: geometry.size.width * (value / 100))
                }
            }
            .frame(height: 12)
            
            Text("\(Int(value))")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .monospacedDigit()
                .frame(width: 35, alignment: .trailing)
        }
    }
    
    private func interactionRow(icon: String, label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
            }
            
            Text(label)
                .font(.system(size: 13))
            
            Spacer()
            
            Text("\(count) 次")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    // MARK: - Computed Properties
    private var totalInteractions: Int {
        viewModel.totalPlayCount + viewModel.totalFeedCount + viewModel.totalCleanCount
    }
    
    private var averageStats: Int {
        Int((viewModel.mood + viewModel.hunger + viewModel.cleanliness) / 3)
    }
    
    private var recentActivities: [String] {
        [
            "今天陪\(viewModel.catName)玩了很久",
            "心情看起来不错",
            "吃得很开心",
            "最近很爱干净"
        ]
    }
}

#Preview {
    CatStatisticsView(viewModel: CatViewModel())
}
