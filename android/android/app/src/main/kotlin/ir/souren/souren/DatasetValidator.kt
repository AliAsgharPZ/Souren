package ir.souren.souren

import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest

/** Dataset validation + reload decisions shared by the dictionary app
 *  and the keyboard (owner B2/B6).
 *
 *  All functions are pure (org.json only, no Android framework classes)
 *  so they run in plain JVM unit tests.
 */
object DatasetValidator {

    sealed class Result {
        data object Valid : Result()
        data class Invalid(val reason: String) : Result()
    }

    /** Strict parse of a dataset JSON text. Mirrors the Dart
     *  validateDatasetText/validateDatasetMap in lib/data/store.dart:
     *  top-level object, `entries` array, every entry needs a non-empty
     *  `ar` string, `fa` (when present) must be an array of strings,
     *  and duplicate Arabic keys are rejected. */
    fun validate(text: String, strictFa: Boolean = false): Result {
        val root = try {
            JSONObject(text)
        } catch (e: Exception) {
            return Result.Invalid("not a JSON object: ${e.message}")
        }
        val arr = try {
            root.getJSONArray("entries")
        } catch (e: Exception) {
            return Result.Invalid("entries missing or not an array")
        }
        val version = root.opt("version")
        if (version != null) {
            val v = version as? Number
            if (v == null || v.toDouble() <= 0 || v.toDouble() % 1.0 != 0.0) {
                return Result.Invalid("version must be a positive integer")
            }
        }
        val seen = HashSet<String>()
        for (i in 0 until arr.length()) {
            val entry = arr.optJSONObject(i)
                ?: return Result.Invalid("entry ${i + 1} is not an object")
            val ar = entry.opt("ar")
            if (ar !is String || ar.isBlank()) {
                return Result.Invalid("entry ${i + 1} has no Arabic word")
            }
            if (strictFa) {
                val fa = entry.optJSONArray("fa")
                    ?: return Result.Invalid("entry '${ar.trim()}' has no fa array")
                for (k in 0 until fa.length()) {
                    if (fa.opt(k) !is String) {
                        return Result.Invalid("entry '${ar.trim()}' has a non-string meaning")
                    }
                }
            } else if (entry.has("fa") && entry.optJSONArray("fa") == null) {
                return Result.Invalid("entry '${ar.trim()}' has a malformed fa field")
            }
            val key = ar.trim()
            if (!seen.add(key)) {
                return Result.Invalid("duplicate Arabic word: '$key'")
            }
        }
        return Result.Valid
    }

    /** Parses a validated dataset into (dictionary, vocab). */
    fun parse(text: String): Pair<Map<String, List<String>>, List<String>> {
        val root = JSONObject(text)
        val arr = root.getJSONArray("entries")
        val map = HashMap<String, List<String>>()
        val words = ArrayList<String>()
        for (i in 0 until arr.length()) {
            val e = arr.getJSONObject(i)
            val ar = e.getString("ar")
            words.add(ar)
            val faArr = e.optJSONArray("fa") ?: JSONArray()
            val fa = List(faArr.length()) { faArr.getString(it) }
            if (fa.isNotEmpty()) map[ar] = fa
            for (f in fa) words.add(f)
        }
        return map to words.distinct()
    }

    enum class Source { KEEP, UPDATED, BUNDLED }

    /** Stable content signature for dataset_updated.json. Unlike
     *  mtime+length it detects same-size replacements and timestamp collisions. */
    fun signature(text: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(text.toByteArray(Charsets.UTF_8))
        val hex = digest.joinToString("") { byte -> "%02x".format(byte.toInt() and 0xff) }
        return "u|sha256|$hex"
    }

    /** The signature KbData assigns when the bundled asset is in memory. */
    const val BUNDLED_SIG = "bundled"

    /** Which dataset the keyboard should load now.
     *
     *  [updatedSig]   SHA-256 content signature of the updated file,
     *                 or null when it does not exist
     *  [updatedValid] whether that file passed [validate]
     *  [loadedSig]    signature of the dataset currently in memory
     *                 (BUNDLED_SIG when the asset was loaded), or null
     *                 when nothing is loaded yet
     *  [force]        an explicit reload request (import/update flow)
     *
     *  KEEP avoids unnecessary full reloads on every keystroke/input
     *  event; UPDATED only fires when the file is genuinely new.
     */
    fun decide(
        updatedSig: String?,
        updatedValid: Boolean,
        loadedSig: String?,
        force: Boolean
    ): Source {
        // Nothing on disk: the bundled asset is the only source.
        if (updatedSig == null) {
            // If an updated file was removed, stop serving its old in-memory
            // copy and return to the bundled dataset.
            return if (!force && loadedSig == BUNDLED_SIG) Source.KEEP
            else Source.BUNDLED
        }
        // A valid updated file becomes active only when it is new
        // (signature changed) or a reload was explicitly requested.
        if (updatedValid) {
            return if (!force && updatedSig == loadedSig) Source.KEEP
            else Source.UPDATED
        }
        // Corrupt/invalid updated file: fall back to the bundled asset
        // so the keyboard keeps working (owner B2).
        return if (!force && loadedSig == BUNDLED_SIG) Source.KEEP
        else Source.BUNDLED
    }
}
