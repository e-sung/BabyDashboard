//
//  AppIntent.swift
//  DashboardWidget
//
//  Created by 류성두 on 11/3/25.
//

import WidgetKit
import AppIntents
import Model

// Widget configuration intent: pick a baby
struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Baby Widget" }
    static var description: IntentDescription { "Choose which baby to show in the widget." }

    @Parameter(title: "Baby")
    var baby: BabyProfileEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Show \(\.$baby)")
    }
}
