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
    @Published var pymaxAvailable = false
    
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
    
    func createWrapper(phone: String, workDir: String? = nil, token: String? = nil) async throws {
        // Выполняем вызов Python функции в serial queue для thread-safety
        // Выполняем вызов Python функции в главном потоке
        // PythonKit требует, чтобы все Python операции выполнялись в потоке, где Python был инициализирован
        guard let module = wrapperModule else {
            throw MaxClientError.notInitialized
        }
        
        let workDirValue = workDir  // Сохраняем Swift значения
        let tokenValue = token
        let jsonString = try await MainActor.run {
            // Создаем Python объекты в главном потоке
            let workDirPython = workDirValue != nil ? PythonObject(workDirValue!) : PythonObject(Python.None)
            let tokenPython = tokenValue != nil ? PythonObject(tokenValue!) : PythonObject(Python.None)
            let result = module.create_wrapper(phone, workDirPython, tokenPython)
            return String(result) ?? "{}"
        }
        
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
        // Выполняем вызов Python функции в главном потоке
        // PythonKit требует, чтобы все Python операции выполнялись в потоке, где Python был инициализирован
        let phoneValue = phone  // Сохраняем Swift значение
        let jsonString = try await MainActor.run {
            // Убеждаемся, что модуль доступен
            guard let module = self.wrapperModule else {
                return "{\"success\": false, \"error\": \"Module not initialized\"}"
            }
            
            // Создаем Python объекты в главном потоке
            let phonePython = phoneValue != nil ? PythonObject(phoneValue!) : PythonObject(Python.None)
            let result = module.request_code(phonePython, language)
            return String(result) ?? "{}"
        }
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
        
        // Выполняем вызов Python функции в главном потоке
        // PythonKit требует, чтобы все Python операции выполнялись в потоке, где Python был инициализирован
        let jsonString = try await MainActor.run {
            guard let module = self.wrapperModule else {
                return "{\"success\": false, \"error\": \"Module not initialized\"}"
            }
            let result = module.login_with_code(tempToken, code)
            return String(result) ?? "{}"
        }
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let success = json["success"] as? Bool else {
            throw MaxClientError.invalidResponse
        }
        
        if !success {
            let error = json["error"] as? String ?? "Unknown error"
            throw MaxClientError.loginFailed(error)
        }
        
        // Сохраняем токен и номер телефона
        if let token = json["token"] as? String {
            UserDefaults.standard.set(token, forKey: "max_auth_token")
            // Сохраняем номер телефона для восстановления сессии
            if let phone = json["phone"] as? String {
                UserDefaults.standard.set(phone, forKey: "max_phone_number")
            }
            isAuthenticated = true
        }
        
        // Парсим информацию о пользователе
        // me может быть nil, если пользователь еще не загружен, это нормально
        if let me = json["me"] as? [String: Any],
           let id = me["id"] as? Int {
            // first_name может быть пустой строкой, это нормально
            let firstName = me["first_name"] as? String ?? "User"
            let user = MaxUser(id: id, firstName: firstName)
            currentUser = user
            return user
        }
        
        // Если me отсутствует, но токен сохранен, это не критическая ошибка
        // Просто не устанавливаем currentUser
        return MaxUser(id: 0, firstName: "Unknown")
    }
    
    func getChats() async throws -> [MaxChat] {
        guard let module = wrapperModule else {
            throw MaxClientError.notInitialized
        }
        
        // Выполняем вызов Python функции в главном потоке
        // PythonKit требует, чтобы все Python операции выполнялись в потоке, где Python был инициализирован
        let jsonString = try await MainActor.run {
            guard let module = self.wrapperModule else {
                return "{\"success\": false, \"error\": \"Module not initialized\"}"
            }
            let result = module.get_chats()
            return String(result) ?? "{}"
        }
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
            let photoId = chatDict["photo_id"] as? Int  // Для диалогов
            let iconUrl = chatDict["icon_url"] as? String  // Для чатов и каналов
            let unreadCount = chatDict["unread_count"] as? Int ?? 0
            
            return MaxChat(
                id: id,
                title: title,
                type: type,
                photoId: photoId,
                iconUrl: iconUrl,
                unreadCount: unreadCount
            )
        }
    }
    
    func getMessages(chatId: Int, limit: Int = 50) async throws -> [MaxMessage] {
        guard let module = wrapperModule else {
            throw MaxClientError.notInitialized
        }
        
        // Выполняем вызов Python функции в главном потоке
        // PythonKit требует, чтобы все Python операции выполнялись в потоке, где Python был инициализирован
        let jsonString = try await MainActor.run {
            guard let module = self.wrapperModule else {
                return "{\"success\": false, \"error\": \"Module not initialized\"}"
            }
            let result = module.get_messages(chatId, limit)
            return String(result) ?? "{}"
        }
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
            print("⚠️ No messages array in response: \(json)")
            return []
        }
        
        print("✓ Parsing \(messagesArray.count) messages from response for chatId=\(chatId)")
        
        let parsedMessages = messagesArray.compactMap { messageDict -> MaxMessage? in
            // id может быть String или Int, конвертируем в String
            var messageId: String?
            if let idString = messageDict["id"] as? String {
                messageId = idString
            } else if let idInt = messageDict["id"] as? Int {
                messageId = String(idInt)
            } else if let idNumber = messageDict["id"] as? NSNumber {
                messageId = idNumber.stringValue
            }
            
            guard let id = messageId else {
                print("⚠️ Invalid message dict: missing id - \(messageDict)")
                return nil
            }
            
            // chat_id может быть nil в JSON, в этом случае используем chatId из параметра функции
            var messageChatId: Int = chatId
            if let chatIdFromJson = messageDict["chat_id"] as? Int {
                messageChatId = chatIdFromJson
            } else if messageDict["chat_id"] is NSNull || messageDict["chat_id"] == nil {
                // chat_id равен null или отсутствует, используем переданный chatId
                messageChatId = chatId
            }
            
            let text = messageDict["text"] as? String ?? ""
            let senderId = messageDict["sender_id"] as? Int
            // Используем time, если есть, иначе date
            let date = (messageDict["time"] as? Int) ?? (messageDict["date"] as? Int)
            let type = messageDict["type"] as? String
            
            let message = MaxMessage(
                id: id,
                chatId: messageChatId,
                text: text,
                senderId: senderId,
                date: date,
                type: type
            )
            
            print("  ✓ Parsed message: id=\(id), chatId=\(messageChatId), text=\(String(text.prefix(30)))")
            return message
        }
        
        print("✓ Successfully parsed \(parsedMessages.count) messages")
        return parsedMessages
    }
    
    func startClient() async throws {
        guard let module = wrapperModule else {
            throw MaxClientError.notInitialized
        }
        
        // Получаем сохраненный токен и номер телефона
        let savedToken = UserDefaults.standard.string(forKey: "max_auth_token")
        let savedPhone = UserDefaults.standard.string(forKey: "max_phone_number")
        
        // Если есть токен, но wrapper еще не создан, создаем его с токеном
        if let token = savedToken, let phone = savedPhone {
            // Создаем wrapper с токеном для восстановления сессии
            try await createWrapper(phone: phone, token: token)
        }
        
        // Выполняем вызов Python функции в главном потоке
        // PythonKit требует, чтобы все Python операции выполнялись в потоке, где Python был инициализирован
        let jsonString = try await MainActor.run {
            guard let module = self.wrapperModule else {
                return "{\"success\": false, \"error\": \"Module not initialized\"}"
            }
            let result = module.start_client()
            return String(result) ?? "{}"
        }
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let success = json["success"] as? Bool else {
            throw MaxClientError.invalidResponse
        }
        
        if !success {
            let error = json["error"] as? String ?? "Unknown error"
            throw MaxClientError.startClientFailed(error)
        }
        
        // Обновляем состояние авторизации
        if let authenticated = json["authenticated"] as? Bool {
            isAuthenticated = authenticated
        } else if json["requires_auth"] as? Bool == true {
            isAuthenticated = false
        } else if savedToken != nil {
            isAuthenticated = true
        }
        
        // Обновляем информацию о пользователе если есть
        if let me = json["me"] as? [String: Any],
           let id = me["id"] as? Int,
           let firstName = me["first_name"] as? String {
            currentUser = MaxUser(id: id, firstName: firstName)
        }
    }
    
    func stopClient() async throws {
        guard let module = wrapperModule else {
            throw MaxClientError.notInitialized
        }
        
        // Выполняем вызов Python функции в главном потоке
        // PythonKit требует, чтобы все Python операции выполнялись в потоке, где Python был инициализирован
        let jsonString = try await MainActor.run {
            guard let module = self.wrapperModule else {
                return "{\"success\": false, \"error\": \"Module not initialized\"}"
            }
            let result = module.stop_client()
            return String(result) ?? "{}"
        }
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw MaxClientError.invalidResponse
        }
        
        // Очищаем состояние и токен
        isAuthenticated = false
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: "max_auth_token")
        UserDefaults.standard.removeObject(forKey: "max_phone_number")
    }
    
    func logout() async throws {
        // Выход из системы - очищаем токен и останавливаем клиент
        try await stopClient()
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
