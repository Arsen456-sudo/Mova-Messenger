package app.messenger.shared.data

import app.messenger.shared.model.Message
import app.messenger.shared.model.Conversation
import app.messenger.shared.model.UserSearchResult
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.parseSessionFromUrl
import io.github.jan.supabase.auth.providers.builtin.Email
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.rpc
import io.github.jan.supabase.postgrest.query.Order
import io.github.jan.supabase.realtime.Realtime
import io.github.jan.supabase.realtime.selectAsFlow
import io.github.jan.supabase.annotations.SupabaseExperimental
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

object SupabaseMessenger {
    fun repository(projectUrl: String, publishableKey: String): MessengerRepository {
        val client = createSupabaseClient(
            supabaseUrl = projectUrl,
            supabaseKey = publishableKey,
        ) {
            install(io.github.jan.supabase.auth.Auth) {
                scheme = "mova"
                host = "auth-callback"
                flowType = io.github.jan.supabase.auth.FlowType.PKCE
            }
            install(Postgrest)
            install(Realtime)
        }
        return MessengerRepository(client)
    }
}

class MessengerRepository internal constructor(private val supabase: SupabaseClient) {
    val currentUserId: String?
        get() = supabase.auth.currentUserOrNull()?.id

    @Throws(Exception::class)
    suspend fun signUp(email: String, password: String, handle: String, firstName: String, surname: String?, birthDate: String) {
        supabase.auth.signUpWith(Email, redirectUrl = "mova://auth-callback") {
            this.email = email.trim()
            this.password = password
            data = buildJsonObject {
                put("handle", handle.trim())
                put("first_name", firstName.trim())
                put("surname", surname?.trim().orEmpty())
                put("birth_date", birthDate.trim())
            }
        }
    }

    @Throws(Exception::class)
    suspend fun signIn(email: String, password: String) {
        supabase.auth.signInWith(Email) {
            this.email = email.trim()
            this.password = password
        }
    }

    @Throws(Exception::class)
    suspend fun handleDeepLink(url: String) {
        val session = supabase.auth.parseSessionFromUrl(url)
        supabase.auth.importSession(session)
    }

    @Throws(Exception::class)
    suspend fun signOut() {
        supabase.auth.signOut()
    }

    @Throws(Exception::class)
    suspend fun completeProfile(handle: String, firstName: String, surname: String?, avatarUrl: String?, birthDate: String) {
        supabase.postgrest.rpc(
            "complete_profile",
            CompleteProfileParams(handle, firstName, surname, avatarUrl, birthDate),
        )
    }

    @Throws(Exception::class)
    suspend fun searchUsers(query: String): List<UserSearchResult> = supabase.postgrest
        .rpc("search_users", SearchUsersParams(query.trim()))
        .decodeList<UserSearchResult>()

    @Throws(Exception::class)
    suspend fun loadConversations(): List<Conversation> = supabase.postgrest
        .rpc("list_conversations")
        .decodeList<Conversation>()

    @Throws(Exception::class)
    suspend fun startDirectChat(otherUserId: String): String = supabase.postgrest
        .rpc("start_direct_chat", StartDirectChatParams(otherUserId))
        .decodeSingle<String>()

    @Throws(Exception::class)
    suspend fun sendMessage(conversationId: String, body: String) {
        require(body.isNotBlank() && body.length <= 16_000)
        val userId = supabase.auth.currentUserOrNull()?.id ?: error("Sign-in required")
        supabase.from("messages").insert(NewMessage(conversationId, userId, body))
    }

    @Throws(Exception::class)
    suspend fun loadMessages(conversationId: String): List<Message> = supabase.from("messages")
        .select {
            filter { eq("conversation_id", conversationId) }
            order(column = "created_at", order = Order.DESCENDING)
            limit(count = 100)
        }
        .decodeList<Message>()
        .sortedBy(Message::sentAt)

    @OptIn(SupabaseExperimental::class)
    fun observeMessages(conversationId: String): Flow<List<Message>> = supabase.from("messages")
        .selectAsFlow(primaryKey = Message::id) {
            eq("conversation_id", conversationId)
        }

    private val nativeScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val nativeObservers = mutableMapOf<String, Job>()

    /** Bridges the shared Realtime flow to UIKit without duplicating data access in Swift. */
    fun observeMessages(conversationId: String, onUpdate: (List<Message>) -> Unit) {
        nativeObservers.remove(conversationId)?.cancel()
        nativeObservers[conversationId] = nativeScope.launch {
            observeMessages(conversationId).collect(onUpdate)
        }
    }

    fun stopObservingMessages(conversationId: String) {
        nativeObservers.remove(conversationId)?.cancel()
    }
}

@Serializable private data class CompleteProfileParams(
    @SerialName("p_handle") val handle: String,
    @SerialName("p_first_name") val firstName: String,
    @SerialName("p_surname") val surname: String?,
    @SerialName("p_avatar_url") val avatarUrl: String?,
    @SerialName("p_birth_date") val birthDate: String,
)

@Serializable private data class SearchUsersParams(@SerialName("p_query") val query: String)
@Serializable private data class StartDirectChatParams(@SerialName("p_other_user") val otherUserId: String)

@Serializable private data class NewMessage(
    @SerialName("conversation_id") val conversationId: String,
    @SerialName("sender_id") val senderId: String,
    val body: String,
)
