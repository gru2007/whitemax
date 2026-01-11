//
//  EventMonitor.swift
//  whitemax
//
//  Monitors a directory for JSON event files emitted by Python wrapper.
//

import Foundation

final class EventMonitor {
    typealias EventHandler = ([String: Any]) -> Void

    private let directoryURL: URL
    private let queue: DispatchQueue
    private var source: DispatchSourceFileSystemObject?
    private var dirFD: Int32 = -1

    var onEvent: EventHandler?

    init(directoryPath: String, queue: DispatchQueue = DispatchQueue(label: "whitemax.events.monitor")) {
        self.directoryURL = URL(fileURLWithPath: directoryPath, isDirectory: true)
        self.queue = queue
    }

    deinit {
        stop()
    }

    func start() {
        guard source == nil else { return }

        let path = directoryURL.path
        dirFD = open(path, O_EVTONLY)
        guard dirFD >= 0 else {
            return
        }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: dirFD,
            eventMask: [.write, .rename, .delete],
            queue: queue
        )

        src.setEventHandler { [weak self] in
            self?.drainEvents()
        }

        src.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.dirFD >= 0 {
                close(self.dirFD)
                self.dirFD = -1
            }
            self.source = nil
        }

        source = src
        src.resume()

        // Drain anything already present
        drainEvents()
    }

    func stop() {
        source?.cancel()
        source = nil
        if dirFD >= 0 {
            close(dirFD)
            dirFD = -1
        }
    }

    private func drainEvents() {
        let fm = FileManager.default

        guard let files = try? fm.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for fileURL in files where fileURL.pathExtension.lowercased() == "json" {
            guard let data = try? Data(contentsOf: fileURL) else { continue }
            guard
                let obj = try? JSONSerialization.jsonObject(with: data),
                let dict = obj as? [String: Any]
            else {
                // If it's malformed, delete to avoid infinite loops
                try? fm.removeItem(at: fileURL)
                continue
            }

            // Delete first to reduce chance of double-processing on repeated events
            try? fm.removeItem(at: fileURL)
            onEvent?(dict)
        }
    }
}

