package com.example.dytava.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.dytava.R
import com.example.dytava.ui.theme.DytavaThemeTokens

enum class ComparisonState(val symbol: String, val label: String) {
    EXACT("✓", "EXACT"),
    EQUIVALENT("≈", "EQUIVALENT"),
    DIFFERENT("≠", "DIFFERENT"),
    UNRESOLVED("?", "UNRESOLVED")
}

enum class DTypeKind(val sign: String, val label: String) {
    STRING("Abc", "STRING"),
    NUMBER("123", "NUMBER"),
    DATETIME("◷", "DATETIME"),
    BOOLEAN("T/F", "BOOLEAN"),
    IDENTIFIER("ID", "IDENTIFIER"),
    NULL("∅", "NULL")
}

@Composable
fun DytavaLogoHeader(
    modifier: Modifier = Modifier,
    showTagline: Boolean = true
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center
        ) {
            Icon(
                painter = painterResource(id = R.drawable.ic_dytava_logo),
                contentDescription = "Dytava Symbol",
                modifier = Modifier
                    .size(48.dp)
                    .clip(RoundedCornerShape(12.dp)),
                tint = Color.Unspecified
            )
            Spacer(modifier = Modifier.width(12.dp))
            Text(
                text = "dytava",
                style = MaterialTheme.typography.displayLarge.copy(
                    fontSize = 36.sp,
                    fontWeight = FontWeight.ExtraBold,
                    letterSpacing = (-2).sp
                ),
                color = MaterialTheme.colorScheme.onBackground
            )
        }

        if (showTagline) {
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "Understand every difference.",
                style = MaterialTheme.typography.bodyMedium.copy(
                    fontWeight = FontWeight.Medium
                ),
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text(
                text = "Đối chiếu dữ liệu. Làm rõ khác biệt.",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
fun ComparisonChip(
    state: ComparisonState,
    modifier: Modifier = Modifier,
    count: Int? = null
) {
    val tokens = DytavaThemeTokens.semantic
    val (bg, textColor) = when (state) {
        ComparisonState.EXACT -> tokens.exactContainer to tokens.exactText
        ComparisonState.EQUIVALENT -> tokens.equivalentContainer to tokens.equivalentText
        ComparisonState.DIFFERENT -> tokens.differentContainer to tokens.differentText
        ComparisonState.UNRESOLVED -> tokens.unresolvedContainer to tokens.unresolvedText
    }

    val labelText = if (count != null) {
        "${state.symbol} $count ${state.label}"
    } else {
        "${state.symbol} ${state.label}"
    }

    Box(
        modifier = modifier
            .clip(RoundedCornerShape(50.dp))
            .background(bg)
            .padding(horizontal = 12.dp, vertical = 6.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = labelText,
            color = textColor,
            style = MaterialTheme.typography.labelMedium.copy(
                fontWeight = FontWeight.Bold
            )
        )
    }
}

@Composable
fun DTypeBadge(
    kind: DTypeKind,
    modifier: Modifier = Modifier
) {
    val tokens = DytavaThemeTokens.semantic
    val (bg, textColor) = when (kind) {
        DTypeKind.STRING -> tokens.stringContainer to tokens.stringText
        DTypeKind.NUMBER -> tokens.numberContainer to tokens.numberText
        DTypeKind.DATETIME -> tokens.dateTimeContainer to tokens.dateTimeText
        DTypeKind.BOOLEAN -> tokens.booleanContainer to tokens.booleanText
        DTypeKind.IDENTIFIER -> tokens.identifierContainer to tokens.identifierText
        DTypeKind.NULL -> tokens.nullContainer to tokens.nullText
    }

    Row(
        modifier = modifier
            .clip(RoundedCornerShape(6.dp))
            .background(bg)
            .padding(horizontal = 8.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text(
            text = kind.sign,
            color = textColor,
            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold)
        )
        Text(
            text = kind.label,
            color = textColor,
            style = MaterialTheme.typography.labelSmall
        )
    }
}
