import Foundation

class LLMRefiner {
    enum RefineError: Error {
        case notConfigured
        case invalidResponse
        case networkError(String)
    }

    private let systemPrompt = """
    你是一个保守的语音识别后处理器。你唯一的工作是修正用户文本中明显的语音识别错误。严格遵循以下规则：

    1. 只修正明确的语音识别错误：
       - 中文同音字错误（如"配森" → "Python"、"杰森" → "JSON"、"咖特" → "cat"）
       - 英文/技术术语被错误识别为中文字符
       - 常见的中英混合识别错误

    2. 禁止：
       - 改写、润色或修饰文本
       - 添加用户没有说过的内容
       - 删除看起来正确的内容
       - 改变风格、语气或结构
       - 添加语音中未暗示的标点

    3. 如果文本本身没有问题，原样返回，不要做任何修改。

    4. 保持原始的语言混合——如果用户中英混用，保持混用不变。

    只返回修正后的文本，不要解释、不要加引号、不要加前缀。
    """

    func refine(_ text: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let baseURL = UserDefaults.standard.string(forKey: "LLMApiBaseURL"), !baseURL.isEmpty,
              let apiKey = UserDefaults.standard.string(forKey: "LLMApiKey"), !apiKey.isEmpty
        else {
            completion(.failure(RefineError.notConfigured))
            return
        }

        let model = UserDefaults.standard.string(forKey: "LLMModel") ?? "gpt-4o-mini"

        // Construct URL
        var urlStr = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !urlStr.hasSuffix("/") { urlStr += "/" }
        urlStr += "chat/completions"

        guard let url = URL(string: urlStr) else {
            completion(.failure(RefineError.networkError("Invalid API URL")))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.0,
            "max_tokens": max(text.count * 2, 256)
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(RefineError.networkError(error.localizedDescription)))
                return
            }

            guard let data = data else {
                completion(.failure(RefineError.invalidResponse))
                return
            }

            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let firstChoice = choices.first,
                      let message = firstChoice["message"] as? [String: Any],
                      let content = message["content"] as? String
                else {
                    completion(.failure(RefineError.invalidResponse))
                    return
                }
                completion(.success(content.trimmingCharacters(in: .whitespacesAndNewlines)))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func testConnection(completion: @escaping (Result<String, Error>) -> Void) {
        refine("Hello world 你好世界", completion: completion)
    }
}
