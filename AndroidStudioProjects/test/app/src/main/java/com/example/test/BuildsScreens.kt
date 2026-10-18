package com.example.test

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.floor



data class BuildItem(
    val id: Int,
    val cpu: String,
    val motherboard: String,
    val gpu: String,
    val ram: String,
    val storage: String,
    val rating: Float? = null,          // null = рейтинг не показываем (экран «Мои сборки»)
    val previewRes: Int = R.drawable.procesor,
)

// Демо-данные, пока нет бэкенда. Заменишь на реальные.
private fun demoBuilds(withRating: Boolean) = List(6) { i ->
    BuildItem(
        id = i,
        cpu = "INTEL CORE I9 X-series",
        motherboard = "MSI MPG B550 GAMING PLUS",
        gpu = "Palit GeForce RTX 5060 Ti Dual",
        ram = "Kingston FURY Beast Black 32гб",
        storage = "512 гб м.2 NVMe накопитель ADATA LEGEND 710",
        rating = if (withRating) 4.5f else null
    )
}

private val CardBorder = Color(0xFF3A3A3A)
private val StarGold = Color(0xFFFFD54F)

// ---------- Экран «Пользовательские сборки» ----------

@Composable
fun UsersBuildsScreen(
    builds: List<BuildItem> = demoBuilds(withRating = true),
    onBackClick: () -> Unit = {},
    onOpenInConfigurator: (BuildItem) -> Unit = {},
    modifier: Modifier = Modifier,
) {
    BuildsListScreen(
        title = "Пользовательские сборки",
        builds = builds,
        onBackClick = onBackClick,
        onOpenInConfigurator = onOpenInConfigurator,
        modifier = modifier
    )
}

// ---------- Экран «Мои сборки» ----------

@Composable
fun MyBuildsScreen(
    builds: List<BuildItem> = demoBuilds(withRating = false),
    onBackClick: () -> Unit = {},
    onOpenInConfigurator: (BuildItem) -> Unit = {},
    modifier: Modifier = Modifier,
) {
    BuildsListScreen(
        title = "Мои сборки",
        builds = builds,
        onBackClick = onBackClick,
        onOpenInConfigurator = onOpenInConfigurator,
        modifier = modifier
    )
}

// ---------- Общий каркас ----------

@Composable
private fun BuildsListScreen(
    title: String,
    builds: List<BuildItem>,
    onBackClick: () -> Unit,
    onOpenInConfigurator: (BuildItem) -> Unit,
    modifier: Modifier = Modifier,
) {
    DarkScreenBackground {
        Column(
            modifier = modifier.fillMaxSize()
        ) {
            Spacer(Modifier.height(8.dp))

            // Шапка: стрелка слева, заголовок по центру
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp)
            ) {
                IconButton(
                    onClick = onBackClick,
                    modifier = Modifier.align(Alignment.CenterStart)
                ) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "Назад",
                        tint = Color.White
                    )
                }
            }

            Text(
                text = title,
                color = Color.White,
                fontFamily = AuthSerif,
                fontSize = 22.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
            )

            Spacer(Modifier.height(20.dp))

            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(start = 20.dp, end = 20.dp, bottom = 24.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                items(builds, key = { it.id }) { build ->
                    BuildCard(
                        build = build,
                        onOpen = { onOpenInConfigurator(build) }
                    )
                }
            }
        }
    }
}

// ---------- Карточка сборки ----------

@Composable
private fun BuildCard(
    build: BuildItem,
    onOpen: () -> Unit,
) {
    val shape = RoundedCornerShape(4.dp)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(DarkPanel)
            .border(1.dp, CardBorder, shape)
            .padding(start = 10.dp, end = 10.dp, top = 10.dp, bottom = 6.dp)
    ) {
        Row(modifier = Modifier.fillMaxWidth()) {
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                BuildLine(build.cpu)
                BuildLine(build.motherboard)
                BuildLine(build.gpu)
                BuildLine(build.ram)
                BuildLine(build.storage)
            }

            Spacer(Modifier.width(8.dp))

            // Превью процессора справа сверху
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(RoundedCornerShape(4.dp))
                    .background(DarkButton)
                    .border(1.dp, Color(0xFF555555), RoundedCornerShape(4.dp)),
                contentAlignment = Alignment.Center
            ) {
                Image(
                    painter = painterResource(build.previewRes),
                    contentDescription = null,
                    modifier = Modifier.size(32.dp),
                    contentScale = ContentScale.Fit
                )
            }
        }

        Spacer(Modifier.height(6.dp))

        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            if (build.rating != null) {
                RatingStars(build.rating)
                Spacer(Modifier.width(10.dp))
                Text(
                    text = build.rating.toString(),
                    color = Color.White,
                    fontFamily = AuthSerif,
                    fontSize = 9.sp
                )
            }

            Text(
                text = "Открыть в конфигураторе",
                color = LightBorder,
                fontFamily = AuthSerif,
                fontSize = 9.sp,
                textAlign = TextAlign.End,
                modifier = Modifier
                    .weight(1f)
                    .clickable(onClick = onOpen)
                    .padding(vertical = 2.dp)
            )
        }
    }
}

@Composable
private fun BuildLine(text: String) {
    Text(
        text = text,
        color = Color.White,
        fontFamily = AuthSerif,
        fontSize = 9.sp,
        maxLines = 1
    )
}

@Composable
private fun RatingStars(rating: Float) {
    val filled = floor(rating).toInt()
    Row(horizontalArrangement = Arrangement.spacedBy(1.dp)) {
        repeat(5) { index ->
            Icon(
                imageVector = Icons.Default.Star,
                contentDescription = null,
                tint = if (index < filled) StarGold else Color(0xFF555555),
                modifier = Modifier.size(11.dp)
            )
        }
    }
}

// ---------- Preview ----------

@Preview(showBackground = true, showSystemUi = true)
@Composable
fun UsersBuildsScreenPreview() {
    UsersBuildsScreen()
}

@Preview(showBackground = true, showSystemUi = true)
@Composable
fun MyBuildsScreenPreview() {
    MyBuildsScreen()
}
