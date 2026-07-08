import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarSection

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "sidebar.left")
                Text("Field75 Mapper")
                    .font(.headline)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.top, 54)
            .padding(.bottom, 8)

            ForEach(SidebarSection.allCases) { section in
                Button {
                    selection = section
                } label: {
                    Label(section.title, systemImage: section.systemImage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
                .foregroundStyle(selection == section ? .white : .primary)
                .background(selection == section ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, 10)
            }

            Spacer()
        }
        .background(.regularMaterial)
    }
}
