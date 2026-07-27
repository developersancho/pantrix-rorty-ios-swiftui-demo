//
//  CharacterDetailView.swift
//  PantrixRortySwiftUI
//

import Kingfisher
import Pantrix
import SwiftUI

/// A character's details, plus the drill-in to the episodes it appears in.
///
/// **No view model, on purpose.** MVI manages state and asynchronous work; this screen has neither —
/// it receives a fully-loaded entity and its one action appends a route. Adding a view model here
/// would be ceremony, and ceremony is what makes a pattern get abandoned.
///
/// **No `.trackScreen` either.** The screen is reported by `.trackNavigation(path:)` on the enclosing
/// stack, and adding one here would report every push twice.
struct CharacterDetailView: View {

    let character: Character
    @Binding var path: [Route]

    var body: some View {
        List {
            Section {
                KFImage(character.imageURL)
                    .placeholder { Color.secondary.opacity(0.1) }
                    .fade(duration: 0.2)
                    .cacheOriginalImage()
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
            }

            Section {
                DetailRow(caption: "Status", value: "", status: character.status)
                DetailRow(caption: "Species", value: character.species)
                DetailRow(caption: "Gender", value: character.gender.display)
                DetailRow(caption: "Type", value: character.type)
                DetailRow(caption: "Origin", value: character.originName)
                DetailRow(caption: "Location", value: character.locationName)
            }

            Section {
                Button {
                    Pantrix.track("character_episodes_opened", attributes: [
                        "id": character.id,
                        "count": character.episodeIds.count
                    ])
                    path.append(.episodesByIds(ids: character.episodeIds, title: "Episodes"))
                } label: {
                    HStack {
                        Text("Episodes (\(character.episodeIds.count))")
                        Spacer()
                        Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
                    }
                }
                .disabled(character.episodeIds.isEmpty)
            }
        }
        .navigationTitle(character.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
