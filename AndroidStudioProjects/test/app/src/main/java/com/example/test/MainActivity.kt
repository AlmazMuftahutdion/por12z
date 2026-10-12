package com.example.test

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.example.test.ui.theme.TestTheme

// Все экраны приложения
enum class Screen { Login, Register, Main, Profile }

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            TestTheme {
                Scaffold(modifier = Modifier.fillMaxSize()) { innerPadding ->
                    var screen by rememberSaveable { mutableStateOf(Screen.Login) }

                    // Кнопка «Назад» на телефоне
                    BackHandler(enabled = screen == Screen.Register || screen == Screen.Profile) {
                        screen = if (screen == Screen.Register) Screen.Login else Screen.Main
                    }

                    Crossfade(
                        targetState = screen,
                        animationSpec = tween(300),
                        label = "screens"
                    ) { current ->
                        val pad = Modifier.padding(innerPadding)
                        when (current) {
                            Screen.Login -> LoginScreen(
                                modifier = pad,
                                onLoginClick = { _, _ -> screen = Screen.Main },
                                onRegisterClick = { screen = Screen.Register }
                            )

                            Screen.Register -> RegisterScreen(
                                modifier = pad,
                                onBackClick = { screen = Screen.Login },
                                onLoginClick = { screen = Screen.Login },
                                onRegisterClick = { _, _, _ -> screen = Screen.Main }
                            )

                            Screen.Main -> MainScreen(
                                modifier = pad,
                                onMenuClick = { screen = Screen.Profile }
                            )

                            Screen.Profile -> ProfileScreen(
                                modifier = pad,
                                onMainMenuClick = { screen = Screen.Main },
                                onLogoutClick = { screen = Screen.Login }
                            )
                        }
                    }
                }
            }
        }
    }
}
