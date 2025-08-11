//
//  StrukturCombine.swift
//  Data SDI
//
//  Created by MacBook on 21/07/25.
//

import Cocoa
import Combine

extension Struktur {
    func setupCombine() {
        viewModel.strukturEvent
            .receive(on: DispatchQueue.global(qos: .background))
            .flatMap(maxPublishers: .max(1)) { event in
                Just(event)
                    .delay(for: .milliseconds(100), scheduler: DispatchQueue.global(qos: .background))
            }
            .sink { [weak self] event in
                guard let self else { return }
                switch event {
                case let .updated(guruu):
                    reloadGuru(guruu)
                case let .deleted(guruu):
                    removeGuru(guruu)
                case let .inserted(guru):
                    insertGuru(guru)
                case let .moved(oldGuru: old, updatedGuru: new):
                    removeGuru([old])
                    insertGuru(new)
                }
            }
            .store(in: &cancellable)
    }

    func insertGuru(_ newGuru: GuruModel) {
        let key = newGuru.struktural ?? "-"

        if let strukturIndex = viewModel.strukturDict.firstIndex(where: { $0.struktural == key }) {
            // Grup sudah ada
            guard let insertIndex = viewModel.insertStruktur(strukturIndex, guru: newGuru) else { return }
            let parentItem = viewModel.strukturDict[strukturIndex]

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                outlineView.insertItems(at: IndexSet(integer: insertIndex), inParent: parentItem, withAnimation: .effectGap)
            }

        } else if let (strukturIndex, _) = viewModel.insertGuruInStruktur(newGuru) {
            // Grup belum ada, baru dibuat
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                outlineView.insertItems(at: IndexSet(integer: strukturIndex), inParent: nil, withAnimation: .slideDown)
                outlineView.expandItem(viewModel.strukturDict[strukturIndex])
            }
        }
    }

    func removeGuru(_ deletedGuruList: [GuruModel]) {
        for deletedGuru in deletedGuruList {
            guard let strukturalKey = deletedGuru.struktural ?? "-" as String?,
                  let (parent, guru) = findGuru(withId: deletedGuru.idGuru, in: viewModel.strukturDict.filter { $0.struktural == strukturalKey })
            else {
                #if DEBUG
                    print("Guru with ID \(deletedGuru.idGuru) not found in structural group \(deletedGuru.struktural ?? "nil").")
                #endif
                return
            }

            if let parentIndex = viewModel.strukturDict.firstIndex(where: { $0.struktural == parent.struktural }),
               let guruIndex = parent.guruList.firstIndex(where: { $0.idGuru == guru.idGuru })
            {
                let isParentRemoved = viewModel.removeStruktur(parentIndex, guruIndex: guruIndex)

                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    if isParentRemoved {
                        outlineView.removeItems(at: IndexSet(integer: parentIndex), inParent: nil)
                    } else {
                        outlineView.removeItems(at: IndexSet(integer: guruIndex), inParent: parent)
                    }
                }
            }
        }
    }

    func reloadGuru(_ newData: [GuruModel]) {
        for newGuru in newData {
            guard let (_, guru) = findGuru(withId: newGuru.idGuru, in: viewModel.strukturDict),
                  guru.namaGuru != newGuru.namaGuru else { continue }

            guru.namaGuru = newGuru.namaGuru
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                outlineView.reloadItem(guru)
            }
        }
    }

    func findGuru(withId idGuru: Int64, in strukturDict: [StrukturGuruDictionary]) -> (StrukturGuruDictionary, GuruModel)? {
        for parent in strukturDict {
            if let guru = parent.guruList.first(where: { $0.idGuru == idGuru }) {
                return (parent, guru)
            }
        }
        return nil
    }
}
