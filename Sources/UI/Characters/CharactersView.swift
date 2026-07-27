//
//  CharactersView.swift
//  PantrixRortySwiftUI
//

import PantrixSwiftUI
import SwiftUI

struct CharactersView: View {

    @State private var vm = CharactersViewModel()
    @Binding var path: [Route]
    @State private var errorMessage: String?

    var body: some View {
        List {
            Picker("Status", selection: statusBinding) {
                Text("All").tag(CharacterStatus?.none)
                ForEach(CharacterStatus.allCases, id: \.self) { status in
                    Text(status.display).tag(CharacterStatus?.some(status))
                }
            }
            .pickerStyle(.segmented)
            .listRowSeparator(.hidden)

            if let message = vm.state.message {
                StateMessage(text: message)
            }

            ForEach(vm.state.items) { character in
                Button {
                    vm.onIntent(.selected(character))
                } label: {
                    CharacterRow(character: character)
                }
                .buttonStyle(.plain)
                .onAppear {
                    // Prefetch trigger: five rows from the end, matching the UIKit demo so the two
                    // apps issue a comparable number of page requests.
                    if character.id == vm.state.items.suffix(5).first?.id {
                        vm.onIntent(.reachedEnd)
                    }
                }
            }

            if vm.state.isLoadingMore {
                LoadingMoreFooter()
            }
        }
        .listStyle(.plain)
        .overlay {
            if vm.state.isLoading && vm.state.items.isEmpty {
                ProgressView()
            }
        }
        .navigationTitle("Characters")
        .searchable(text: queryBinding, prompt: "Search characters")
        .refreshable { vm.onIntent(.refresh) }
        .task { vm.onIntent(.appear) }
        // Automatic screen tracking cannot see this — the whole app is one UIHostingController.
        .trackScreen("Characters")
        .onReceive(vm.effect) { effect in
            switch effect {
            case let .navigate(route): path.append(route)
            case let .showError(message): errorMessage = message
            }
        }
        .alert("Couldn't load more", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    /// The text field writes through an intent rather than binding straight into state, so the
    /// debounce and the filter event stay in the view model where the other intents live.
    private var queryBinding: Binding<String> {
        Binding(
            get: { vm.state.query },
            set: { vm.onIntent(.queryChanged($0)) }
        )
    }

    private var statusBinding: Binding<CharacterStatus?> {
        Binding(
            get: { vm.state.status },
            set: { vm.onIntent(.statusSelected($0)) }
        )
    }
}
