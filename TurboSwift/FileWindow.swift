//
//  FileWindow.swift
//  TurboSwift
//
//  Created by Miguel de Icaza on 5/13/21.
//

import Foundation
import TermKit
import SwiftLSPClient


// Convenient place to track the open files - we have a 1:1 mapping, an open window is an open file
class FileWindow: Window {
    var project: Project
    var server: LanguageServer
    static var untitledCount = 0
    var filename: String?
    var textView: SwiftSourceEditor
    
    init (project: Project, filename: String?, contents: String = "")
    {
        self.filename = filename
        self.project = project
        self.server = project.server
        let file = filename ?? FileWindow.getUntitled()
        textView = SwiftSourceEditor (project: project, file: file)
        textView.text = contents
        super.init(filename ?? FileWindow.getUntitled(), padding: 0)
        
        allowMove = true
        allowClose = true
        allowResize = true
        
        textView.fill ()
        
        addSubview(textView)
        _ = textView.becomeFirstResponder()
        
        if let file = filename {
            project.load (file: file)
        }
    }
    
    static func getUntitled () -> String {
        if FileWindow.untitledCount == 0 { return "Untitled" }
        FileWindow.untitledCount += 1
        return "Untitled-\(FileWindow.untitledCount)"
    }
    
    open override var debugDescription: String {
        get {
            return "FileWindow (\(filename ?? "Untitled"))"
        }
    }
    
    // expects filename to be set
    func saveFile (_ target: String) {
        do {
            try textView.text?.write(toFile: target, atomically: true, encoding: .utf8)
            isDirty = false
        } catch {
            MessageBox.error("Error", message: "Could not save the file to \(target)", buttons: ["Ok"]) { _ in }
        }
    }

    func saveAs (_ initial: String?) {
        let s = SaveDialog (title: "Save", message: "Choose file to save")
        s.filePath = initial ?? ""
        
        s.present {_ in
            guard let target = s.fileName else {
                return
            }
            self.filename = target
            self.saveFile (target)
        }
    }
    
    func save() {
        if filename == nil {
            saveAs (nil)
        } else {
            saveFile (filename!)
        }
    }
    
    var isDirty: Bool {
        get { textView.isDirty }
        set { textView.isDirty = newValue }
    }
}
