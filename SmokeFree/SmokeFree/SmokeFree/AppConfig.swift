import Foundation

// MARK: - 健康恢复里程碑

struct HealthMilestone: Identifiable {
    let id: String
    let offsetSeconds: TimeInterval
    let title: String
    let description: String
    let iconName: String
}

// MARK: - 成就徽章定义

struct AchievementDefinition: Identifiable {
    let id: String
    let title: String
    let description: String
    let iconName: String
    let requiredStreakDays: Int?
    let requiredMoneySaved: Double?
    // 减量类条件
    let requiredConsecutiveDaysBelow: Int?  // 连续 N 天吸烟量 < 基准
    let requiredReductionPercent: Double?   // 近 7 天日均 ≤ 基准 × percent（0.5 = 减少50%）

    init(
        id: String, title: String, description: String, iconName: String,
        requiredStreakDays: Int? = nil, requiredMoneySaved: Double? = nil,
        requiredConsecutiveDaysBelow: Int? = nil, requiredReductionPercent: Double? = nil
    ) {
        self.id = id; self.title = title; self.description = description; self.iconName = iconName
        self.requiredStreakDays = requiredStreakDays; self.requiredMoneySaved = requiredMoneySaved
        self.requiredConsecutiveDaysBelow = requiredConsecutiveDaysBelow
        self.requiredReductionPercent = requiredReductionPercent
    }
}

// MARK: - 烟草开销对比预设

struct CostComparisonPreset: Identifiable {
    let id: String
    let name: String
    let amount: Double
    let iconName: String
}

// MARK: - AppConfig

enum AppConfig {
    static let healthMilestones: [HealthMilestone] = [
        HealthMilestone(
            id: "day1",
            offsetSeconds: 86_400,
            title: "控烟第一天",
            description: "迈出第一步，改变从今天开始。",
            iconName: "flag.fill"
        ),
        HealthMilestone(
            id: "3days",
            offsetSeconds: 259_200,
            title: "坚持三天",
            description: "烟瘾高峰期已过，最难的阶段正在结束。",
            iconName: "bolt.heart"
        ),
        HealthMilestone(
            id: "1week",
            offsetSeconds: 604_800,
            title: "一周控烟",
            description: "坚持一周！烟瘾开始减弱，身体逐渐适应。",
            iconName: "7.circle.fill"
        ),
        HealthMilestone(
            id: "2weeks",
            offsetSeconds: 1_209_600,
            title: "两周里程碑",
            description: "吸烟冲动明显减少，睡眠质量开始改善。",
            iconName: "moon.stars.fill"
        ),
        HealthMilestone(
            id: "1month",
            offsetSeconds: 2_592_000,
            title: "一个月突破",
            description: "持续控烟一个月，已逐渐形成新的行为习惯。",
            iconName: "calendar"
        ),
        HealthMilestone(
            id: "2months",
            offsetSeconds: 5_184_000,
            title: "两个月坚持",
            description: "呼吸更顺畅，运动耐力开始提升。",
            iconName: "lungs.fill"
        ),
        HealthMilestone(
            id: "3months",
            offsetSeconds: 7_776_000,
            title: "三个月荣耀",
            description: "季度控烟成功！肺功能显著改善，精力更充沛。",
            iconName: "trophy.fill"
        ),
        HealthMilestone(
            id: "6months",
            offsetSeconds: 15_552_000,
            title: "半年里程碑",
            description: "半年控烟成果斐然，心血管健康持续改善。",
            iconName: "heart.circle.fill"
        ),
        HealthMilestone(
            id: "1year",
            offsetSeconds: 31_536_000,
            title: "年度成就",
            description: "坚持控烟整整一年，你的身体感谢你的坚持！",
            iconName: "star.fill"
        ),
    ]

    static let achievementDefinitions: [AchievementDefinition] = [
        // MARK: 控烟坚持类徽章（连续低于基准天数）
        AchievementDefinition(
            id: "streak_1_day",
            title: "迈出第一步",
            description: "连续控烟 1 天，低于基准用量",
            iconName: "1.circle.fill",
            requiredConsecutiveDaysBelow: 1
        ),
        AchievementDefinition(
            id: "streak_3_days",
            title: "三日勇士",
            description: "连续 3 天低于基准用量",
            iconName: "3.circle.fill",
            requiredConsecutiveDaysBelow: 3
        ),
        AchievementDefinition(
            id: "streak_1_week",
            title: "坚持一周",
            description: "连续 7 天低于基准用量",
            iconName: "7.circle.fill",
            requiredConsecutiveDaysBelow: 7
        ),
        AchievementDefinition(
            id: "streak_1_month",
            title: "月度冠军",
            description: "连续 30 天低于基准用量",
            iconName: "calendar",
            requiredConsecutiveDaysBelow: 30
        ),
        AchievementDefinition(
            id: "streak_3_months",
            title: "季度英雄",
            description: "连续 90 天低于基准用量",
            iconName: "trophy.fill",
            requiredConsecutiveDaysBelow: 90
        ),
        AchievementDefinition(
            id: "streak_6_months",
            title: "半年里程碑",
            description: "连续 180 天低于基准用量",
            iconName: "medal.fill",
            requiredConsecutiveDaysBelow: 180
        ),
        AchievementDefinition(
            id: "streak_1_year",
            title: "年度荣耀",
            description: "连续 365 天低于基准用量",
            iconName: "crown.fill",
            requiredConsecutiveDaysBelow: 365
        ),

        // MARK: 减量幅度徽章
        AchievementDefinition(
            id: "reduction_half",
            title: "减半达人",
            description: "近 7 天日均用量减少 50%",
            iconName: "minus.circle.fill",
            requiredReductionPercent: 0.5
        ),
        AchievementDefinition(
            id: "reduction_quarter",
            title: "接近清零",
            description: "近 7 天日均用量减少 75%",
            iconName: "flame",
            requiredReductionPercent: 0.25
        ),

        // MARK: 节省金额徽章
        AchievementDefinition(
            id: "money_100",
            title: "省下百元",
            description: "累计节省 100 元",
            iconName: "yensign.circle.fill",
            requiredMoneySaved: 100
        ),
        AchievementDefinition(
            id: "money_500",
            title: "省下五百",
            description: "累计节省 500 元",
            iconName: "banknote.fill",
            requiredMoneySaved: 500
        ),
    ]

    static let costComparisonPresets: [CostComparisonPreset] = [
        CostComparisonPreset(id: "iphone",   name: "iPhone 16",      amount: 6_999,   iconName: "iphone"),
        CostComparisonPreset(id: "macbook",  name: "MacBook Air",    amount: 8_499,   iconName: "laptopcomputer"),
        CostComparisonPreset(id: "trip",     name: "欧洲旅行",        amount: 30_000,  iconName: "airplane"),
        CostComparisonPreset(id: "bmw3",     name: "宝马 3 系",      amount: 300_000, iconName: "car.fill"),
        CostComparisonPreset(id: "model3",   name: "特斯拉 Model 3", amount: 239_900, iconName: "bolt.car.fill"),
        CostComparisonPreset(id: "house_dp", name: "首付款",         amount: 300_000, iconName: "house.fill"),
    ]
}
