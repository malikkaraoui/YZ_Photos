import SwiftUI

/// Onglet Corbeille : restaurer fichier par fichier, ou tout supprimer
/// définitivement (« Vider la corbeille (libérer X Go) »).
struct TrashView: View {
    let drive: DriveRecord
    let root: URL

    @Environment(AppEnvironment.self) private var env
    @Environment(\.yzTheme) private var theme
    @State private var files: [FileRecord] = []
    @State private var selectedFile: FileRecord?
    @State private var confirmEmpty = false
    @State private var lastFreed: (count: Int, bytes: Int64)?
    @State private var isWorking = false
    @State private var cellSize: CGFloat = 150
    @State private var baseCellSize: CGFloat = 150
    /// Appui long → sélection multiple : restaurer ou supprimer définitivement.
    @State private var selectionMode = false
    @State private var selection = Set<Int64>()
    @State private var confirmDeleteSelection = false

    private var totalBytes: Int64 { files.reduce(0) { $0 + $1.sizeBytes } }

    var body: some View {
        NavigationStack {
            MasterDetailLayout(
                selectedFile: $selectedFile,
                root: root,
                onAction: { Task { await reload() } },
                selectionSummary: selectionMode && !selection.isEmpty
                    ? SelectionSummary(files: files.filter { f in f.id.map { selection.contains($0) } ?? false })
                    : nil
            ) {
                if files.isEmpty {
                    YZEmptyState(
                        systemImage: "trash",
                        title: "Corbeille vide",
                        message: "Les fichiers mis à la poubelle pendant le tri arrivent ici. Rien n'est supprimé tant que tu ne vides pas la corbeille."
                    )
                    .yzScreenBackground(theme)
                } else {
                    ScrollView {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "info.circle.fill")
                            Text("Rien n'est supprimé tant que tu ne vides pas la corbeille. \(Fmt.count(files.count)) fichiers · \(Fmt.bytes(totalBytes)).")
                                .font(YZFont.footnote)
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(theme.accent)
                        .padding(12)
                        .background(theme.accentSoft, in: RoundedRectangle(cornerRadius: YZRadius.card, style: .continuous))
                        .padding(.horizontal)
                        .padding(.top, 6)

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: cellSize), spacing: 6)],
                            spacing: 6
                        ) {
                            ForEach(files) { file in
                                trashCell(file)
                            }
                        }
                        .padding(.horizontal, 6)
                    }
                    .refreshable { await reload() }
                    .simultaneousGesture(
                        MagnifyGesture()
                            .onChanged { value in
                                cellSize = min(max(baseCellSize * value.magnification, 80), 400)
                            }
                            .onEnded { _ in
                                baseCellSize = cellSize
                            }
                    )
                    .scrollContentBackground(.hidden)
                    .yzScreenBackground(theme)
                }
            }
            .navigationTitle(selectionMode ? "\(selection.count) sélectionnés" : "Corbeille")
            .toolbar {
                if selectionMode {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annuler") {
                            selectionMode = false
                            selection.removeAll()
                        }
                    }
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Tout sélectionner") {
                            selection = Set(files.compactMap(\.id))
                        }
                    }
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Tout désélectionner") {
                            selection.removeAll()
                        }
                        .disabled(selection.isEmpty)
                    }
                    ToolbarItem(placement: .secondaryAction) {
                        Button(role: .destructive) {
                            confirmEmpty = true
                        } label: {
                            Label("Vider la corbeille", systemImage: "trash.slash")
                        }
                        .disabled(isWorking)
                    }
                    // Croix directe : vide la sélection sans passer par le menu « … ».
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            selection.removeAll()
                        } label: {
                            Label("Désélectionner", systemImage: "xmark.circle.fill")
                        }
                        .disabled(selection.isEmpty)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            restoreSelection()
                        } label: {
                            Label("Restaurer (\(selection.count))", systemImage: "arrow.uturn.backward")
                        }
                        .tint(theme.accent)
                        .disabled(selection.isEmpty || isWorking)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button(role: .destructive) {
                            confirmDeleteSelection = true
                        } label: {
                            Label("Supprimer définitivement (\(selection.count) · \(Fmt.bytes(selectedBytes)))",
                                  systemImage: "xmark.bin.fill")
                        }
                        .disabled(selection.isEmpty || isWorking)
                    }
                } else if !files.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button(role: .destructive) {
                            confirmEmpty = true
                        } label: {
                            Label("Vider la corbeille (libérer \(Fmt.bytes(totalBytes)))", systemImage: "trash.slash")
                        }
                        .disabled(isWorking)
                    }
                }
            }
        }
        .task(id: drive.id) { await reload() }
        // Recharge à CHAQUE ouverture de l'onglet : un onglet inactif n'observe pas
        // toujours changeTick → sans ça, la corbeille restait vide après un tri tant
        // qu'on n'avait pas reconnecté le disque.
        .onAppear { Task { await reload() } }
        .onChange(of: env.triage?.changeTick) { _, _ in
            Task { await reload() }
        }
        .confirmationDialog(
            "Supprimer définitivement \(Fmt.count(files.count)) fichiers et libérer \(Fmt.bytes(totalBytes)) ? Cette action est irréversible.",
            isPresented: $confirmEmpty,
            titleVisibility: .visible
        ) {
            Button("Vider la corbeille", role: .destructive) { emptyTrash() }
            Button("Annuler", role: .cancel) {}
        }
        .confirmationDialog(
            "Supprimer définitivement \(Fmt.count(selection.count)) fichiers sélectionnés (\(Fmt.bytes(selectedBytes))) ? Cette action est irréversible.",
            isPresented: $confirmDeleteSelection,
            titleVisibility: .visible
        ) {
            Button("Supprimer définitivement", role: .destructive) { deleteSelection() }
            Button("Annuler", role: .cancel) {}
        }
        .alert(
            "Suppression définitive",
            isPresented: .init(get: { lastFreed != nil }, set: { if !$0 { lastFreed = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            if let lastFreed {
                Text("\(Fmt.count(lastFreed.count)) fichiers supprimés · \(Fmt.bytes(lastFreed.bytes)) libérés.")
            }
        }
    }

    @ViewBuilder
    private func trashCell(_ file: FileRecord) -> some View {
        let isSelected = file.id.map { selection.contains($0) } ?? false
        ThumbnailCell(file: file, root: root, showSize: true)
            .overlay {
                if selectionMode && isSelected {
                    RoundedRectangle(cornerRadius: YZRadius.chip, style: .continuous)
                        .fill(theme.accent.opacity(0.3))
                    RoundedRectangle(cornerRadius: YZRadius.chip, style: .continuous)
                        .strokeBorder(theme.accent, lineWidth: 2)
                }
            }
            .overlay(alignment: .topLeading) {
                if !selectionMode {
                    restoreButton(file)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if selectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? theme.accent : .white)
                        .shadow(radius: 3)
                        .padding(6)
                }
            }
            .onTapGesture {
                if selectionMode {
                    guard let id = file.id else { return }
                    if selection.contains(id) {
                        selection.remove(id)
                    } else {
                        selection.insert(id)
                    }
                } else {
                    selectedFile = file
                }
            }
            .onLongPressGesture {
                if !selectionMode {
                    selectionMode = true
                    if let id = file.id { selection.insert(id) }
                }
            }
    }

    private var selectedTrashFiles: [FileRecord] {
        files.filter { file in file.id.map { selection.contains($0) } ?? false }
    }

    private var selectedBytes: Int64 {
        selectedTrashFiles.reduce(0) { $0 + $1.sizeBytes }
    }

    private func deleteSelection() {
        guard let triage = env.triage else { return }
        let toDelete = selectedTrashFiles
        isWorking = true
        Task {
            if let result = try? await triage.deletePermanently(toDelete) {
                lastFreed = result
            }
            selectionMode = false
            selection.removeAll()
            await reload()
            isWorking = false
        }
    }

    private func restoreSelection() {
        guard let triage = env.triage else { return }
        let toRestore = files.filter { file in file.id.map { selection.contains($0) } ?? false }
        isWorking = true
        Task {
            try? await triage.restoreAll(toRestore)
            selectionMode = false
            selection.removeAll()
            await reload()
            isWorking = false
        }
    }

    private func restoreButton(_ file: FileRecord) -> some View {
        Button {
            guard let triage = env.triage else { return }
            isWorking = true
            Task {
                try? await triage.restore(file)
                await reload()
                isWorking = false
            }
        } label: {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .font(.title2)
                .foregroundStyle(.white, theme.accent)
        }
        .padding(5)
        .disabled(isWorking)
    }

    private func emptyTrash() {
        guard let triage = env.triage else { return }
        isWorking = true
        Task {
            if let result = try? await triage.emptyTrash() {
                lastFreed = result
            }
            await reload()
            isWorking = false
        }
    }

    private func reload() async {
        let driveId = drive.id
        files = (try? await env.database.writer.read { db in
            try Queries.trashedFiles(driveId: driveId).fetchAll(db)
        }) ?? []
        // Le fichier en aperçu n'est plus dans la corbeille (supprimé ou restauré)
        // → on vide l'aperçu, sinon il resterait affiché à droite.
        if let sel = selectedFile?.id, !files.contains(where: { $0.id == sel }) {
            selectedFile = nil
        }
        // Purge la sélection des fichiers disparus.
        selection.formIntersection(Set(files.compactMap(\.id)))
    }
}
