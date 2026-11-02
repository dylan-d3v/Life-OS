import 'dart:math' as math;

/// Resultado de una coincidencia de resolución semántica local.
class EntityMatchResult<T> {
  final T item;
  final double score; // 0.0 a 100.0
  final String matchedTitle;

  const EntityMatchResult({
    required this.item,
    required this.score,
    required this.matchedTitle,
  });

  bool get isHighConfidence => score >= 60.0;
}

/// Motor de Resolución Semántica Local (Zero-Knowledge / In-Memory).
///
/// Permite a Kev localizar con alta precisión qué registro de la base de datos
/// (tarea, nota, evento, proyecto) desea modificar o eliminar el usuario,
/// basándose exclusivamente en el término o frase en lenguaje natural (`query`)
/// sin exponer la base de datos completa al LLM.
class LocalEntityResolver {
  const LocalEntityResolver._();

  static const double defaultMinScore = 40.0;

  static const Set<String> _spanishStopWords = {
    'el',
    'la',
    'los',
    'las',
    'un',
    'una',
    'unos',
    'unas',
    'de',
    'del',
    'a',
    'al',
    'en',
    'para',
    'por',
    'con',
    'mi',
    'mis',
    'tu',
    'tus',
    'su',
    'sus',
    'que',
    'y',
    'o',
  };

  /// Normaliza una cadena de texto para comparación insensible:
  /// - Convierte a minúsculas
  /// - Elimina acentos/diacríticos (á -> a, é -> e, etc.)
  /// - Remueve signos de puntuación y espacios redundantes
  static String normalize(String text) {
    if (text.isEmpty) return '';

    var result = text.toLowerCase().trim();

    // Reemplazo de tildes y caracteres diacríticos comunes en español
    const withDiacritics = 'áéíóúÁÉÍÓÚüÜñÑ';
    const withoutDiacritics = 'aeiouaeiouuunn';

    for (var i = 0; i < withDiacritics.length; i++) {
      result = result.replaceAll(withDiacritics[i], withoutDiacritics[i]);
    }

    // Remover caracteres de puntuación y especiales
    result = result.replaceAll(RegExp(r'[^\w\s]'), ' ');

    // Colapsar espacios múltiples
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();

    return result;
  }

  /// Divide una cadena en lista de palabras clave (tokens), descartando palabras vacías comunes.
  static List<String> tokenize(String text) {
    final normalized = normalize(text);
    if (normalized.isEmpty) return const [];

    return normalized
        .split(' ')
        .where((token) => token.isNotEmpty && !_spanishStopWords.contains(token))
        .toList();
  }

  /// Calcula la distancia de Levenshtein entre dos cadenas para medir similitud tipográfica.
  static int levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final len1 = s1.length;
    final len2 = s2.length;

    var v0 = List<int>.generate(len2 + 1, (i) => i);
    var v1 = List<int>.filled(len2 + 1, 0);

    for (var i = 0; i < len1; i++) {
      v1[0] = i + 1;

      for (var j = 0; j < len2; j++) {
        final cost = s1[i] == s2[j] ? 0 : 1;
        v1[j + 1] = math.min(
          v1[j] + 1,
          math.min(v0[j + 1] + 1, v0[j] + cost),
        );
      }

      final temp = v0;
      v0 = v1;
      v1 = temp;
    }

    return v0[len2];
  }

  /// Calcula el puntaje de coincidencia (0.0 a 100.0) entre la consulta y el título de un ítem.
  static double computeScore(String query, String targetTitle) {
    final normQuery = normalize(query);
    final normTitle = normalize(targetTitle);

    if (normQuery.isEmpty || normTitle.isEmpty) return 0.0;

    // 1. Coincidencia Exacta (100 puntos)
    if (normQuery == normTitle) {
      return 100.0;
    }

    // 2. Coincidencia por Prefijo (85 puntos)
    if (normTitle.startsWith(normQuery)) {
      return 85.0;
    }
    if (normQuery.startsWith(normTitle) && normTitle.length >= 3) {
      return 82.0;
    }

    // 3. Contención de Subcadena (70 puntos)
    if (normTitle.contains(normQuery)) {
      return 70.0;
    }
    if (normQuery.contains(normTitle) && normTitle.length >= 4) {
      return 68.0;
    }

    // 4. Intersección de Palabras Clave (Token Overlap) (40 - 65 puntos)
    final queryTokens = tokenize(normQuery);
    final titleTokens = tokenize(normTitle);

    if (queryTokens.isNotEmpty && titleTokens.isNotEmpty) {
      final titleSet = titleTokens.toSet();
      int matches = 0;

      for (final qToken in queryTokens) {
        if (titleSet.contains(qToken)) {
          matches++;
        } else {
          // Coincidencia difusa parcial por token si hay error leve
          final fuzzyMatch = titleTokens.any((tToken) {
            if (qToken.length >= 4 && tToken.length >= 4) {
              return levenshteinDistance(qToken, tToken) <= 1;
            }
            return false;
          });
          if (fuzzyMatch) matches++;
        }
      }

      if (matches > 0) {
        final queryCoverage = matches / queryTokens.length;
        final titleCoverage = matches / titleTokens.length;
        // Pondera fuertemente qué porcentaje de la consulta del usuario se cumplió
        final harmonicMean = (2 * queryCoverage * titleCoverage) /
            (queryCoverage + titleCoverage);
        final score = 40.0 + (harmonicMean * 25.0);
        return score.clamp(0.0, 65.0);
      }
    }

    // 5. Coincidencia Difusa Global por Levenshtein (para errores tipográficos)
    final maxLen = math.max(normQuery.length, normTitle.length);
    final distance = levenshteinDistance(normQuery, normTitle);
    final similarity = 1.0 - (distance / maxLen);

    if (similarity >= 0.75) {
      return (similarity * 60.0).clamp(0.0, 60.0);
    }

    return 0.0;
  }

  /// Encuentra el mejor elemento coincidente en [items] para la consulta [query].
  ///
  /// Retorna `null` si ninguna coincidencia supera [minScore] (por defecto 40.0).
  static T? findBestMatch<T>({
    required String query,
    required List<T> items,
    required String Function(T item) titleExtractor,
    double minScore = defaultMinScore,
  }) {
    if (items.isEmpty || query.trim().isEmpty) return null;

    T? bestItem;
    double bestScore = -1.0;

    for (final item in items) {
      final title = titleExtractor(item);
      final score = computeScore(query, title);

      if (score > bestScore) {
        bestScore = score;
        bestItem = item;
      }
    }

    if (bestScore >= minScore) {
      return bestItem;
    }

    return null;
  }

  /// Clasifica y ordena todos los elementos coincidentes de mayor a menor puntaje.
  static List<EntityMatchResult<T>> rankMatches<T>({
    required String query,
    required List<T> items,
    required String Function(T item) titleExtractor,
    double minScore = defaultMinScore,
  }) {
    if (items.isEmpty || query.trim().isEmpty) return const [];

    final results = <EntityMatchResult<T>>[];

    for (final item in items) {
      final title = titleExtractor(item);
      final score = computeScore(query, title);

      if (score >= minScore) {
        results.add(EntityMatchResult(
          item: item,
          score: score,
          matchedTitle: title,
        ));
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }
}

