//
//  PythonBridge.swift
//  whitemax
//
//  Python Bridge для инициализации Python интерпретатора
//  Согласно документации Python для iOS: https://docs.python.org/3/using/ios.html
//

import Foundation
import PythonKit

class PythonBridge {
    static let shared = PythonBridge()
    
    private var isInitialized = false
    
    private init() {}
    
    func initialize() throws {
        guard !isInitialized else { return }
        
        // Получаем путь к app bundle
        guard let bundlePath = Bundle.main.resourcePath else {
            throw PythonBridgeError.bundlePathNotFound
        }
        
        let appPath = "\(bundlePath)/app"
        let pythonPath = "\(bundlePath)/app/python"
        let pythonLibPath = "\(pythonPath)/lib/python3.12"
        let pythonLibDynload = "\(pythonLibPath)/lib-dynload"
        
        // Настройка PYTHONHOME согласно документации iOS
        let pythonHome = pythonPath
        setenv("PYTHONHOME", pythonHome, 1)
        
        // Настройка PYTHONPATH согласно документации iOS
        // Должен включать: python/lib/python3.X, python/lib/python3.X/lib-dynload, app
        var pythonPathEnv = pythonLibPath
        pythonPathEnv += ":\(pythonLibDynload)"
        pythonPathEnv += ":\(appPath)"
        
        setenv("PYTHONPATH", pythonPathEnv, 1)
        
        print("Python configuration:")
        print("PYTHONHOME: \(pythonHome)")
        print("PYTHONPATH: \(pythonPathEnv)")
        
        // PythonKit автоматически использует встроенный Python из xcframework
        // Проверяем что Python работает и может импортировать базовые модули
        do {
            // Проверяем, что sys модуль доступен
            let sys = try Python.attemptImport("sys")
            print("Python version: \(sys.version)")
            print("Python executable: \(sys.executable)")
            print("Python path: \(sys.path)")
            
            // Проверяем, что encodings доступен (критически важно для iOS)
            let _ = try Python.attemptImport("encodings")
            print("✓ encodings module loaded successfully")
            
            // Добавляем app путь в sys.path если его там нет
            let sysPath: PythonObject = sys.path
            let appPathObj = PythonObject(appPath)
            if !sysPath.contains(appPathObj) {
                sys.path.insert(0, appPathObj)
            }
            
            // Проверяем наличие файлов в app директории
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: appPath) {
                print("✓ app directory exists: \(appPath)")
                
                // Проверяем наличие max_client_wrapper.py
                let wrapperPath = "\(appPath)/max_client_wrapper.py"
                if fileManager.fileExists(atPath: wrapperPath) {
                    print("✓ max_client_wrapper.py exists")
                } else {
                    print("✗ max_client_wrapper.py NOT found at: \(wrapperPath)")
                }
                
                // Проверяем наличие pymax
                let pymaxPath = "\(appPath)/pymax"
                if fileManager.fileExists(atPath: pymaxPath) {
                    print("✓ pymax directory exists")
                } else {
                    print("✗ pymax directory NOT found at: \(pymaxPath)")
                }
            } else {
                print("✗ app directory NOT found: \(appPath)")
            }
            
            isInitialized = true
        } catch {
            print("Python initialization error: \(error)")
            // Выводим дополнительную диагностику
            if let sysPath = Bundle.main.path(forResource: "app/python/lib/python3.12", ofType: nil) {
                print("Python library path exists: \(sysPath)")
                let fm = FileManager.default
                let encodingsPath = "\(sysPath)/encodings"
                if fm.fileExists(atPath: encodingsPath) {
                    print("✓ encodings directory exists")
                } else {
                    print("✗ encodings directory NOT found at: \(encodingsPath)")
                }
            }
            throw PythonBridgeError.initializationFailed(error.localizedDescription)
        }
    }
    
    func importModule(_ name: String) throws -> PythonObject {
        guard isInitialized else {
            throw PythonBridgeError.notInitialized
        }
        
        do {
            // Сначала пытаемся импортировать sys для отладки
            let sys = try Python.attemptImport("sys")
            print("Attempting to import module: \(name)")
            print("Current sys.path: \(sys.path)")
            
            // Пытаемся импортировать модуль
            let module = try Python.attemptImport(name)
            print("✓ Successfully imported module: \(name)")
            return module
        } catch {
            // Дополнительная диагностика при ошибке
            print("✗ Failed to import module '\(name)': \(error)")
            
            // Пытаемся получить больше информации из Python
            do {
                let sys = try Python.attemptImport("sys")
                let traceback = try Python.attemptImport("traceback")
                let importlib = try Python.attemptImport("importlib.util")
                print("Checking if module file exists...")
                
                // Проверяем, существует ли файл
                if let bundlePath = Bundle.main.resourcePath {
                    let modulePath = "\(bundlePath)/app/\(name).py"
                    let fileManager = FileManager.default
                    if fileManager.fileExists(atPath: modulePath) {
                        print("✓ Module file exists: \(modulePath)")
                    } else {
                        print("✗ Module file NOT found: \(modulePath)")
                    }
                }
            } catch {
                print("Could not get additional diagnostics: \(error)")
            }
            
            throw PythonBridgeError.importFailed(name, error.localizedDescription)
        }
    }
}

enum PythonBridgeError: LocalizedError {
    case bundlePathNotFound
    case notInitialized
    case initializationFailed(String)
    case importFailed(String, String)
    
    var errorDescription: String? {
        switch self {
        case .bundlePathNotFound:
            return "Bundle path not found"
        case .notInitialized:
            return "Python bridge not initialized"
        case .initializationFailed(let message):
            return "Python initialization failed: \(message)"
        case .importFailed(let module, let message):
            return "Failed to import module '\(module)': \(message)"
        }
    }
}
