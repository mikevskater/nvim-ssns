---Fuzzy string matching utility for SSNS IntelliSense
---Used for matching column names across tables in JOIN suggestions
---@class FuzzyMatcher
local FuzzyMatcher = {}

---Normalize a string for comparison
---Converts to lowercase, removes underscores, and strips common prefixes
---@param s string The string to normalize
---@return string normalized The normalized string
function FuzzyMatcher.normalize(s)
  if not s then return "" end
  local result = s:lower()
  result = result:gsub("_", "")  -- Remove underscores
  result = result:gsub("^fk", "")  -- Remove FK prefix
  result = result:gsub("^pk", "")  -- Remove PK prefix
  return result
end

---Calculate Levenshtein distance between two strings
---@param s1 string First string
---@param s2 string Second string
---@return number distance The edit distance
local function levenshtein_distance(s1, s2)
  local len1, len2 = #s1, #s2

  -- Handle edge cases
  if len1 == 0 then return len2 end
  if len2 == 0 then return len1 end
  if s1 == s2 then return 0 end

  -- Create distance matrix
  local matrix = {}
  for i = 0, len1 do
    matrix[i] = { [0] = i }
  end
  for j = 0, len2 do
    matrix[0][j] = j
  end

  -- Fill in the matrix
  for i = 1, len1 do
    for j = 1, len2 do
      local cost = (s1:sub(i, i) == s2:sub(j, j)) and 0 or 1
      matrix[i][j] = math.min(
        matrix[i - 1][j] + 1,       -- deletion
        matrix[i][j - 1] + 1,       -- insertion
        matrix[i - 1][j - 1] + cost -- substitution
      )
    end
  end

  return matrix[len1][len2]
end

---Calculate similarity score between two strings (0.0 to 1.0)
---1.0 means identical (after normalization), 0.0 means completely different
---@param s1 string First string
---@param s2 string Second string
---@return number score Similarity score between 0 and 1
function FuzzyMatcher.similarity(s1, s2)
  if not s1 or not s2 then return 0 end

  -- Normalize both strings
  local norm1 = FuzzyMatcher.normalize(s1)
  local norm2 = FuzzyMatcher.normalize(s2)

  -- Empty strings after normalization
  if #norm1 == 0 or #norm2 == 0 then
    return (#norm1 == #norm2) and 1.0 or 0.0
  end

  -- Identical after normalization = perfect match
  if norm1 == norm2 then
    return 1.0
  end

  -- Calculate Levenshtein distance
  local distance = levenshtein_distance(norm1, norm2)
  local max_len = math.max(#norm1, #norm2)

  -- Convert distance to similarity (0 distance = 1.0 similarity)
  return 1.0 - (distance / max_len)
end

---Check if two strings are a fuzzy match above a threshold
---@param s1 string First string
---@param s2 string Second string
---@param threshold number? Minimum similarity score (default 0.85)
---@return boolean is_match True if similarity >= threshold
---@return number score The actual similarity score
function FuzzyMatcher.is_match(s1, s2, threshold)
  threshold = threshold or 0.85
  local score = FuzzyMatcher.similarity(s1, s2)
  return score >= threshold, score
end

---Find all fuzzy matches for a string in a list
---@param needle string The string to match
---@param haystack string[] List of strings to search
---@param threshold number? Minimum similarity score (default 0.85)
---@return table[] matches Array of {value, score} sorted by score descending
function FuzzyMatcher.find_matches(needle, haystack, threshold)
  threshold = threshold or 0.85
  local matches = {}

  for _, value in ipairs(haystack) do
    local score = FuzzyMatcher.similarity(needle, value)
    if score >= threshold then
      table.insert(matches, {
        value = value,
        score = score,
      })
    end
  end

  -- Sort by score descending
  table.sort(matches, function(a, b)
    return a.score > b.score
  end)

  return matches
end

---Compare column names for JOIN matching
---Special handling for common column naming patterns
---@param col1_name string First column name
---@param col2_name string Second column name
---@param threshold number? Minimum similarity score (default 0.85)
---@return boolean is_match True if columns likely refer to same concept
---@return number score The similarity score
function FuzzyMatcher.match_columns(col1_name, col2_name, threshold)
  threshold = threshold or 0.85

  -- First check: exact match (case-insensitive)
  if col1_name:lower() == col2_name:lower() then
    return true, 1.0
  end

  -- Second check: normalized match (handles Employee_ID vs EmployeeId)
  local norm1 = FuzzyMatcher.normalize(col1_name)
  local norm2 = FuzzyMatcher.normalize(col2_name)

  if norm1 == norm2 then
    return true, 1.0
  end

  -- Third check: fuzzy match
  local score = FuzzyMatcher.similarity(col1_name, col2_name)
  return score >= threshold, score
end

return FuzzyMatcher
