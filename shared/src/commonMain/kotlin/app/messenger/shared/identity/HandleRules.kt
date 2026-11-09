package app.messenger.shared.identity

/** Canonical rules are shared by iOS and Android; server validation remains authoritative. */
object HandleRules {
    private val allowed = Regex("@[a-zA-Z0-9_]{3,24}")

    fun normalize(value: String): String? {
        val candidate = value.trim()
        if (!allowed.matches(candidate)) return null
        return candidate.lowercase()
    }
}
