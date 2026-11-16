package ir.souren.souren

import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest

/** Validation and cache decisions for the keyboard's shared dataset file. */
object DatasetValidator {
    sealed class Result {
        data object Valid : Result()
        data class Invalid(val reason: String) : Result()
    }

    fun validate(text: String, strictFa: Boolean = false): Result {
        val root = try {
            JSONObject(text)
        } catch (e: Exception) {
            return Result.Invalid("not a JSON object: ${e.message}")
        }
        val entries = try {
            root.getJSONArray("entries")
        } catch (_: Exception) {
            return Result.Invalid("entries missing or not an array")
        }
        val version = root.opt("version")
        if (version != null) {
            val number = version as? Number
            if (number == null || number.toDouble() <= 0 ||
                number.toDouble() % 1.0 != 0.0
            ) return Result.Invalid("version must be a positive integer")
        }
        val seen = HashSet<String>()
        for (i in 0 until entries.length()) {
            val entry = entries.optJSONObject(i)
                ?: return Result.Invalid("entry ${i + 1} is not an object")
            val arabic = entry.opt("ar")
            if (arabic !is String || arabic.isBlank()) {
                return Result.Invalid("entry ${i + 1} has no Arabic word")
            }
            if (strictFa) {
                val meanings = entry.optJSONArray("fa")
                    ?: return Result.Invalid("entry '${arabic.trim()}' has no fa array")
                for (k in 0 until meanings.length()) {
                    if (meanings.opt(k) !is String) {
                        return Result.Invalid("entry '${arabic.trim()}' has a non-string meaning")
                    }
                }
            } else if (entry.has("fa") && entry.optJSONArray("fa") == null) {
                return Result.Invalid("entry '${arabic.trim()}' has a malformed fa field")
            }
            val key = arabic.trim()
            if (!seen.add(key)) return Result.Invalid("duplicate Arabic word: '$key'")
        }
        return Result.Valid
    }

    fun parse(text: String): Pair<Map<String, List<String>>, List<String>> {
        val root = JSONObject(text)
        val entries = root.getJSONArray("entries")
        val dictionary = HashMap<String, List<String>>()
        val words = ArrayList<String>()
        for (i in 0 until entries.length()) {
            val entry = entries.getJSONObject(i)
            val arabic = entry.getString("ar")
            words.add(arabic)
            val meanings = entry.optJSONArray("fa") ?: JSONArray()
            val translated = List(meanings.length()) { meanings.getString(it) }
            if (translated.isNotEmpty()) dictionary[arabic] = translated
            words.addAll(translated)
        }
        return dictionary to words.distinct()
    }

    enum class Source { KEEP, UPDATED, BUNDLED }

    fun signature(text: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(text.toByteArray(Charsets.UTF_8))
        val hex = digest.joinToString("") { "%02x".format(it.toInt() and 0xff) }
        return "u|sha256|$hex"
    }

    const val BUNDLED_SIG = "bundled"

    fun decide(
        updatedSig: String?,
        updatedValid: Boolean,
        loadedSig: String?,
        force: Boolean
    ): Source {
        if (updatedSig == null) {
            return if (!force && loadedSig == BUNDLED_SIG) Source.KEEP
            else Source.BUNDLED
        }
        if (updatedValid) {
            return if (!force && updatedSig == loadedSig) Source.KEEP
            else Source.UPDATED
        }
        return if (!force && loadedSig == BUNDLED_SIG) Source.KEEP
        else Source.BUNDLED
    }
}
