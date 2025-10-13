//
//  PasswordStrength.swift
//  Conven
//
//  Created by 土豆星球 on 2025/10/13.
//


import Foundation

enum PasswordStrength {
    case weak
    case medium
    case strong
    
    var description: String {
        switch self {
        case .weak: return "密码强度：弱"
        case .medium: return "密码强度：中"
        case .strong: return "密码强度：强"
        }
    }
}

struct PasswordStrengthChecker {
    static func checkStrength(for password: String) -> PasswordStrength {
        let length = password.count
        
        // 简单规则示例：
        // 1. 长度小于8位 -> 弱
        if length < 8 {
            return .weak
        }
        
        // 2. 包含数字、大小写字母、特殊字符中的三种或以上 -> 强
        var strengthLevel = 0
        if password.rangeOfCharacter(from: .decimalDigits) != nil { strengthLevel += 1 }
        if password.rangeOfCharacter(from: .lowercaseLetters) != nil { strengthLevel += 1 }
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil { strengthLevel += 1 }
        if password.rangeOfCharacter(from: .punctuationCharacters) != nil { strengthLevel += 1 }
        
        if strengthLevel >= 3 {
            return .strong
        } else {
            return .medium
        }
    }
}