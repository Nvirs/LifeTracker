import SwiftUI

struct NotesView: View {
    @State private var notes = [
        "Project Ideas",
        "Vacation Plans",
        "Book Recommendations",
        "Grocery List"
    ]
    
    @State private var newNote = ""
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Add Note")) {
                    HStack {
                        TextField("New note...", text: $newNote)
                        Button(action: {
                            if !newNote.isEmpty {
                                notes.insert(newNote, at: 0)
                                newNote = ""
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.pink)
                        }
                    }
                }
                
                Section(header: Text("Recent Notes")) {
                    ForEach(notes, id: \.self) { note in
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.pink)
                            Text(note)
                        }
                    }
                    .onDelete { indexSet in
                        notes.remove(atOffsets: indexSet)
                    }
                }
            }
            .navigationTitle("Notes")
        }
    }
}