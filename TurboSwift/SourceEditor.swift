//
//  SourceEditor.swift
//  TurboSwift
//
//  Created by Miguel de Icaza on 5/14/21.
//

import Foundation
import TermKit
import SwiftLSPClient
import TextBufferKit

class SourceEditor: TextView {
    var project: Project
    var server: LanguageServer
    var file: String
    var docId: TextDocumentIdentifier
    var changeId = 0
    
    public init (project: Project, file: String) {
        self.project = project
        self.server = project.server
        self.file = file
        self.docId = TextDocumentIdentifier (path: file)

        super.init ()
        textEditNotification = textEdited
    }
    
    func textEdited (_ range: TextRange, _ txt: String) {
        let range = LSPRange (start: Position (line: range.start.line, character: range.start.column),
                  end: Position (line: range.end.line, character: range.end.column))
        let ch = TextDocumentContentChangeEvent (range: range, rangeLength: nil, text: txt)
        let versionedDoc = VersionedTextDocumentIdentifier(uri: file, version: changeId)
        changeId += 1
        let change = DidChangeTextDocumentParams (textDocument: versionedDoc, contentChanges: [ch])
        server.didChangeTextDocument(params: change) { err in
            if let e = err {
                log (e.errorDescription ?? "error, but no error description")
            }
        }
    }
}

class SwiftSourceEditor: SourceEditor {
    
    public override init (project: Project, file: String) {
        super.init (project: project, file: file)
    }
   
    func removeCompletionWindow () {
        guard let cwin = completions else {
            return
        }
        cwin.superview?.remove(cwin)
        completionData = nil
        completions = nil
    }
    
    var completions: ListView?
    var completionData: CompletionHolder?
    
    class CompletionHolder: ListViewDataSource {
        func getCount(listView: ListView) -> Int {
            data.count
        }
        func isMarked(listView: ListView, item: Int) -> Bool { false }
        func setMark(listView: ListView, item: Int, state: Bool) { }
        
        var data: [CompletionItem]
        init (data: [CompletionItem]) {
            self.data = data
        }
    }
    
    func addCompletions (items: [CompletionItem]) {
        removeCompletionWindow ()
        completionData = CompletionHolder(data: items)
        let list = ListView(dataSource: completionData!) { row, width in
            if (self.completionData?.data.count ?? 0) > row+1 {
                return self.completionData?.data [row].label ?? ""
            } else {
                return ""
            }
        }
        list.allowMarking = false
        list.colorScheme = Colors.dialog
        list.selectedMarker = "→"
        list.set(x: currentColumn, y: currentRow+1-topRow, width: 30, height: 10)
        list.canFocus = false
        addSubview(list)
        completions = list
    }
    
    func complete (triggerChar: String? = nil) {
        let position = Position(line: currentRow, character: currentColumn)
        
        let ctx = CompletionContext (triggerKind: triggerChar == nil ? .invoked : .triggerCharacter, triggerCharacter: triggerChar)
        let completion = CompletionParams (textDocument: docId, position: position, context: ctx)
        server.completion(params: completion) { completion in
            switch completion {
            case .failure(let err):
                log (err.errorDescription ?? "unknown")
            case .success(let res):
                if res.items.count != 0 {
                    self.addCompletions (items: res.items)
                }
            }
        }
    }
    
    // This is useful to track completion at every point and debug things
    var completionAtEveryPoint = false
    
    // converts a language server protocol range into a TextView.TextRange
    func lspRangeToTextRange (lspRange: LSPRange) -> TextView.TextRange {
        return TextView.TextRange (start: TextBufferKit.Position (line: lspRange.start.line, column: lspRange.start.character),
                                   end: TextBufferKit.Position (line: lspRange.end.line, column: lspRange.end.character))
    }
    
    open override func processKey(event: KeyEvent) -> Bool {
        if !completionAtEveryPoint {
            if let completing = completions {
                switch event.key {
                case .controlJ:
                    let change = completionData!.data[completing.selectedItem]
                    
                    // TODO: instead of inserting the text, perform a text replacement operation based on .textEdit property
                    if let textEdit = change.textEdit {
                        let editorRange = lspRangeToTextRange(lspRange: textEdit.range)
                        applyTextEdit(range: editorRange, text: textEdit.newText)
                        setCursorPosition (position: advance (position: editorRange.start, count: textEdit.newText.count))
                    } else {
                        insert(text: change.label)
                    }
                    removeCompletionWindow()
                default:
                    return completing.processKey(event: event)
                    
                }
                return false
            }
        }
        
        switch event.key {
        case .controlSpace:
            complete(triggerChar: nil)
            return true
        default:
            break
        }
        let handled = super.processKey(event: event)
        
        switch event.key {
        case .letter("."):
            complete (triggerChar: ".")
            
        default:
            if completionAtEveryPoint {
                complete (triggerChar: nil)
            }
        }
        return handled
    }
}
