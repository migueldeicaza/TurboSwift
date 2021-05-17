//
//  main.swift
//  TurboSwift
//
//  Created by Miguel de Icaza on 5/13/21.
//

import Foundation
import TermKit

// So the debugger can attach
sleep (1)
Application.prepare()

class SimpleEditor: StandardToplevel {
    var project: Project?
    
    func place (window: FileWindow) {
        window.frame = Rect (origin: Point.zero, size: desk.bounds.size)
        manage (window: window)
        window.closeClicked = handleClose
    }
    
    func handleClose (w: Window)  {
        guard let filewin = w as? FileWindow else {
            return
        }
        if filewin.isDirty {
            filewin.save()
        }
        drop (window: w)
    }
    
    func newFile () {
        guard let p = project else {
            MessageBox.info("Info", message: "No project created, use New Project first")
            return
        }
        let file = FileWindow (project: p, filename: nil)
        place (window: file)
        _ = file.becomeFirstResponder()
    }

    func tryLoad (project: Project, file: String) {
        if let contents = try? String(contentsOfFile: file) {
            let file = FileWindow (project: project, filename: file, contents: contents)
            self.place (window: file)
        } else {
            MessageBox.error("Error", message: "Could not read contents of file", buttons: ["Ok"]) { _ in }
        }
    }
    
    func openFile () {
        guard let p = project else {
            MessageBox.info("Info", message: "No project created, use New Project first")
            return
        }
        let open = OpenDialog.init(title: "Open File", message: "Select a file to open")
        open.canChooseDirectories = true
        open.canChooseFiles = true
        open.allowsMultipleSelection = false
        open.present { d in
            if let file = d.filePaths?.first {
                self.tryLoad (project: p, file: file)
            }
        }
    }
    
    func saveFile () {
        for win in windows {
            guard let fileWin = win as? FileWindow else {
                continue
            }
            if fileWin.hasFocus {
                fileWin.save ()
                return
            }
        }
        MessageBox.error("Error", message: "There is no current window selected", buttons: ["Ok"])
    }
    
    func saveAsFile () {
        for win in windows {
            guard let fileWin = win as? FileWindow else {
                continue
            }
            if fileWin.hasFocus {
                fileWin.saveAs (fileWin.filename)
                return
            }
        }
        MessageBox.error("Error", message: "There is no current window selected", buttons: ["Ok"])
    }
    
    func openSwift () {
        Project.open(directory: "/Users/miguel/cvs/TextBufferKit/Sources/TextBufferKit") { res in
            switch res {
            case .failure (let err):
                MessageBox.error("Error", message: err.errorDescription ?? "<No Information>", buttons: ["Ok"])
            case .success(let p):
                self.project = p
            }
        }
    }
    
    func run () {
        MessageBox.info("Run", message: "This should run")
    }
    
    func test () {
        MessageBox.info("Run", message: "This should test")
    }
    
    func openStdFile () {
        guard let p = project else {
            return
        }
        tryLoad (project: p, file: "/Users/miguel/cvs/TextBufferKit/Sources/TextBufferKit/PieceTreeBase.swift")
    }
    
    override init () {
        super.init ()
        
        let menu = MenuBar (
            menus: [
                MenuBarItem (title: "_File", children: [
                    MenuItem (title: "Open Std project", action: openSwift),
                    MenuItem (title: "Open Std file", action: openStdFile),
                    MenuItem (title: "_New", action: newFile),
                    MenuItem (title: "_Open", action: openFile),
                    MenuItem (title: "_Save", action: saveFile),
                    MenuItem (title: "S_ave as", action: saveAsFile),
                    nil,
                    MenuItem (title: "_Quit", action: { Application.requestStop() }),
                ]),
                MenuBarItem (title: "_Edit", children: []),
                MenuBarItem (title: "_Find", children: []),
                MenuBarItem (title: "_Product", children: [
                    MenuItem(title: "_Run", help: "F5", action: run, shortcut: Key.f5, style: .plain),
                    MenuItem(title: "_Test", action: run, style: .plain)
                ]),
                MenuBarItem (title: "_Window", children: [])])
        
        addSubview(menu)
    }
}

Application.present(top: SimpleEditor ())
dispatchMain ()
