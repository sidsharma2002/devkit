import Foundation

struct ClaudeRunner {

    private static let claudePath: String = {
        // Prefer path injected by install.sh into LaunchAgent env — works on any system
        if let envPath = ProcessInfo.processInfo.environment["DEVKIT_CLAUDE_PATH"],
           !envPath.isEmpty,
           FileManager.default.fileExists(atPath: envPath) {
            return envPath
        }
        // Fallback: common install locations for dev/manual runs
        let home = NSHomeDirectory()
        let candidates = [
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            "\(home)/.local/bin/claude",
            "\(home)/.npm-global/bin/claude",
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) { return path }
        }
        return "/usr/local/bin/claude"
    }()

    // Role + preservation rules — injected via --system-prompt (separate from user turn)
    private static let systemPrompt = """
    Communication specialist. Reformat messages. No additions, no omissions.
    Rules: keep recipient names exact; keep technical terms/service names/numbers exact; \
    use **bold** for key terms and field labels, - for bullets; output message only, no preamble.
    """

    // Per-tone instructions — injected as the user-turn prompt
    private static let toneInstructions: [String: String] = [
        "Formal": """
        Reformat in Formal tone — professional incident report style.
        - Open with a **bold** header summarising the issue (e.g. **Incident Report** | Severity: P0)
        - Follow with bullet points covering: Summary, Impact, Status, Action Required
        - Use neutral, passive voice throughout
        - Target length: 4-8 lines
        """,

        "Diplomatic": """
        Reformat in Diplomatic tone — non-alarming, constructive message.
        - Keep the same recipient as the original (individual or team — do not change who is addressed)
        - Start with a warm, calm opener appropriate for the recipient
        - Collaborative framing: soften blame without removing accountability; use "we can improve" framing where appropriate
        - Acknowledge the issue without catastrophising
        - Close with a concrete next step or forward-looking ask
        - Target length: 2-4 sentences, no bullet points
        """,

        "Direct": """
        Reformat in Direct tone — maximum engineering brevity.
        - Hard limit: 2 sentences
        - Imperative voice: state the fact, then the action needed
        - Strip all filler words, greetings, and sign-offs
        """,

        "Management": """
        Reformat in Management tone — executive summary for non-technical stakeholders.
        - Lead with business impact, not technical details
        - Use this exact structure and nothing else:
          **[Service or Feature]** — [one-line status]
          - **Impact:** [who or what is affected, derived only from the original message]
          - **Status:** [current investigation state, derived only from the original message]
          - **ETA:** TBD
        - Bold all field labels
        - Do NOT add any information, recommendations, or escalation language not present in the original message
        - Target length: 4-6 lines
        """,

        "Junior-friendly": """
        Reformat in Junior-friendly tone — plain-English explanation for a newer engineer.
        - Explain what the issue actually means in simple terms
        - Avoid jargon; if a technical term is unavoidable, add a brief parenthetical explanation
        - Keep the tone friendly and calm — not alarming
        - End with a clear, specific ask (e.g. "Can someone from the payments team take a look?")
        - No emojis
        - Target length: 3-5 sentences
        """,
    ]

    static func format(text: String, tone: String, completion: @escaping (String) -> Void) {
        let toneRule = toneInstructions[tone] ?? "Reformat in a \(tone) tone."
        let userPrompt = """
        \(toneRule)

        Message to reformat:
        \(text)
        """

        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: claudePath)
            task.arguments = ["--print", "--model", "haiku", "--system-prompt", systemPrompt, userPrompt]

            var env = ProcessInfo.processInfo.environment
            env["HOME"] = NSHomeDirectory()
            // PATH is inherited from LaunchAgent EnvironmentVariables (set by install.sh)
            // No hardcoded paths — works on any system regardless of package manager
            task.environment = env
            // Set working dir to /tmp so claude doesn't scan upward for CLAUDE.md files
            task.currentDirectoryPath = "/tmp"

            let outPipe = Pipe()
            let errPipe = Pipe()
            task.standardOutput = outPipe
            task.standardError = errPipe

            do {
                try task.launch()
                task.waitUntilExit()

                let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                var result = String(data: data, encoding: .utf8) ?? text

                // Strip ANSI escape codes
                result = result.replacingOccurrences(
                    of: #"\x1B\[[0-9;]*[mGKHFABCDEFsuJK]"#,
                    with: "",
                    options: .regularExpression
                )
                result = result.trimmingCharacters(in: .whitespacesAndNewlines)

                print("[DevKit] Claude response (\(result.count) chars): \(result.prefix(80))")
                DispatchQueue.main.async { completion(result.isEmpty ? text : result) }
            } catch {
                print("[DevKit] claude subprocess failed: \(error)")
                DispatchQueue.main.async { completion(text) }
            }
        }
    }
}
