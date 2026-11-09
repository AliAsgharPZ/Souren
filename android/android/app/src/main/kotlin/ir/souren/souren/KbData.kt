package ir.souren.souren

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/** Data shared between the dictionary app and this keyboard: same
 *  package, same filesDir. The app writes settings + dataset updates;
 *  the keyboard writes what it learns. Nothing leaves the device. */
object KbData {
    @Volatile var dictionary: Map<String, List<String>> = emptyMap()
    @Volatile var vocab: List<String> = emptyList()
    @Volatile var replaceArabic: Boolean = true
    @Volatile var autoCorrect: Boolean = true
    @Volatile var kbHeight: String = "tall"
    @Volatile var learnedCounts: MutableMap<String, Int> = mutableMapOf()

    /** Signature of the dataset currently in memory: "lastModified|length"
     *  of the updated file, or DatasetValidator.BUNDLED_SIG for the asset.
     *  Null when nothing was parsed successfully yet. */
    @Volatile private var datasetSig: String? = null

    /** Loads data for a fresh input session. Cheap when nothing changed:
     *  the dataset is only re-parsed when the updated file's signature
     *  differs from what is in memory (owner B2 — no reload per
     *  keystroke, no permanent cache either). */
    @Synchronized
    fun load(ctx: Context) {
        refreshDataset(ctx, force = false)
        readSettings(ctx)
        readLearned(ctx)
    }

    /** Forces a dataset reload (the app imported/downloaded a new
     *  dataset and wants the running keyboard to see it without an
     *  app-process restart). */
    @Synchronized
    fun reload(ctx: Context) {
        refreshDataset(ctx, force = true)
    }

    /** The only place the dataset is parsed. A source is loaded ONLY
     *  after a successful parse; an invalid dataset_updated.json falls
     *  back to the bundled asset. */
    @Synchronized
    private fun refreshDataset(ctx: Context, force: Boolean) {
        val upd = File(ctx.filesDir, "dataset_updated.json")
        val updatedExists = upd.exists()
        // Read once: validation and parsing must see the same file snapshot.
        val updatedText = if (updatedExists) {
            try { upd.readText() } catch (_: Exception) { null }
        } else null
        val updatedSig = when {
            !updatedExists -> null
            updatedText != null -> DatasetValidator.signature(updatedText)
            else -> "u|unreadable|${upd.lastModified()}|${upd.length()}"
        }
        // An identical snapshot was validated before; avoid reparsing its
        // JSON on every new input session.
        val updatedValid = updatedText != null && (
            (!force && updatedSig == datasetSig) ||
                DatasetValidator.validate(updatedText, strictFa = true) is DatasetValidator.Result.Valid
            )
        when (DatasetValidator.decide(updatedSig, updatedValid, datasetSig, force)) {
            DatasetValidator.Source.KEEP -> return
            DatasetValidator.Source.UPDATED -> {
                val parsed = updatedText?.let { tryParse(it) }
                if (parsed != null) {
                    apply(parsed.first, parsed.second, updatedSig!!)
                    return
                }
                // Defensive fallback if the validated snapshot cannot parse.
                applyBundled(ctx)
            }
            DatasetValidator.Source.BUNDLED -> applyBundled(ctx)
        }
    }

    private fun tryParse(text: String): Pair<Map<String, List<String>>, List<String>>? =
        try { DatasetValidator.parse(text) } catch (e: Exception) { null }

    private fun apply(map: Map<String, List<String>>, words: List<String>, sig: String) {
        dictionary = map
        vocab = words
        datasetSig = sig
    }

    @Synchronized
    private fun applyBundled(ctx: Context) {
        try {
            val text = ctx.assets
                .open("flutter_assets/assets/db/dataset.json")
                .bufferedReader().readText()
            val parsed = tryParse(text)
            if (parsed != null) {
                apply(parsed.first, parsed.second, DatasetValidator.BUNDLED_SIG)
                return
            }
        } catch (e: Exception) { }
        // Nothing could be parsed — keep whatever valid data is already
        // in memory (a working dataset is never replaced by emptiness).
    }

    fun readSettings(ctx: Context) {
        try {
            val f = File(ctx.filesDir, "souren_settings.json")
            if (f.exists()) {
                val j = JSONObject(f.readText())
                replaceArabic = j.optBoolean("replaceArabic", true)
                autoCorrect = j.optBoolean("autoCorrect", true)
                kbHeight = j.optString("kbHeight", "tall")
            }
        } catch (e: Exception) { }
    }

    fun readLearned(ctx: Context) {
        try {
            val f = File(ctx.filesDir, "learned.json")
            if (f.exists()) {
                val j = JSONObject(f.readText())
                val counts = j.optJSONObject("counts") ?: JSONObject()
                val m = HashMap<String, Int>()
                val keys = counts.keys()
                while (keys.hasNext()) {
                    val k = keys.next()
                    m[k] = counts.optInt(k)
                }
                learnedCounts = m
            }
        } catch (e: Exception) { }
    }

    /** Record that the user ended up with [to] after typing [from]:
     *  bumps the learned count and appends to the history the app shows. */
    @Synchronized
    fun recordLearned(ctx: Context, from: String, to: String) {
        if (from == to || from.isBlank() || to.isBlank()) return
        learnedCounts[to] = (learnedCounts[to] ?: 0) + 1
        try {
            val file = File(ctx.filesDir, "learned.json")
            val root = if (file.exists()) JSONObject(file.readText()) else JSONObject()
            val counts = root.optJSONObject("counts") ?: JSONObject()
            counts.put(to, learnedCounts[to])
            root.put("counts", counts)
            val history = root.optJSONArray("history") ?: JSONArray()
            history.put(JSONObject().apply {
                put("from", from); put("to", to)
                put("ts", System.currentTimeMillis())
            })
            while (history.length() > 300) history.remove(0)
            root.put("history", history)
            file.writeText(root.toString())
        } catch (e: Exception) { }
    }

    // ---------------- clipboard panel store ----------------
    fun clipboardItems(ctx: Context): MutableList<Pair<String, Boolean>> {
        val out = mutableListOf<Pair<String, Boolean>>()
        try {
            val f = File(ctx.filesDir, "clipboard.json")
            if (f.exists()) {
                val arr = JSONObject(f.readText()).optJSONArray("items") ?: JSONArray()
                for (i in 0 until arr.length()) {
                    val o = arr.getJSONObject(i)
                    out.add(o.getString("text") to o.optBoolean("pinned"))
                }
            }
        } catch (e: Exception) { }
        return out
    }

    fun saveClipboardItems(ctx: Context, items: List<Pair<String, Boolean>>) {
        try {
            val arr = JSONArray()
            for ((t, p) in items.take(40)) {
                arr.put(JSONObject().apply { put("text", t); put("pinned", p) })
            }
            File(ctx.filesDir, "clipboard.json")
                .writeText(JSONObject().put("items", arr).toString())
        } catch (e: Exception) { }
    }

    fun rememberClipboard(ctx: Context, text: String) {
        if (text.isBlank()) return
        val items = clipboardItems(ctx)
        if (items.firstOrNull()?.first == text) return
        items.removeAll { it.first == text }
        items.add(0, text to false)
        saveClipboardItems(ctx, items)
    }

    // ---------------- keyboard-local state (SharedPreferences) ----------------
    private fun prefs(ctx: Context) =
        ctx.getSharedPreferences("souren_kb", Context.MODE_PRIVATE)

    /** The symbol the comma-side custom key currently shows/inserts
     *  (Samsung's custom key remembers the last picked symbol);
     *  kept separately for the Persian and English layouts. */
    fun customSymbol(ctx: Context, fa: Boolean): String =
        prefs(ctx).getString(if (fa) "custom_symbol_fa" else "custom_symbol_en",
            if (fa) "،" else ",") ?: if (fa) "،" else ","

    fun setCustomSymbol(ctx: Context, fa: Boolean, symbol: String) {
        prefs(ctx).edit()
            .putString(if (fa) "custom_symbol_fa" else "custom_symbol_en", symbol)
            .apply()
    }

    /** Recently used emojis, most recent first (max 32). */
    fun emojiRecents(ctx: Context): List<String> {
        val raw = prefs(ctx).getString("emoji_recents", "") ?: ""
        return if (raw.isEmpty()) emptyList() else raw.split('\u0001').filter { it.isNotEmpty() }
    }

    fun recordEmoji(ctx: Context, emoji: String) {
        val list = emojiRecents(ctx).toMutableList()
        list.remove(emoji)
        list.add(0, emoji)
        prefs(ctx).edit()
            .putString("emoji_recents", list.take(32).joinToString("\u0001"))
            .apply()
    }

}
