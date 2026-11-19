//
//  Components.swift
//  PantrixRortySwiftUI
//
//  Small shared views. Kept here rather than duplicated per feature so the three list screens cannot
//  drift apart visually.
//

import Kingfisher
import SwiftUI

/// Full-screen state message — empty result, or a load failure.
struct StateMessage: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
            .listRowSeparator(.hidden)
    }
}

/// Footer spinner shown while a next page is in flight.
struct LoadingMoreFooter: View {
    var body: some View {
        HStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .padding(.vertical, 8)
        .listRowSeparator(.hidden)
    }
}

/// Status → colour. One definition, so a list row and a detail row can never disagree.
func statusColor(_ status: CharacterStatus) -> Color {
    switch status {
    case .alive: return .green
    case .dead: return .red
    case .unknown: return .gray
    }
}

/// The coloured dot + "Alive • Human" subtitle used by every character *list row*.
struct CharacterSubtitle: View {
    let status: CharacterStatus
    let species: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor(status))
                .frame(width: 8, height: 8)
            Text("\(status.display) • \(species)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

/// One character in a list.
struct CharacterRow: View {
    let character: Character

    var body: some View {
        HStack(spacing: 12) {
            KFImage(character.imageURL)
                .placeholder { Image(systemName: "person.circle").foregroundStyle(.tertiary) }
                .fade(duration: 0.2)
                .cacheOriginalImage()
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(character.name)
                    .font(.headline)
                    .lineLimit(1)
                CharacterSubtitle(status: character.status, species: character.species)
            }
        }
        .padding(.vertical, 4)
    }
}

/// One episode in a list.
struct EpisodeRow: View {
    let episode: Episode

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(episode.name).font(.headline).lineLimit(1)
            Text("\(episode.code) • \(episode.airDate)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

/// Caption on the left, value on the right — the detail screens' one row type.
struct DetailRow: View {
    let caption: String
    let value: String
    /// When set, the value is rendered as a coloured status pill instead of plain text. The `value`
    /// is then ignored — a status row states the status, nothing else. (An earlier version reused
    /// `CharacterSubtitle` here and printed "Alive • Human" on a row already followed by a Species
    /// row saying "Human".)
    var status: CharacterStatus?

    var body: some View {
        HStack(alignment: .top) {
            Text(caption)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            if let status {
                HStack(spacing: 6) {
                    Spacer()
                    Circle().fill(statusColor(status)).frame(width: 8, height: 8)
                    Text(status.display)
                }
            } else {
                // Empty is common on this API (a character's `type`, a location's `dimension`).
                // Showing an em dash keeps the row's meaning visible instead of hiding the field.
                Text(value.isEmpty ? "—" : value)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.vertical, 2)
    }
}

/// A trial of MQ on GitHub: a forced cast, which the catalogue stops a change for, and a space after the name of an
/// attribute, which SwiftLint calls an error and the catalogue does not stop for.
@available (iOS 17, *)
func forcedNumber(_ value: Any) -> Int {
    value as! Int
}
