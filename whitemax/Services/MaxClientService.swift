//
//  MaxClientService.swift
//  whitemax
//
//  Swift сервис для работы с Max.RU через Python
//

import Foundation
import Combine
import PythonKit

@MainActor
class MaxClientService: ObservableObject {
    static let shared = MaxClientService()
    
    @Published var isInitialized = false
    @Published var isAuthenticated = false
    @Published var currentUser: MaxUser?
    
    private var wrapperModule: PythonObject?
    
    private init() {
        initializePython()
    }
    
    private func initializePython() {
        do {
            try PythonBridge.shared.initialize()
            
            // Проверяем наличие файла перед импортом
            guard let bundlePath = Bundle.main.resourcePath else {
                print("Failed to get bundle path")
                return
            }
            
            let wrapperPath = "\(bundlePath)/app/max_client_wrapper.py"
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: wrapperPath) {
                print("Error: max_client_wrapper.py not found at: \(wrapperPath)")
                return
            }
            
            // Пытаемся импортировать модуль с обработкой ошибок
            do {
                wrapperModule = try PythonBridge.shared.importModule("max_client_wrapper")
                isInitialized = true
                print("✓ max_client_wrapper module loaded successfully")
            } catch {
                print("Error importing max_client_wrapper: \(error)")
                // Продолжаем без модуля - может быть pymax не установлен
                print("Note: max_client_wrapper will not work until pymax is available")
                isInitialized = false
            }
        } catch {
            print("Failed to initialize Python: \(error)")
            if let error = error as? PythonBridgeError {
                print("Error details: \(error.localizedDescription)")
            }
        }
    }
    
    func createWrapper(phone: String, workDir: String? = nil) async throws {
        guard let module = wrapperModule else {
            throw MaxClientError.notInitialized
        }
        
        // Проверка доступности pymax будет выполнена в create_wrapper
        
        let workDirPython = workDir != nil ? PythonObject(workDir!) : PythonObject(Python.None)
        let result = module.create_wrapper(phone, workDirPython)
        
        let jsonString = String(result) ?? "{}"
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let success = json["success"] as? Bool else {
            throw MaxClientError.invalidResponse
        }
        
        if !success {
            let error = json["error"] as? String ?? "Unknown error"
            if error.contains("pymax not available") {
                throw MaxClientError.pymaxNotAvailable
            }
            throw MaxClientError.wrapperCreationFailed(error)
        }
    }
    
    func requestCode(phone: String? = nil, language: String = "ru") async throws -> String {
        guard let module = wrapperModule else {
            throw MaxClientError.notInitialized
        }
        
        let phonePython = phone != nil ? PythonObject(phone!) : PythonObject(Python.None)
        let result = module.request_code(phonePython, language)
        
        let jsonString = String(result) ?? "{}"
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let success = json["success"] as? Bool else {
            throw MaxClientError.invalidResponse
        }
        
        if !success {
            let error = json["error"] as? String ?? "Unknown error"
            throw MaxClientError.requestCodeFailed(error)
        }
        
        guard let tempToken = json["temp_token"] as? String else {
            throw MaxClientError.missingToken
        }
        
        return tempToken
    }
    
    func loginWithCode(tempToken: String, code: String) async throws -> MaxUser {
        guard let module = wrapperModule else {
            throw MaxClientError.notInitialized
        }
        
        let result = module.login_with_code(tempToken, code)
        
        let jsonString = String(result) ?? "{}"
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let success = json["success"] as? Bool else {
            throw MaxClientError.invalidResponse
        }
        
        if !success {
            let error = json["error"] as? String ?? "Unknown error"
            throw MaxClientError.loginFailed(error)
        }
        
        // Сохраняем токен
        if let token = json["token"] as? String {
            UserDefaults.standard.set(token, forKey: "max_auth_token")
            isAuthenticated = true
        }
        
        // Парсим информацию о пользователе
        if let me = json["me"] as? [String: Any],
           let id = me["id"] as? Int,
           let firstName = me["first_name"] as? String {
            let user = MaxUser(id: id, firstName: firstName)
            currentUser = user
            return user
        }
        
        throw MaxClientError.invalidUserData
    }
    
    func getChats() async throws -> [MaxChat] {
        guard let module = wrapperModule else {
            throw MaxClientError.notInitialized
        }
        
        let result = module.get_chats()
        
        let jsonString = String(result) ?? "{}"
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let success = json["success"] as? Bool else {
            throw MaxClientError.invalidResponse
        }
        
        if !success {
            let error = json["error"] as? String ?? "Unknown error"
            throw MaxClientError.getChatsFailed(error)
        }
        
        guard let chatsArray = json["chats"] as? [[String: Any]] else {
            return []
        }
        
        return chatsArray.compactMap { chatDict in
            guard let id = chatDict["id"] as? Int,
                  let title = chatDict["title"] as? String else {
                return nil
            }
            
            let type = chatDict["type"] as? String ?? "unknown"
            let photoId = chatDict["photo_id"] as? Int
            let unreadCount = chatDict["unread_count"] as? Int ?? 0
            
            return MaxChat(
                id: id,
                title: title,
                type: type,
                photoId: photoId,
                unreadCount: unreadCount
            )
        }
    }
    
    func getMessages(chatId: Int, limit: Int = 50) async throws -> [MaxMessage] {
        guard let module = wrapperModule else {
            throw MaxClientError.notInitialized
        }
        
        let result = module.get_messages(chatId, limit)
        
        let jsonString = String(result) ?? "{}"
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let success = json["success"] as? Bool else {
            throw MaxClientError.invalidResponse
        }
        
        if !success {
            let error = json["error"] as? String ?? "Unknown error"
            throw MaxClientError.getMessagesFailed(error)
        }
        
        guard let messagesArray = json["messages"] as? [[String: Any]] else {
            return []
        }
        
        return messagesArray.compactMap { messageDict in
            guard let id = messageDict["id"] as? String,
                  let chatId = messageDict["chat_id"] as? Int else {
                return nil
            }
            
            let text = messageDict["text"] as? String ?? ""
            let senderId = messageDict["sender_id"] as? Int
            let date = messageDict["date"] as? Int
            let type = messageDict["type"] as? String
            
            return MaxMessage(
                id: id,
                chatId: chatId,
                text: text,
                senderId: senderId,
                date: date,
                type: type
            )
        }
    }
    
    func startClient() async throws {
        guard let module = wrapperModule else {
            throw MaxClientError.notInitialized
        }
        
        let result = module.start_client()
        
        let jsonString = String(result) ?? "{}"
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let success = json["success"] as? Bool else {
            throw MaxClientError.invalidResponse
        }
        
        if !success {
            let error = json["error"] as? String ?? "Unknown error"
            throw MaxClientError.startClientFailed(error)
        }
        
        // Проверяем наличие токена
        if UserDefaults.standard.string(forKey: "max_auth_token") != nil {
            isAuthenticated = true
        }
    }
    
    func stopClient() async throws {
        guard let module = wrapperModule else {
            throw MaxClientError.notInitialized
        }
        
        let result = module.stop_client()
        
        let jsonString = String(result) ?? "{}"
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw MaxClientError.invalidResponse
        }
        
        // Очищаем состояние
        isAuthenticated = false
        currentUser = nil
    }
    
    func checkAuthentication() -> Bool {
        return UserDefaults.standard.string(forKey: "max_auth_token") != nil
    }
}

enum MaxClientError: LocalizedError {
    case notInitialized
    case invalidResponse
    case pymaxNotAvailable
    case wrapperCreationFailed(String)
    case requestCodeFailed(String)
    case loginFailed(String)
    case getChatsFailed(String)
    case getMessagesFailed(String)
    case startClientFailed(String)
    case missingToken
    case invalidUserData
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Python bridge not initialized"
        case .invalidResponse:
            return "Invalid response from Python"
        case .pymaxNotAvailable:
            return "pymax not available - missing dependencies (pydantic-core required)"
        case .wrapperCreationFailed(let message):
            if message.contains("pymax not available") {
                return "pymax not available - missing dependencies"
            }
            return "Failed to create wrapper: \(message)"
        case .requestCodeFailed(let message):
            return "Failed to request code: \(message)"
        case .loginFailed(let message):
            return "Login failed: \(message)"
        case .getChatsFailed(let message):
            return "Failed to get chats: \(message)"
        case .getMessagesFailed(let message):
            return "Failed to get messages: \(message)"
        case .startClientFailed(let message):
            return "Failed to start client: \(message)"
        case .missingToken:
            return "Missing authentication token"
        case .invalidUserData:
            return "Invalid user data"
        }
    }
}
