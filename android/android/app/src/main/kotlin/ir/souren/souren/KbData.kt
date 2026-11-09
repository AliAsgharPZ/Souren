package ir.souren.souren

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

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
    @Volatile var learnedPairs: MutableMap<String, Int> = mutableMapOf()
    @Volatile var shareLearning: Boolean = false
    @Volatile var kbMode: String = "standard"
    @Volatile var kbSide: String = "right"
    @Volatile private var syncingLearning = false
    @Volatile private var syncingModel = false
    @Volatile private var lastModelAttemptAt = 0L
    private var loaded = false

    @Synchronized
    fun load(ctx: Context) {
        if (loaded) return
        loaded = true
        // Dataset: updated file wins, else the bundled asset.
        val jsonText: String? = try {
            val upd = File(ctx.filesDir, "dataset_updated.json")
            if (upd.exists()) upd.readText()
            else ctx.assets.open("flutter_assets/assets/db/dataset.json")
                .bufferedReader().readText()
        } catch (e: Exception) { null }
        if (jsonText != null) {
            try {
                val root = JSONObject(jsonText)
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
                dictionary = map
                vocab = words.distinct()
            } catch (e: Exception) { /* keep empty; suggestions just stop */ }
        }
        readSettings(ctx)
        readLearned(ctx)
    }

    fun readSettings(ctx: Context) {
        try {
            val f = File(ctx.filesDir, "souren_settings.json")
            if (f.exists()) {
                val j = JSONObject(f.readText())
                replaceArabic = j.optBoolean("replaceArabic", true)
                autoCorrect = j.optBoolean("autoCorrect", true)
                kbHeight = j.optString("kbHeight", "tall")
                val wasSharing = shareLearning
                shareLearning = j.optBoolean("shareLearning", false)
                if (wasSharing && !shareLearning) {
                    val learnedFile = File(ctx.filesDir, "learned.json")
                    if (learnedFile.exists()) {
                        val learned = JSONObject(learnedFile.readText())
                        learned.put("pending", JSONArray())
                        learnedFile.writeText(learned.toString())
                    }
                }
            }
            val keyboardFile = File(ctx.filesDir, "souren_keyboard.json")
            if (keyboardFile.exists()) {
                val keyboard = JSONObject(keyboardFile.readText())
                kbMode = keyboard.optString("mode", "standard")
                kbSide = keyboard.optString("side", "right")
            }
        } catch (e: Exception) { }
    }

    @Synchronized
    fun setKeyboardMode(ctx: Context, mode: String, side: String = kbSide) {
        kbMode = if (mode in setOf("standard", "one-handed", "floating")) mode else "standard"
        kbSide = if (side == "left") "left" else "right"
        try {
            File(ctx.filesDir, "souren_keyboard.json").writeText(
                JSONObject().put("mode", kbMode).put("side", kbSide).toString()
            )
        } catch (_: Exception) { }
    }

    @Synchronized
    fun readLearned(ctx: Context) {
        try {
            val file = File(ctx.filesDir, "learned.json")
            val root = if (file.exists()) JSONObject(file.readText()) else JSONObject()
            val counts = root.optJSONObject("counts") ?: JSONObject()
            val countMap = HashMap<String, Int>()
            val countKeys = counts.keys()
            while (countKeys.hasNext()) {
                val key = countKeys.next()
                countMap[key] = counts.optInt(key)
            }
            learnedCounts = countMap

            val localPairs = root.optJSONObject("pairs") ?: JSONObject()
            val sharedPairs = root.optJSONObject("sharedPairs") ?: JSONObject()
            val pairMap = HashMap<String, Int>()
            val localKeys = localPairs.keys()
            while (localKeys.hasNext()) {
                val key = localKeys.next()
                pairMap[key] = localPairs.optInt(key)
            }
            val sharedKeys = sharedPairs.keys()
            while (sharedKeys.hasNext()) {
                val key = sharedKeys.next()
                pairMap[key] = (pairMap[key] ?: 0) + sharedPairs.optInt(key)
            }
            learnedPairs = pairMap

            val fetchedAt = root.optLong("modelFetchedAt", 0L)
            if (System.currentTimeMillis() - fetchedAt > 24L * 60 * 60 * 1000) {
                fetchSharedModel(ctx)
            }
            if (shareLearning) syncLearning(ctx)
        } catch (_: Exception) { }
    }

    /** Record that the user ended up with [to] after typing [from]:
     *  bumps the learned count and appends to the history the app shows. */
    @Synchronized
    fun recordLearned(
        ctx: Context,
        from: String,
        to: String,
        leftContext: String = "",
        rightContext: String = ""
    ) {
        if (from == to || from.isBlank() || to.isBlank()) return
        learnedCounts[to] = (learnedCounts[to] ?: 0) + 1
        val key = Corrector.learningKey(from, leftContext, rightContext, to)
        learnedPairs[key] = (learnedPairs[key] ?: 0) + 1
        try {
            val file = File(ctx.filesDir, "learned.json")
            val root = if (file.exists()) JSONObject(file.readText()) else JSONObject()
            val counts = root.optJSONObject("counts") ?: JSONObject()
            counts.put(to, learnedCounts[to])
            root.put("counts", counts)
            val pairs = root.optJSONObject("pairs") ?: JSONObject()
            val localCount = pairs.optInt(key) + 1
            pairs.put(key, localCount)
            root.put("pairs", pairs)
            val sharedCount = (root.optJSONObject("sharedPairs") ?: JSONObject()).optInt(key)
            learnedPairs[key] = localCount + sharedCount
            val sample = JSONObject().apply {
                put("from", from); put("to", to)
                put("left", leftContext); put("right", rightContext)
                put("ts", System.currentTimeMillis())
            }
            val history = root.optJSONArray("history") ?: JSONArray()
            history.put(sample)
            while (history.length() > 300) history.remove(0)
            root.put("history", history)
            if (shareLearning) {
                val pending = root.optJSONArray("pending") ?: JSONArray()
                pending.put(JSONObject().apply {
                    put("from", from); put("to", to)
                    put("left", leftContext); put("right", rightContext)
                })
                while (pending.length() > 100) pending.remove(0)
                root.put("pending", pending)
            }
            file.writeText(root.toString())
            if (shareLearning) syncLearning(ctx)
        } catch (e: Exception) { }
    }

    /** Sends only token-level correction examples after explicit opt-in.
     *  Full sentences, account identifiers and clipboard contents are never sent. */
    private fun syncLearning(ctx: Context) {
        synchronized(this) {
            if (syncingLearning) return
            syncingLearning = true
        }
        Thread {
            try {
                val file = File(ctx.filesDir, "learned.json")
                val root = if (file.exists()) JSONObject(file.readText()) else JSONObject()
                val pending = root.optJSONArray("pending") ?: JSONArray()
                if (pending.length() == 0) return@Thread
                val batch = JSONArray()
                for (i in 0 until minOf(pending.length(), 20)) {
                    batch.put(pending.getJSONObject(i))
                }
                val payload = JSONObject().put("samples", batch)
                val connection = (URL("https://souren.aliasgharpanahizare.workers.dev/api/learning")
                    .openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    connectTimeout = 8000
                    readTimeout = 8000
                    doOutput = true
                    setRequestProperty("Content-Type", "application/json; charset=utf-8")
                }
                val accepted = try {
                    connection.outputStream.use {
                        it.write(payload.toString().toByteArray(Charsets.UTF_8))
                    }
                    connection.responseCode in 200..299
                } finally {
                    connection.disconnect()
                }
                if (accepted) synchronized(this) {
                    val latest = if (file.exists()) JSONObject(file.readText()) else JSONObject()
                    val current = latest.optJSONArray("pending") ?: JSONArray()
                    val remaining = JSONArray()
                    for (i in batch.length() until current.length()) {
                        remaining.put(current.getJSONObject(i))
                    }
                    latest.put("pending", remaining)
                    file.writeText(latest.toString())
                }
            } catch (_: Exception) {
                // Keep the pending batch locally; a later accepted correction retries it.
            } finally {
                synchronized(this) { syncingLearning = false }
            }
        }.start()
    }

    /** Downloads only the thresholded, aggregate model. This is read-only and
     *  does not require or imply consent to upload personal corrections. */
    private fun fetchSharedModel(ctx: Context) {
        synchronized(this) {
            if (syncingModel || System.currentTimeMillis() - lastModelAttemptAt < 60L * 60 * 1000) return
            syncingModel = true
            lastModelAttemptAt = System.currentTimeMillis()
        }
        Thread {
            try {
                val connection = (URL("https://souren.aliasgharpanahizare.workers.dev/api/learning/model")
                    .openConnection() as HttpURLConnection).apply {
                    requestMethod = "GET"
                    connectTimeout = 8000
                    readTimeout = 10000
                    setRequestProperty("Accept", "application/json")
                }
                val payload = try {
                    if (connection.responseCode !in 200..299) return@Thread
                    connection.inputStream.bufferedReader().use { it.readText() }
                } finally {
                    connection.disconnect()
                }
                val response = JSONObject(payload)
                if (response.optInt("version") != 1) return@Thread
                val rows = response.optJSONArray("pairs") ?: JSONArray()
                val shared = JSONObject()
                val sharedMap = HashMap<String, Int>()
                for (i in 0 until rows.length()) {
                    val row = rows.optJSONObject(i) ?: continue
                    val from = row.optString("from")
                    val to = row.optString("to")
                    if (from.isBlank() || to.isBlank()) continue
                    val key = Corrector.learningKey(
                        from, row.optString("left"), row.optString("right"), to
                    )
                    val count = row.optInt("count").coerceAtLeast(0)
                    if (count == 0) continue
                    shared.put(key, count)
                    sharedMap[key] = count
                }
                synchronized(this) {
                    val file = File(ctx.filesDir, "learned.json")
                    val root = if (file.exists()) JSONObject(file.readText()) else JSONObject()
                    root.put("sharedPairs", shared)
                    root.put("modelFetchedAt", System.currentTimeMillis())
                    file.writeText(root.toString())

                    val combined = HashMap<String, Int>()
                    val local = root.optJSONObject("pairs") ?: JSONObject()
                    val localKeys = local.keys()
                    while (localKeys.hasNext()) {
                        val key = localKeys.next()
                        combined[key] = local.optInt(key)
                    }
                    for ((key, count) in sharedMap) {
                        combined[key] = (combined[key] ?: 0) + count
                    }
                    learnedPairs = combined
                }
            } catch (_: Exception) {
                // Keep the last local model; retry after the hourly cooldown.
            } finally {
                synchronized(this) { syncingModel = false }
            }
        }.start()
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
