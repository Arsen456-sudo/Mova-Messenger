package app.messenger.shared.model

import kotlinx.serialization.Serializable
import kotlinx.serialization.SerialName

@Serializable
data class Profile(
    val id: String,
    val handle: String,
    @SerialName("first_name")
    val firstName: String,
    @SerialName("surname")
    val surname: String? = null,
    @SerialName("avatar_url")
    val avatarUrl: String? = null,
    @SerialName("birth_date")
    val birthDate: String? = null,
)

@Serializable
data class UserSearchResult(val id: String, val handle: String, @SerialName("first_name") val firstName: String, val surname: String? = null, @SerialName("avatar_url") val avatarUrl: String? = null)

@Serializable
data class Message(val id: String, @SerialName("conversation_id") val conversationId: String, @SerialName("sender_id") val senderId: String, val body: String, @SerialName("created_at") val sentAt: String)

@Serializable
data class Conversation(val id: String, val kind: String, val title: String, val lastMessage: Message? = null)

@Serializable
data class RegisterRequest(val email: String, val password: String, val handle: String, @SerialName("first_name") val firstName: String, val surname: String? = null, @SerialName("birth_date") val birthDate: String)

@Serializable
data class SendMessageRequest(val body: String)
