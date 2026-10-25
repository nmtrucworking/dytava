package com.example.dytava.ui.theme

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color

// Brand Core Palette
val PrecisionBlue = Color(0xFF2663EB)
val MidnightNavy = Color(0xFF10243B)
val CanvasLight = Color(0xFFF5F8FD)
val CanvasDark = Color(0xFF0B1524)
val SurfaceLight = Color(0xFFFFFFFF)
val SurfaceDark = Color(0xFF14253B)
val OnSurfaceLight = Color(0xFF10243B)
val OnSurfaceDark = Color(0xFFEFF4FF)
val OutlineLight = Color(0xFFCAD5E5)
val OutlineDark = Color(0xFF657991)
val SubtleLight = Color(0xFFEDF2F9)
val SubtleDark = Color(0xFF203752)
val MutedLight = Color(0xFF5B6D86)
val MutedDark = Color(0xFFB1C0D2)

val PrimaryContainerLight = Color(0xFFDFE8FF)
val OnPrimaryContainerLight = Color(0xFF102C69)

val PrimaryDark = Color(0xFF9CB8FF)
val PrimaryContainerDark = Color(0xFF102C69)
val OnPrimaryContainerDark = Color(0xFFDFE8FF)

// DType Semantic Tokens
val DTypeString = Color(0xFF137A64)
val DTypeStringContainer = Color(0xFFDDF6EC)

val DTypeNumber = Color(0xFF235CD7)
val DTypeNumberContainer = Color(0xFFE6EEFF)

val DTypeDateTime = Color(0xFFA76B13)
val DTypeDateTimeContainer = Color(0xFFFFF0D0)

val DTypeBoolean = Color(0xFF764BBA)
val DTypeBooleanContainer = Color(0xFFF0E8FF)

val DTypeIdentifier = Color(0xFF50657D)
val DTypeIdentifierContainer = Color(0xFFE8EDF3)

val DTypeNull = Color(0xFF596573)
val DTypeNullContainer = Color(0xFFF0F1F3)

// Comparison State Tokens
val ComparisonExact = Color(0xFF137A64)
val ComparisonExactContainer = Color(0xFFDDF6ED)

val ComparisonEquivalent = Color(0xFF235CD7)
val ComparisonEquivalentContainer = Color(0xFFDFEAFE)

val ComparisonDifferent = Color(0xFFB42333)
val ComparisonDifferentContainer = Color(0xFFFDE7E9)

val ComparisonUnresolved = Color(0xFF925B0E)
val ComparisonUnresolvedContainer = Color(0xFFFFF0DA)

@Immutable
data class DytavaSemanticColors(
    // DType
    val stringText: Color = DTypeString,
    val stringContainer: Color = DTypeStringContainer,
    val numberText: Color = DTypeNumber,
    val numberContainer: Color = DTypeNumberContainer,
    val dateTimeText: Color = DTypeDateTime,
    val dateTimeContainer: Color = DTypeDateTimeContainer,
    val booleanText: Color = DTypeBoolean,
    val booleanContainer: Color = DTypeBooleanContainer,
    val identifierText: Color = DTypeIdentifier,
    val identifierContainer: Color = DTypeIdentifierContainer,
    val nullText: Color = DTypeNull,
    val nullContainer: Color = DTypeNullContainer,

    // Comparison
    val exactText: Color = ComparisonExact,
    val exactContainer: Color = ComparisonExactContainer,
    val equivalentText: Color = ComparisonEquivalent,
    val equivalentContainer: Color = ComparisonEquivalentContainer,
    val differentText: Color = ComparisonDifferent,
    val differentContainer: Color = ComparisonDifferentContainer,
    val unresolvedText: Color = ComparisonUnresolved,
    val unresolvedContainer: Color = ComparisonUnresolvedContainer,

    // Neutral
    val subtle: Color = SubtleLight,
    val muted: Color = MutedLight
)
