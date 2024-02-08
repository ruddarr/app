import os
import Foundation

func logger(_ category: String = "default") -> Logger {
    Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: category
    )
}
