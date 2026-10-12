package com.example.test
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// ---------- Цвета из макета (уточните HEX в Figma через Dev Mode) ----------
val AuthBackground = Color(0xFFFFFDE6)   // кремовый фон
val AuthOrange = Color(0xFFF57F17)       // оранжевый акцент
val AuthBlack = Color(0xFF111111)        // кнопки и текст
val AuthHint = Color(0xFF8A8A8A)         // серые подсказки

// Шрифт заголовков в макете засечковый (похож на Alegreya).
// Скачайте его в Google Fonts, положите в res/font и замените FontFamily.Serif.
val AuthSerif = FontFamily.Serif



@Composable
fun AuthTextField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    icon: ImageVector,
    iconTint: Color,
    modifier: Modifier = Modifier,
    placeholderColor: Color = AuthHint,
    isPassword: Boolean = false,
    keyboardType: KeyboardType = KeyboardType.Text,
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = modifier
            .fillMaxWidth()
            .height(56.dp),
        singleLine = true,
        shape = RoundedCornerShape(50),
        textStyle = TextStyle(fontSize = 14.sp, color = AuthOrange),
        placeholder = {
            Text(text = placeholder, color = placeholderColor, fontSize = 14.sp)
        },
        leadingIcon = {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = iconTint,
                modifier = Modifier.size(20.dp)
            )
        },
        visualTransformation = if (isPassword) PasswordVisualTransformation() else VisualTransformation.None,
        keyboardOptions = KeyboardOptions(keyboardType = if (isPassword) KeyboardType.Password else keyboardType),
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = AuthBlack,
            unfocusedBorderColor = AuthBlack,
            focusedContainerColor = AuthBackground,
            unfocusedContainerColor = AuthBackground,
            cursorColor = AuthOrange,
        )
    )
}

@Composable
fun AuthButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    Button(
        onClick = onClick,
        modifier = modifier
            .height(48.dp)
            .widthIn(min = 200.dp),
        shape = RoundedCornerShape(50),
        contentPadding = PaddingValues(horizontal = 28.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = AuthBlack,
            contentColor = Color.White
        )
    ) {
        Text(
            text = text,
            fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            softWrap = false
        )
    }
}



@Composable
fun LoginScreen(
    onLoginClick: (email: String, password: String) -> Unit = { _, _ -> },
    onForgotPasswordClick: () -> Unit = {},
    onRegisterClick: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(AuthBackground)
            .imePadding()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(Modifier.height(24.dp))

        // Логотип: экспортируйте из Figma как PNG и положите в res/drawable/logo_por12z.png
        Image(
            painter = painterResource(R.drawable.logo_por12z),
            contentDescription = "Por12z",
            modifier = Modifier.size(120.dp)
        )

        Spacer(Modifier.height(24.dp))

        Text(
            text = "Добрый день!",
            fontFamily = AuthSerif,
            fontSize = 30.sp,
            color = AuthBlack
        )
        Spacer(Modifier.height(6.dp))
        Text(
            text = "Введите свою почту и пароль, чтобы войти",
            fontFamily = AuthSerif,
            fontSize = 12.sp,
            color = AuthOrange,
            textAlign = TextAlign.Center
        )

        Spacer(Modifier.height(36.dp))

        AuthTextField(
            value = email,
            onValueChange = { email = it },
            placeholder = "ivanovivan@gmail.com",
            placeholderColor = AuthOrange,
            icon = Icons.Default.Email,
            iconTint = AuthOrange,
            keyboardType = KeyboardType.Email
        )
        Spacer(Modifier.height(20.dp))
        AuthTextField(
            value = password,
            onValueChange = { password = it },
            placeholder = "Введите пароль",
            icon = Icons.Default.Lock,
            iconTint = AuthOrange,
            isPassword = true
        )

        Text(
            text = "Забыли пароль?",
            color = AuthOrange,
            fontFamily = AuthSerif,
            fontSize = 11.sp,
            modifier = Modifier
                .align(Alignment.End)
                .padding(top = 8.dp)
                .clickable { onForgotPasswordClick() }
        )

        Spacer(Modifier.height(28.dp))
        AuthButton(text = "Войти", onClick = { onLoginClick(email, password) })

        Spacer(Modifier.height(48.dp))

        Text(
            text = buildAnnotatedString {
                withStyle(SpanStyle(color = AuthOrange)) { append("Нет аккаунта? ") }
                withStyle(SpanStyle(color = AuthBlack)) { append("Зарегистрируйтесь!") }
            },
            fontFamily = AuthSerif,
            fontSize = 14.sp,
            modifier = Modifier.clickable { onRegisterClick() }
        )
        Spacer(Modifier.height(24.dp))
    }
}

// ---------- Экран регистрации ----------

@Composable
fun RegisterScreen(
    onBackClick: () -> Unit = {},
    onRegisterClick: (name: String, email: String, password: String) -> Unit = { _, _, _ -> },
    onLoginClick: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    var name by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var repeatPassword by remember { mutableStateOf("") }
    var agreed by remember { mutableStateOf(false) }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(AuthBackground)
            .imePadding()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(Modifier.fillMaxWidth()) {
            IconButton(
                onClick = onBackClick,
                modifier = Modifier.align(Alignment.CenterStart)
            ) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Назад",
                    tint = AuthBlack
                )
            }
        }

        Spacer(Modifier.height(36.dp))

        Text(
            text = "Регистрация",
            fontFamily = AuthSerif,
            fontSize = 30.sp,
            color = AuthBlack
        )
        Spacer(Modifier.height(10.dp))
        Text(
            text = "Заполните все поля, чтобы создать аккаунт",
            fontFamily = AuthSerif,
            fontSize = 12.sp,
            color = AuthOrange,
            textAlign = TextAlign.Center
        )

        Spacer(Modifier.height(40.dp))

        AuthTextField(
            value = name,
            onValueChange = { name = it },
            placeholder = "Ivanov Ivan",
            placeholderColor = AuthOrange,
            icon = Icons.Default.Person,
            iconTint = AuthBlack
        )
        Spacer(Modifier.height(16.dp))
        AuthTextField(
            value = email,
            onValueChange = { email = it },
            placeholder = "Email",
            placeholderColor = AuthOrange,
            icon = Icons.Default.Email,
            iconTint = AuthOrange,
            keyboardType = KeyboardType.Email
        )
        Spacer(Modifier.height(16.dp))
        AuthTextField(
            value = password,
            onValueChange = { password = it },
            placeholder = "Придумайте пароль",
            icon = Icons.Default.Lock,
            iconTint = AuthBlack,
            isPassword = true
        )
        Spacer(Modifier.height(16.dp))
        AuthTextField(
            value = repeatPassword,
            onValueChange = { repeatPassword = it },
            placeholder = "Повторите пароль",
            icon = Icons.Default.Lock,
            iconTint = AuthBlack,
            isPassword = true
        )

        Spacer(Modifier.height(8.dp))

        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Start
        ) {
            Checkbox(
                checked = agreed,
                onCheckedChange = { agreed = it },
                colors = CheckboxDefaults.colors(
                    checkedColor = AuthOrange,
                    uncheckedColor = AuthBlack
                )
            )
            Text(
                text = buildAnnotatedString {
                    append("Я согласен с ")
                    withStyle(SpanStyle(color = AuthOrange)) { append("политикой конфиденциальности") }
                },
                fontSize = 10.sp,
                color = AuthBlack
            )
        }

        Spacer(Modifier.height(16.dp))
        AuthButton(
            text = "Зарегистрироваться",
            onClick = { onRegisterClick(name, email, password) }
        )

        Spacer(Modifier.height(28.dp))

        Text(
            text = buildAnnotatedString {
                withStyle(SpanStyle(color = AuthBlack)) { append("Уже есть аккаунт? ") }
                withStyle(SpanStyle(color = AuthOrange)) { append("Войти") }
            },
            fontSize = 18.sp,
            fontWeight = FontWeight.Medium,
            modifier = Modifier.clickable { onLoginClick() }
        )
        Spacer(Modifier.height(24.dp))
    }
}

// ---------- Preview ----------

@Preview(showBackground = true, showSystemUi = true)
@Composable
fun LoginScreenPreview() {
    LoginScreen()
}

@Preview(showBackground = true, showSystemUi = true)
@Composable
fun RegisterScreenPreview() {
    RegisterScreen()
}
