package com.example.test

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ExitToApp
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.roundToInt

// ---------- Картинки ----------
// Аватар в профиле пока остаётся заглушкой. Когда будет настоящая, поменяйте здесь.
private val PlaceholderImage = R.drawable.logo_por12z

// Задний фон экранов
private val BackgroundImage = R.drawable.logo_por12z

val DarkBg = Color(0xFF1B1B1B)
val DarkPanel = Color(0xFF2B2B2B)
val DarkButton = Color(0xFF3A3A3A)
val CreamChip = Color(0xFFE6E2D3)
val GrayText = Color(0xFF9A9A9A)
val LightBorder = Color(0xFFE8D9A8)

// Фон с узором (картинка img.png)
@Composable
fun DarkScreenBackground(content: @Composable BoxScope.() -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(DarkBg)
    ) {
        Image(
            painter = painterResource(BackgroundImage),
            contentDescription = null,
            modifier = Modifier.fillMaxSize(),
            contentScale = ContentScale.Crop,
            alpha = 0.40f
        )
        content()
    }
}

// =====================================================================
//                            ГЛАВНЫЙ ЭКРАН
// =====================================================================

private data class ComponentItem(val title: String, val iconRes: Int)

private val componentItems = listOf(
    ComponentItem("Процессор", R.drawable.procesor),
    ComponentItem("Мат. плата", R.drawable.motherplata),
    ComponentItem("Блок питания", R.drawable.block),
    ComponentItem("Корпус", R.drawable.corpus),
    ComponentItem("Видеокарта", R.drawable.videocarta),
    ComponentItem("Охлаждение процессора", R.drawable.coldpc),
    ComponentItem("Оперативная память", R.drawable.operativka),
    ComponentItem("Накопители", R.drawable.nacopiteli)
)

@Composable
fun MainScreen(
    onMenuClick: () -> Unit = {},
    onAddClick: (component: String) -> Unit = {},
    onGenerateClick: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    var aiMode by rememberSaveable { mutableStateOf(false) }
    var budget by rememberSaveable { mutableStateOf(50000f) }
    var platform by rememberSaveable { mutableStateOf("AMD") }
    var socket by rememberSaveable { mutableStateOf("AM5") }
    var gpu by rememberSaveable { mutableStateOf("NVIDIA") }
    var storage by rememberSaveable { mutableStateOf("SSD") }

    DarkScreenBackground {
        Column(
            modifier = modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp)
        ) {
            Spacer(Modifier.height(8.dp))

            IconButton(onClick = onMenuClick) {
                Icon(
                    imageVector = Icons.Default.Menu,
                    contentDescription = "Меню",
                    tint = Color.White
                )
            }

            Spacer(Modifier.height(8.dp))

            // Плашка «Автоматическая сборка с режимом ИИ»
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(DarkPanel)
                    .border(1.dp, Color(0xFF444444))
                    .clickable { aiMode = !aiMode }
                    .padding(vertical = 6.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "Автоматическая сборка с режимом ИИ",
                    color = Color.White,
                    fontSize = 12.sp
                )
            }

            // Окно сборки с ИИ: плавно раскрывается и сдвигает список компонентов вниз
            AnimatedVisibility(
                visible = aiMode,
                enter = expandVertically(animationSpec = tween(500)) + fadeIn(tween(500)),
                exit = shrinkVertically(animationSpec = tween(400)) + fadeOut(tween(400))
            ) {
                AiPanel(
                    budget = budget,
                    onBudgetChange = { budget = it },
                    platform = platform,
                    onPlatformChange = { platform = it },
                    socket = socket,
                    onSocketChange = { socket = it },
                    gpu = gpu,
                    onGpuChange = { gpu = it },
                    storage = storage,
                    onStorageChange = { storage = it },
                    onClose = { aiMode = false },
                    onGenerate = onGenerateClick
                )
            }

            Spacer(Modifier.height(16.dp))

            componentItems.forEach { item ->
                ComponentRow(
                    title = item.title,
                    iconRes = item.iconRes,
                    onAdd = { onAddClick(item.title) }
                )
            }

            Spacer(Modifier.height(24.dp))
        }
    }
}

@Composable
private fun AiPanel(
    budget: Float,
    onBudgetChange: (Float) -> Unit,
    platform: String,
    onPlatformChange: (String) -> Unit,
    socket: String,
    onSocketChange: (String) -> Unit,
    gpu: String,
    onGpuChange: (String) -> Unit,
    storage: String,
    onStorageChange: (String) -> Unit,
    onClose: () -> Unit,
    onGenerate: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 8.dp)
            .background(DarkPanel, RoundedCornerShape(6.dp))
            .padding(16.dp)
    ) {
        Text(text = "Ваш бюджет", color = Color.White, fontSize = 12.sp)
        Text(
            text = "₽ " + formatMoney((budget / 1000f).roundToInt() * 1000),
            color = Color.White,
            fontSize = 12.sp
        )
        Slider(
            value = budget,
            onValueChange = onBudgetChange,
            valueRange = 10000f..300000f,
            colors = SliderDefaults.colors(
                thumbColor = AuthOrange,
                activeTrackColor = AuthOrange,
                inactiveTrackColor = Color(0xFF555555)
            )
        )

        Spacer(Modifier.height(8.dp))

        // Платформа и сокет
        GroupBox {
            Text(text = "Платформа", color = Color.White, fontSize = 11.sp)
            Spacer(Modifier.height(4.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                OptionChip("AMD", platform == "AMD", { onPlatformChange("AMD") })
                OptionChip("Intel", platform == "Intel", { onPlatformChange("Intel") })
            }
            Spacer(Modifier.height(8.dp))
            Text(text = "Сокет", color = Color.White, fontSize = 11.sp)
            Spacer(Modifier.height(4.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                OptionChip("AM5", socket == "AM5", { onSocketChange("AM5") })
                OptionChip("AM4", socket == "AM4", { onSocketChange("AM4") })
            }
        }

        Spacer(Modifier.height(10.dp))

        // Компоненты
        GroupBox {
            Text(text = "Компоненты", color = Color.White, fontSize = 11.sp)
            Spacer(Modifier.height(8.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = "Графический процессор",
                    color = Color.White,
                    fontSize = 11.sp,
                    modifier = Modifier.weight(1f)
                )
                Row(horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                    OptionChip("NVIDIA", gpu == "NVIDIA", { onGpuChange("NVIDIA") }, width = 48.dp)
                    OptionChip("AMD", gpu == "AMD", { onGpuChange("AMD") }, width = 40.dp)
                }
            }

            Spacer(Modifier.height(6.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = "Накопитель",
                    color = Color.White,
                    fontSize = 11.sp,
                    modifier = Modifier.weight(1f)
                )
                Row(horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                    OptionChip("SSD", storage == "SSD", { onStorageChange("SSD") }, width = 40.dp)
                    OptionChip("HDD", storage == "HDD", { onStorageChange("HDD") }, width = 40.dp)
                }
            }

            Spacer(Modifier.height(10.dp))

            Text(
                text = "Сохранить настройки",
                color = Color.White,
                fontSize = 13.sp,
                modifier = Modifier.align(Alignment.CenterHorizontally)
            )
            Spacer(Modifier.height(6.dp))
            Row(
                modifier = Modifier.align(Alignment.CenterHorizontally),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                // Галочка (логику сохранения добавите позже)
                Box(
                    modifier = Modifier
                        .width(56.dp)
                        .height(24.dp)
                        .clip(RoundedCornerShape(4.dp))
                        .background(CreamChip)
                        .clickable { },
                    contentAlignment = Alignment.Center
                ) {
                    Image(
                        painter = painterResource(R.drawable.plus),
                        contentDescription = "Сохранить",
                        modifier = Modifier.size(16.dp)
                    )
                }
                // Крестик: закрывает окно ИИ
                Box(
                    modifier = Modifier
                        .width(56.dp)
                        .height(24.dp)
                        .clip(RoundedCornerShape(4.dp))
                        .background(DarkPanel)
                        .border(1.dp, Color(0xFFC0392B), RoundedCornerShape(4.dp))
                        .clickable(onClick = onClose),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "Закрыть",
                        tint = Color(0xFFC0392B),
                        modifier = Modifier.size(16.dp)
                    )
                }
            }
            Spacer(Modifier.height(4.dp))
        }

        Spacer(Modifier.height(16.dp))

        OutlinedButton(
            onClick = onGenerate,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp),
            shape = RoundedCornerShape(6.dp),
            border = BorderStroke(1.dp, AuthOrange),
            colors = ButtonDefaults.outlinedButtonColors(contentColor = AuthOrange)
        ) {
            Text(text = "Сгенерировать сборку", fontSize = 13.sp)
        }
    }
}

@Composable
private fun GroupBox(content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .border(1.dp, LightBorder, RoundedCornerShape(6.dp))
            .padding(10.dp),
        content = content
    )
}

@Composable
private fun OptionChip(
    text: String,
    selected: Boolean,
    onClick: () -> Unit,
    width: Dp = 60.dp,
) {
    val shape = RoundedCornerShape(4.dp)
    Box(
        modifier = Modifier
            .width(width)
            .height(24.dp)
            .clip(shape)
            .background(if (selected) CreamChip else DarkPanel)
            .border(1.dp, if (selected) CreamChip else AuthOrange.copy(alpha = 0.7f), shape)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = text,
            fontSize = 10.sp,
            color = if (selected) Color(0xFF222222) else GrayText,
            maxLines = 1
        )
    }
}

@Composable
private fun ComponentRow(title: String, iconRes: Int, onAdd: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Иконка компонента
        Image(
            painter = painterResource(iconRes),
            contentDescription = null,
            modifier = Modifier.size(32.dp)
        )
        Spacer(Modifier.width(10.dp))
        Text(
            text = title,
            color = Color.White,
            fontSize = 13.sp,
            modifier = Modifier.weight(1f)
        )
        Text(text = "Обязательно", color = GrayText, fontSize = 9.sp)
        Spacer(Modifier.width(8.dp))
        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(4.dp))
                .background(DarkButton)
                .clickable(onClick = onAdd)
                .padding(horizontal = 8.dp, vertical = 5.dp)
        ) {
            Text(text = "Добавить", color = Color.White, fontSize = 9.sp)
        }
    }
}

private fun formatMoney(value: Int): String =
    value.toString().reversed().chunked(3).joinToString(" ").reversed()

// =====================================================================
//                              ПРОФИЛЬ
// =====================================================================

@Composable
fun ProfileScreen(
    email: String = "TUTVASHAPOCHTA@GMAIL.COM",
    onMainMenuClick: () -> Unit = {},
    onMyBuildsClick: () -> Unit = {},
    onUsersBuildsClick: () -> Unit = {},
    onLogoutClick: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    DarkScreenBackground {
        Column(
            modifier = modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(Modifier.height(48.dp))

            // Аватар (заглушка)
            Image(
                painter = painterResource(PlaceholderImage),
                contentDescription = "Аватар",
                modifier = Modifier
                    .size(140.dp)
                    .clip(CircleShape)
                    .background(AuthOrange)
                    .border(2.dp, Color.White, CircleShape)
                    .padding(20.dp),
                contentScale = ContentScale.Fit
            )

            Spacer(Modifier.height(12.dp))

            Text(
                text = email,
                color = AuthOrange,
                fontFamily = AuthSerif,
                fontSize = 14.sp
            )

            Spacer(Modifier.height(40.dp))

            ProfileButton(text = "Главное меню", onClick = onMainMenuClick) { ChevronIcon() }
            Spacer(Modifier.height(16.dp))
            ProfileButton(text = "Мои сборки", onClick = onMyBuildsClick) { ChevronIcon() }
            Spacer(Modifier.height(16.dp))
            ProfileButton(text = "Сборки пользователей", onClick = onUsersBuildsClick) { ChevronIcon() }
            Spacer(Modifier.height(16.dp))
            ProfileButton(
                text = "Выйти",
                onClick = onLogoutClick,
                borderColor = LightBorder,
                contentColor = LightBorder
            ) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ExitToApp,
                    contentDescription = null,
                    tint = LightBorder,
                    modifier = Modifier.size(20.dp)
                )
            }

            Spacer(Modifier.height(24.dp))
        }
    }
}

@Composable
private fun ChevronIcon() {
    Icon(
        imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
        contentDescription = null,
        tint = Color.White
    )
}

@Composable
private fun ProfileButton(
    text: String,
    onClick: () -> Unit,
    borderColor: Color = Color.Black,
    contentColor: Color = Color.White,
    trailing: @Composable () -> Unit,
) {
    val shape = RoundedCornerShape(50)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(48.dp)
            .clip(shape)
            .background(Color(0xFF1E1E1E))
            .border(1.dp, borderColor, shape)
            .clickable(onClick = onClick)
            .padding(horizontal = 18.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = text,
            color = contentColor,
            fontFamily = AuthSerif,
            fontSize = 14.sp,
            modifier = Modifier.weight(1f)
        )
        trailing()
    }
}

// ---------- Preview ----------

@Preview(showBackground = true, showSystemUi = true)
@Composable
fun MainScreenPreview() {
    MainScreen()
}

@Preview(showBackground = true, showSystemUi = true)
@Composable
fun ProfileScreenPreview() {
    ProfileScreen()
}