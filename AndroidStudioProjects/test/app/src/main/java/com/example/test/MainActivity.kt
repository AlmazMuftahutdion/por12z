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
enum class Screen { Login, Register, Main, Profile, MyBuilds, UsersBuilds }

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            TestTheme {
                Scaffold(modifier = Modifier.fillMaxSize()) { innerPadding ->
                    var screen by rememberSaveable { mutableStateOf(Screen.Login) }

                    // Кнопка «Назад» на телефоне
                    BackHandler(enabled = screen != Screen.Login && screen != Screen.Main) {
                        screen = when (screen) {
                            Screen.Register -> Screen.Login
                            Screen.Profile -> Screen.Main
                            Screen.MyBuilds, Screen.UsersBuilds -> Screen.Profile
                            else -> screen
                        }
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
                                onMyBuildsClick = { screen = Screen.MyBuilds },
                                onUsersBuildsClick = { screen = Screen.UsersBuilds },
                                onLogoutClick = { screen = Screen.Login }
                            )

                            Screen.MyBuilds -> MyBuildsScreen(
                                modifier = pad,
                                onBackClick = { screen = Screen.Profile },
                                onOpenInConfigurator = { screen = Screen.Main }
                            )

                            Screen.UsersBuilds -> UsersBuildsScreen(
                                modifier = pad,
                                onBackClick = { screen = Screen.Profile },
                                onOpenInConfigurator = { screen = Screen.Main }
                            )
                        }
                    }
                }
            }
        }
    }
}