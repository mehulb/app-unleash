//
//  ViewController.swift
//  AppUnleash
//
//  Created by Mehul Bhavani on 18/01/21.
//

import Cocoa
import XcodeProj

class ViewController: NSViewController, NSTextFieldDelegate {
    
    @IBOutlet private var xcodeProjectPathTextField : NSTextField?
    
    @IBOutlet private var versionTextField          : NSTextField?
    @IBOutlet private var buildTextField            : NSTextField?
    
    @IBOutlet private var outputTextView            : NSTextView?
    
    @IBOutlet private var configSegmentedControl    : NSSegmentedControl?
    
    @IBOutlet private var activityIndicator         : NSProgressIndicator?
    
    @IBOutlet private var percentageLabel           : NSTextField?
    @IBOutlet private var currentTaskLabel          : NSTextField?
    @IBOutlet private var progressView              : NSProgressIndicator?
    
    private var xcodePath = ""
    private var infoPlistPath = ""
    private var buildPath = ""
    private var projectName = ""
    
    private var versionString = ""
    private var buildString = ""
    private var configString = "Release"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        (self.view as! DDView).validExtensions = ["xcodeproj"]
        (self.view as! DDView).didDropFile { (filePath) in
            print("\(filePath)")
            self.xcodeProjectPathTextField?.stringValue = filePath
            self.populateVersionAndBuild()
        }
        
        xcodeProjectPathTextField?.delegate = self
        outputTextView?.font = NSFont(name: "Andale Mono", size: 14)
    }
    
    @IBAction func xcodeButton_Clicked(_ button: NSButton) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.allowedFileTypes = ["xcodeproj"]
        panel.beginSheetModal(for: self.view.window!) { (response) in
            if response == .OK {
                self.xcodeProjectPathTextField?.stringValue = panel.url!.path
            }
        }
    }
    @IBAction func startButton_Clicked(_ button: NSButton) {
        versionString = versionTextField?.stringValue ?? ""
        buildString = buildTextField?.stringValue ?? ""
        configString = configSegmentedControl?.selectedSegment == 0 ? "Debug" : "Release"
        
        xcodePath = xcodeProjectPathTextField?.stringValue ?? ""
        projectName = xcodePath.deletingPathExtension.lastPathComponent
        infoPlistPath = xcodePath.deletingLastPathComponent+"/"+projectName+"/"+"Info.plist"
        buildPath = xcodePath.deletingLastPathComponent+"/Builds/\(versionString)-\(buildString)/\(configString)"
        
        outputTextView?.string = ""
        
        if !IsVersionValid(versionString) {
            output("Invalid Version!", 3)
            output("Example version: 1.4.0", 2)
            return
        }
        if !IsBuildValid(buildString) {
            output("Invalid Build Number!", 3)
            output("Use reverse date format : yymmdd", 2)
            return
        }
        
        output("--- BEGIN ---\n", 1)
        
        button.title = "running..."
        button.isEnabled = false
        activityIndicator?.startAnimation(nil)
        
        DispatchQueue.global(qos: .background).async {
            //            _ = self.buildXcodeProject()
            if self.changeXcodeProjectVersion() {
                if self.buildXcodeProject() {
                    // :)
                    self.complete()
                }
            }
            DispatchQueue.main.async {
                self.activityIndicator?.stopAnimation(nil)
                button.title = "Start"
                button.isEnabled = true
            }
            self.output("\n--- THE END ---", 1)
        }
    }
    
    //MARK:- NSTextFieldDelegate
    func controlTextDidEndEditing(_ obj: Notification) {
        //print("framework end editing")
        populateVersionAndBuild()
    }
}

//MARK:- STEPS
extension ViewController {
    private func changeXcodeProjectVersion() -> Bool {
        output("Update \(projectName) version ...", 1)
        updateProgress(progress: 80, message: "Updating \(projectName) Version...")
        
        if !xcodePath.isEmpty {
            if FileManager.default.fileExists(atPath: infoPlistPath) {
                guard let plistContent = NSMutableDictionary(contentsOfFile: infoPlistPath) else {
                    output("failed to read \(projectName) info.plist", 3)
                    return false
                }
                print("\(projectName) version-build loaded")
                DispatchQueue.main.async {
                    plistContent["CFBundleShortVersionString"] = self.versionTextField?.stringValue
                    plistContent["CFBundleVersion"] = self.buildTextField?.stringValue
                }
                
                if plistContent.write(toFile: infoPlistPath, atomically: true) {
                    output("\(projectName) version/build updated", 2)
                }
                else {
                    output("Failed to update \(projectName) version/build", 3)
                    return false
                }
            }
        }
        
        output("... \(projectName) version updated\n", 1)
        return true
    }
    private func buildXcodeProject() -> Bool {
        output("Start building \(projectName) ...", 1)
        updateProgress(progress: 10, message: "Buiding \(projectName)...")
        
        let args = [
            "-project",
            xcodePath,
            "-scheme",
            "\(projectName)",
            "-configuration",
            "\(configString)",
            "SYMROOT=\(buildPath.deletingLastPathComponent)",
            "-quiet"
        ]
        output(runCommand(launchPath: "/usr/bin/xcodebuild", arguments: args), 2)
        
        output("... \(projectName) build complete", 1)
        return true
    }
    private func complete() {
        updateProgress(progress: 100, message: "Complete!")
    }
}

//MARK:- Helper Methods
extension ViewController {
    private func runCommand(launchPath: String, arguments: [String]) -> String {
        let task = Process()
        let pipe = Pipe()
        
        task.launchPath = launchPath
        task.arguments = arguments
        task.standardOutput = pipe
        task.standardError = pipe
        task.launch()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        
        return String(data: data, encoding: .utf8) ?? "NO OUTPUT"
    }
    private func copyFile(from sourcePath: String, to destinationPath: String) -> Bool {
        if !FileManager.default.fileExists(atPath: sourcePath) {
            output("No file found at source:\n\(sourcePath)", 3)
            return false
        }
        if FileManager.default.fileExists(atPath: destinationPath) {
            do {
                try FileManager.default.removeItem(atPath: destinationPath)
            }
            catch {
                output("Failed to delete old file!\n\(error)", 3)
                return false
            }
        }
        do {
            try FileManager.default.copyItem(atPath: sourcePath, toPath: destinationPath)
        }
        catch {
            output("Failed to move file!\n\(error)", 3)
            return false
        }
        
        return true
    }
    private func output(_ string: String,_ type: Int) {
        var attributes: [NSAttributedString.Key: Any]
        switch type {
            case 1:
                attributes = [.font: NSFont(name: "Courier", size: 14)!, .foregroundColor: NSColor.labelColor]
            case 2:
                attributes = [.font: NSFont(name: "Courier New", size: 14)!, .foregroundColor: NSColor.tertiaryLabelColor]
            case 3:
                attributes = [.font: NSFont(name: "Courier", size: 14)!, .foregroundColor: NSColor.red]
            default:
                attributes = [.font: NSFont(name: "Courier", size: 14)!, .foregroundColor: NSColor.labelColor]
        }
        
        let attrString = NSAttributedString(string: string+"\n", attributes: attributes)
        
        DispatchQueue.main.async {
            self.outputTextView?.textStorage?.append(attrString)
            self.outputTextView?.scrollToEndOfDocument(nil)
        }
    }
    private func IsVersionValid(_ string: String) -> Bool {
        if string.isEmpty {
            return false
        }
        let vComp = string.components(separatedBy: ".")
        if vComp.count != 3 {
            return false
        }
        if Int(vComp[0]) == nil || Int(vComp[1]) == nil || Int(vComp[2]) == nil {
            return false
        }
        
        return true
    }
    private func IsBuildValid(_ string: String) -> Bool {
        if string.isEmpty {
            return false
        }
        if string.count != 6 {
            return false
        }
        if Int(string) == nil {
            return false
        }
        
        return true
    }
    private func populateVersionAndBuild() {
        if let path = xcodeProjectPathTextField?.stringValue, !path.isEmpty {
            if FileManager.default.fileExists(atPath: infoPlistPath) {
                guard let plistContent = NSMutableDictionary(contentsOfFile: infoPlistPath) else {
                    return
                }
                print("\(projectName) version-build loaded")
                versionTextField?.stringValue = plistContent["CFBundleShortVersionString"] as! String
                buildTextField?.stringValue = plistContent["CFBundleVersion"] as! String
            }
        }
    }
    private func updateProgress(progress: Int, message: String) {
        DispatchQueue.main.async {
            self.currentTaskLabel?.stringValue = message
            self.percentageLabel?.stringValue = "\(progress)%"
            self.progressView?.doubleValue = Double(progress)
        }
    }
}

extension String {
    var str: NSString {
        return self as NSString
    }
    
    var pathExtension: String {
        return str.pathExtension
    }
    
    var lastPathComponent: String {
        return str.lastPathComponent
    }
    
    var deletingLastPathComponent: String {
        return str.deletingLastPathComponent
    }
    
    var deletingPathExtension: String {
        return str.deletingPathExtension
    }
}


