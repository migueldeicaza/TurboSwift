//
//  Project.swift
//  TurboSwift
//
//  Created by Miguel de Icaza on 5/13/21.
//
// TODO make this a factory method, so we create Project that have a guaranteed server working

import Foundation
import TermKit
import SwiftLSPClient
import os

var logger: Logger = Logger(subsystem: "TurboSwift", category: "log")

public func log (_ s: String)
{
    logger.log("\(s, privacy: .public)")
}

class Project: NotificationResponder {
    func languageServer(_ server: LanguageServer, logMessage message: LogMessageParams) {
        log ("logMessage" + message.description)
    }
    
    func languageServer(_ server: LanguageServer, showMessage message: ShowMessageParams) {
        log ("showMessage" + message.description)
    }
    
    func languageServer(_ server: LanguageServer, showMessageRequest messageRequest: ShowMessageRequestParams) {
        log ("showMessageRequest" + messageRequest.description)
    }
    
    func languageServer(_ server: LanguageServer, publishDiagnostics diagnosticsParams: PublishDiagnosticsParams) {
        log ("publishDiagnostics")
    }
    
    func languageServer(_ server: LanguageServer, failedToDecodeNotification notificationName: String, with error: Error) {
        log ("failedToDecodeNotification" + notificationName.description)
    }
    
    var host: LanguageServerProcessHost
    var server: LanguageServer
    
    public func load (file: String) {
        if let pars = try? DidOpenTextDocumentParams (textDocument: TextDocumentItem (contentsOfFile: file)) {
            server.didOpenTextDocument(params: pars) { err in
                log (err?.errorDescription ?? "Load OK")
            }
        }
    }
    
    init (host: LanguageServerProcessHost, server: LanguageServer)
    {
        self.host = host
        self.server = server
    }
    
    public static func open (directory: String, complete: @escaping (LanguageServerResult<Project>)->()) {
        let host = LanguageServerProcessHost(
            path: "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/sourcekit-lsp",
            arguments: [],
            environment: [:])
    
        host.start { (server) in
            guard let server = server else {
                Swift.print("unable to launch server")
                return
            }
            // Set-up notificationResponder to see log/error messages from LSP server
            // TODO: server.notificationResponder = self
            
            let processId = Int(ProcessInfo.processInfo.processIdentifier)
            
            let capabilities = ClientCapabilities(workspace: nil, textDocument: nil, experimental: nil)
            
            let workspace = WorkspaceFolder (uri: directory, name: "textbufferkit")
            let params = InitializeParams(processId: processId,
                                          rootPath: directory,
                                          rootURI: nil,
                                          initializationOptions: nil,
                                          capabilities: capabilities,
                                          trace: Tracing.verbose,
                                          workspaceFolders: [workspace])
            
            server.initialize(params: params, block: { (result) in
                switch result {
                case .failure(let error):
                    complete (.failure (error))
                case .success(let value):
                    let p = Project (host: host, server: server)
                    server.notificationResponder = p
                    complete (.success(p))
                }
            })
        }
    }
}
