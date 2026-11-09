package app.messenger.shared.api

/** Shared route names prevent platform clients from drifting apart. */
object ApiContract {
    const val REGISTER = "/v1/auth/register"
    const val LOGIN = "/v1/auth/login"
    const val SEARCH_USERS = "/v1/users/search"
    const val CONVERSATIONS = "/v1/conversations"
    const val NOTES = "/v1/conversations/notes"
    const val MESSAGES = "/v1/conversations/{id}/messages"
    const val MESSAGE_SOCKET = "/v1/conversations/{id}/events"
}
