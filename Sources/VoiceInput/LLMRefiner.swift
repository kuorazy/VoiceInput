import Foundation

class LLMRefiner {
    enum RefineError: Error {
        case notConfigured
        case invalidResponse
        case networkError(String)
    }

    private let systemPrompt = """
    You are a conservative speech recognition post-processor. Your ONLY job is to fix obvious speech recognition errors in the user's text. Follow these rules STRICTLY:

    1. Only fix CLEAR speech recognition mistakes:
       - Chinese homophone errors (e.g., "配森" → "Python", "杰森" → "JSON", "咖特" → "cat")
       - English/technical terms that were wrongly transcribed as Chinese characters
       - Common mixed-language recognition errors

    2. DO NOT:
       - Rewrite, rephrase, or polish the text
       - Add words that weren't spoken
       - Remove content that seems correct
       - Change the style, tone, or structure
       - Add punctuation that wasn't implied by the speech

    3. If the text looks correct as-is, return it EXACTLY as provided. Do not make any changes.

    4. Preserve the original language mix — if the user mixed Chinese and English, keep that mix.

    Return ONLY the corrected text, with no explanation, no quotes, no prefix.
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
