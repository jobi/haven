import SwiftUI
import WidgetKit

@main
struct HavenWidgetBundle: WidgetBundle {
    var body: some Widget {
        SingleEntityWidget()
        ControlGridWidget()
        OptionPickerWidget()
        ClimateWidget()
        MediaPlayerWidget()
    }
}
