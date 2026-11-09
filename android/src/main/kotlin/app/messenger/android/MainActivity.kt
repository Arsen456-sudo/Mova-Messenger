package app.messenger.android

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.unit.dp
import app.messenger.shared.data.MessengerRepository
import app.messenger.shared.data.SupabaseMessenger
import app.messenger.shared.identity.HandleRules
import app.messenger.shared.model.Conversation
import app.messenger.shared.model.Message
import app.messenger.shared.model.UserSearchResult
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.LocalDate

private object MessengerDesign {
    val spacing = 16.dp
    val page = 24.dp
    val primary = Color(0xFF315C9B)
    val background = Color(0xFFF8F9FC)
}

private val MessengerColors = lightColorScheme(
    primary = MessengerDesign.primary,
    background = MessengerDesign.background,
    surface = Color.White,
)

class MainActivity : ComponentActivity() {
    private val incomingDeepLink = mutableStateOf<String?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        incomingDeepLink.value = intent?.data?.toString()
        setContent {
            MaterialTheme(colorScheme = MessengerColors) {
                val repository = remember {
                    if (BuildConfig.SUPABASE_URL.isNotBlank() && BuildConfig.SUPABASE_PUBLISHABLE_KEY.isNotBlank()) {
                        SupabaseMessenger.repository(BuildConfig.SUPABASE_URL, BuildConfig.SUPABASE_PUBLISHABLE_KEY)
                    } else null
                }
                MessengerApp(repository, incomingDeepLink.value)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        incomingDeepLink.value = intent.data?.toString()
    }
}

private enum class AppRoute { SIGN_IN, SIGN_UP, HOME, SEARCH, CHAT }

@Composable
private fun MessengerApp(repository: MessengerRepository?, incomingDeepLink: String?) {
    var route by remember { mutableStateOf(if (repository?.currentUserId != null) AppRoute.HOME else AppRoute.SIGN_IN) }
    var selectedConversation by remember { mutableStateOf<Conversation?>(null) }
    var selectedTitle by remember { mutableStateOf("") }
    var notice by remember { mutableStateOf("") }
    val scope = rememberCoroutineScope()

    LaunchedEffect(incomingDeepLink, repository) {
        val url = incomingDeepLink ?: return@LaunchedEffect
        if (repository != null) {
            runCatching { repository.handleDeepLink(url) }
                .onSuccess { route = AppRoute.HOME; notice = "Email підтверджено. Вітаємо в Mova!" }
                .onFailure { notice = it.message ?: "Не вдалося завершити підтвердження email." }
        }
    }

    Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        when (route) {
            AppRoute.SIGN_IN -> AuthScreen(
                repository = repository,
                registering = false,
                notice = notice,
                onSwitch = { route = AppRoute.SIGN_UP; notice = "" },
                onAuthenticated = { route = AppRoute.HOME; notice = "" },
                onNotice = { notice = it },
            )
            AppRoute.SIGN_UP -> AuthScreen(
                repository = repository,
                registering = true,
                notice = notice,
                onSwitch = { route = AppRoute.SIGN_IN; notice = "" },
                onAuthenticated = { route = AppRoute.HOME; notice = "" },
                onNotice = { notice = it },
            )
            AppRoute.HOME -> if (repository == null) ConfigurationNotice() else HomeScreen(
                repository = repository,
                notice = notice,
                onSearch = { route = AppRoute.SEARCH },
                onOpen = { conversation, title -> selectedConversation = conversation; selectedTitle = title; route = AppRoute.CHAT },
                onSignOut = { scope.launch { repository.signOut(); route = AppRoute.SIGN_IN } },
            )
            AppRoute.SEARCH -> UserSearchScreen(
                repository = repository,
                onBack = { route = AppRoute.HOME },
                onOpen = { user ->
                    if (repository != null) scope.launch {
                        notice = ""
                        runCatching { repository.startDirectChat(user.id) }
                            .onSuccess { id ->
                                selectedConversation = Conversation(id = id, kind = "direct", title = user.handle)
                                selectedTitle = user.handle
                                route = AppRoute.CHAT
                            }
                            .onFailure { notice = it.message ?: "Не вдалося відкрити чат." }
                    }
                },
            )
            AppRoute.CHAT -> {
                val conversation = selectedConversation
                if (repository != null && conversation != null) ChatScreen(repository, conversation, selectedTitle) { route = AppRoute.HOME }
            }
        }
    }
}

@Composable
private fun AuthScreen(
    repository: MessengerRepository?,
    registering: Boolean,
    notice: String,
    onSwitch: () -> Unit,
    onAuthenticated: () -> Unit,
    onNotice: (String) -> Unit,
) {
    var handle by remember { mutableStateOf("") }
    var firstName by remember { mutableStateOf("") }
    var surname by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var birthDate by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val validHandle = HandleRules.normalize(if (handle.startsWith("@")) handle else "@$handle")
    val validDate = !registering || runCatching { LocalDate.parse(birthDate) }.isSuccess
    val validEmail = android.util.Patterns.EMAIL_ADDRESS.matcher(email.trim()).matches()
    val canContinue = repository != null && !busy && validEmail && password.length >= 8 &&
        if (registering) validHandle != null && firstName.isNotBlank() && validDate else true

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(MessengerDesign.page),
        verticalArrangement = Arrangement.spacedBy(MessengerDesign.spacing),
    ) {
        Text(if (registering) "Створи акаунт Mova" else "Увійти в Mova", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.SemiBold)
        Text(if (registering) "Спілкуйся зі своїм колом людей." else "Продовжуй свої розмови.", style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
        if (registering) {
            MovaField(handle, { handle = it }, "Нікнейм", prefix = "@")
            MovaField(firstName, { firstName = it }, "Ім’я")
            MovaField(surname, { surname = it }, "Прізвище · необов’язково")
        }
        MovaField(email, { email = it }, "Електронна пошта", keyboardType = KeyboardType.Email)
        MovaField(password, { password = it }, "Пароль", secure = true)
        if (registering) MovaField(birthDate, { birthDate = it }, "Дата народження · РРРР-ММ-ДД", keyboardType = KeyboardType.Number)
        Button(
            enabled = canContinue,
            modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp),
            onClick = {
                busy = true
                onNotice("")
                scope.launch {
                    val result = runCatching {
                        if (registering) repository!!.signUp(email, password, validHandle!!, firstName.trim(), surname.trim().ifBlank { null }, birthDate.trim())
                        else repository!!.signIn(email, password)
                    }
                    result.onSuccess {
                        if (registering && repository?.currentUserId == null) {
                            onNotice("Лист підтвердження надіслано. Відкрий його, щоб активувати профіль і створити «Нотатник».")
                        } else onAuthenticated()
                    }.onFailure { onNotice(it.message ?: "Не вдалося виконати запит. Перевір дані й спробуй ще раз.") }
                    busy = false
                }
            },
        ) { Text(if (busy) "Зачекай…" else if (registering) "Створити акаунт" else "Увійти") }
        TextButton(onClick = onSwitch) { Text(if (registering) "Уже маєш акаунт? Увійти" else "Створити новий акаунт") }
        if (notice.isNotBlank()) Text(notice, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.primary)
        if (repository == null) Text("Додай Supabase URL і publishable key у local.properties, щоб під’єднати сервер.", style = MaterialTheme.typography.bodySmall)
        if (registering && birthDate.isNotBlank() && !validDate) Text("Введи дату у форматі РРРР-ММ-ДД.", color = MaterialTheme.colorScheme.error)
    }
}

@Composable
private fun HomeScreen(
    repository: MessengerRepository,
    notice: String,
    onSearch: () -> Unit,
    onOpen: (Conversation, String) -> Unit,
    onSignOut: () -> Unit,
) {
    var conversations by remember { mutableStateOf<List<Conversation>>(emptyList()) }
    var error by remember { mutableStateOf("") }
    LaunchedEffect(repository) {
        runCatching { repository.loadConversations() }
            .onSuccess { conversations = it }
            .onFailure { error = it.message ?: "Не вдалося завантажити чати." }
    }
    Column(Modifier.fillMaxSize().padding(MessengerDesign.page), verticalArrangement = Arrangement.spacedBy(MessengerDesign.spacing)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Column {
                Text("Mova", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
                Text("Твої розмови", color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            TextButton(onClick = onSignOut) { Text("Вийти") }
        }
        OutlinedButton(onClick = onSearch, modifier = Modifier.fillMaxWidth()) { Text("Знайти людину за @ніком") }
        if (notice.isNotBlank()) Text(notice, style = MaterialTheme.typography.bodyMedium)
        if (error.isNotBlank()) Text(error, color = MaterialTheme.colorScheme.error)
        if (conversations.isEmpty() && error.isBlank()) {
            Text("Поки що чатів немає. «Нотатник» з’явиться після підтвердження email.", style = MaterialTheme.typography.bodyLarge)
        }
        LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            items(conversations, key = Conversation::id) { conversation ->
                val title = conversation.title.ifBlank { if (conversation.kind == "notes") "Нотатник" else "Особистий чат" }
                ElevatedCard(onClick = { onOpen(conversation, title) }, modifier = Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(18.dp)) {
                        Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                        Text(if (conversation.kind == "notes") "Твої особисті нотатки" else "Особисте листування", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
    }
}

@Composable
private fun UserSearchScreen(repository: MessengerRepository?, onBack: () -> Unit, onOpen: (UserSearchResult) -> Unit) {
    var query by remember { mutableStateOf("") }
    var users by remember { mutableStateOf<List<UserSearchResult>>(emptyList()) }
    var error by remember { mutableStateOf("") }
    Column(Modifier.fillMaxSize().padding(MessengerDesign.page), verticalArrangement = Arrangement.spacedBy(MessengerDesign.spacing)) {
        TextButton(onClick = onBack) { Text("‹  Чати") }
        Text("Знайти людину", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.SemiBold)
        MovaField(query, { query = it }, "@нік або ім’я")
        LaunchedEffect(query, repository) {
            if (query.trim().length < 2 || repository == null) { users = emptyList(); return@LaunchedEffect }
            delay(250)
            runCatching { repository.searchUsers(query) }
                .onSuccess { users = it; error = "" }
                .onFailure { error = it.message ?: "Пошук не вдався." }
        }
        if (error.isNotBlank()) Text(error, color = MaterialTheme.colorScheme.error)
        LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            items(users, key = UserSearchResult::id) { user ->
                ElevatedCard(onClick = { onOpen(user) }, modifier = Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(16.dp)) {
                        Text(user.handle, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                        Text(listOfNotNull(user.firstName, user.surname).joinToString(" "), color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
    }
}

@Composable
private fun ChatScreen(repository: MessengerRepository, conversation: Conversation, title: String, onBack: () -> Unit) {
    val messages = remember(conversation.id) { mutableStateListOf<Message>() }
    var draft by remember { mutableStateOf("") }
    var error by remember { mutableStateOf("") }
    val scope = rememberCoroutineScope()
    LaunchedEffect(conversation.id) {
        runCatching { repository.loadMessages(conversation.id) }.onSuccess { messages.clear(); messages.addAll(it) }.onFailure { error = it.message ?: "Не вдалося завантажити повідомлення." }
        runCatching { repository.observeMessages(conversation.id).collect { fresh -> messages.clear(); messages.addAll(fresh.sortedBy(Message::sentAt)) } }
            .onFailure { error = it.message ?: "Втратився зв’язок із оновленнями чату." }
    }
    Column(Modifier.fillMaxSize().padding(horizontal = 16.dp, vertical = 8.dp)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            TextButton(onClick = onBack) { Text("‹  Чати") }
            Text(title, modifier = Modifier.padding(top = 14.dp), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.width(48.dp))
        }
        if (error.isNotBlank()) Text(error, color = MaterialTheme.colorScheme.error)
        LazyColumn(Modifier.weight(1f).fillMaxWidth(), reverseLayout = true, contentPadding = PaddingValues(vertical = 12.dp)) {
            items(messages.asReversed(), key = Message::id) { message ->
                Surface(color = if (message.senderId == repository.currentUserId) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant, shape = MaterialTheme.shapes.large, modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
                    Text(message.body, modifier = Modifier.padding(14.dp), style = MaterialTheme.typography.bodyLarge)
                }
            }
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedTextField(draft, { draft = it }, Modifier.weight(1f), placeholder = { Text("Повідомлення") }, maxLines = 4)
            Button(
                enabled = draft.isNotBlank(),
                onClick = {
                    val text = draft.trim()
                    draft = ""
                    scope.launch { runCatching { repository.sendMessage(conversation.id, text) }.onFailure { error = it.message ?: "Не вдалося надіслати повідомлення." } }
                },
            ) { Text("Надіслати") }
        }
    }
}

@Composable
private fun ConfigurationNotice() {
    Column(Modifier.fillMaxSize().padding(MessengerDesign.page), verticalArrangement = Arrangement.Center) {
        Text("Supabase не налаштований", style = MaterialTheme.typography.headlineSmall)
        Text("Заповни supabase.url та supabase.publishableKey у local.properties.")
    }
}

@Composable
private fun MovaField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    prefix: String? = null,
    secure: Boolean = false,
    keyboardType: KeyboardType = KeyboardType.Text,
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = Modifier.fillMaxWidth(),
        label = { Text(label) },
        prefix = prefix?.let { { Text(it) } },
        singleLine = true,
        visualTransformation = if (secure) PasswordVisualTransformation() else androidx.compose.ui.text.input.VisualTransformation.None,
        keyboardOptions = KeyboardOptions(keyboardType = if (secure) KeyboardType.Password else keyboardType),
    )
}
