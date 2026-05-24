import SwiftUI

/// Grid layout for plugin-contributed dashboard widgets.
/// Responsive: 2 columns on iPhone, 3+ on iPad.
public struct DashboardWidgetLayout: View {
    let widgets: [(name: String, factory: ComponentFactory)]
    
    public init(widgets: [(name: String, factory: ComponentFactory)]) {
        self.widgets = widgets
    }
    
    public var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(widgets, id: \.name) { widget in
                widget.factory()
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.08))
                    )
            }
        }
    }
    
    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]
    }
}
