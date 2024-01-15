//
//  SearchTest.swift
//  Ruddarr
//
//  Created by Till Krüss on 15/1/24.
//

import SwiftUI

struct SearchTest: View {
    @State private var searchText: String = ""
    
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
        SearchBar(text: $searchText, onTextChanged: searchMovies)
    }
    
    func searchMovies(for searchText: String) {
        if !searchText.isEmpty {
            print(searchText)
        }
    }
}

#Preview {
    SearchTest()
}

import SwiftUI

struct SearchBar: UIViewRepresentable {
    @Binding var text: String
    var onTextChanged: (String) -> Void
    
    class Coordinator: NSObject, UISearchBarDelegate {
        var onTextChanged: (String) -> Void
        @Binding var text: String
        
        init(text: Binding<String>, onTextChanged: @escaping (String) -> Void) {
            _text = text
            self.onTextChanged = onTextChanged
        }
        
        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            text = searchText
            onTextChanged(text)
        }
    }
    
    func makeCoordinator() -> SearchBar.Coordinator {
        return Coordinator(text: $text, onTextChanged: onTextChanged)
    }
    
    func makeUIView(context: UIViewRepresentableContext<SearchBar>) -> UISearchBar {
        let searchBar = UISearchBar(frame: .zero)
        searchBar.delegate = context.coordinator
        searchBar.searchBarStyle = .minimal
        searchBar.autocapitalizationType = .none
        return searchBar
    }
    
    func updateUIView(_ uiView: UISearchBar, context: UIViewRepresentableContext<SearchBar>) {
        uiView.text = text
    }
}
