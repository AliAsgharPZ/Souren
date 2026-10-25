package ir.souren.souren

/** Emoji catalogue for the keyboard's emoji panel, grouped the way the
 *  Samsung panel groups them: Smileys, People, Animals, Food, Travel,
 *  Activities, Objects, Symbols, Flags. Search keywords are English
 *  plus common Persian words for the most-used entries. */
object EmojiData {

    data class Category(val icon: String, val name: String, val items: List<String>)

    private fun e(s: String): List<String> = s.split(' ').filter { it.isNotEmpty() }

    val categories: List<Category> = listOf(
        Category("😀", "لبخندها", e(
            "😀 😃 😄 😁 😆 😅 🤣 😂 🙂 🙃 🫠 😉 😊 😇 🥰 😍 🤩 😘 😗 😚 😙 🥲 😋 😛 😜 🤪 😝 🤑 🤗 🤭 🫢 🫣 🤫 🤔 🫡 🤐 🤨 😐 😑 😶 🫥 😶‍🌫️ 😏 😒 🙄 😬 🤥 🫨 😌 😔 😪 🤤 😴 😷 🤒 🤕 🤢 🤮 🤧 🥵 🥶 🥴 😵 😵‍💫 🤯 🤠 🥳 🥸 😎 🤓 🧐 😕 🫤 😟 🙁 ☹️ 😮 😯 😲 😳 🥺 🥹 😦 😧 😨 😰 😥 😢 😭 😱 😖 😣 😞 😓 😩 😫 🥱 😤 😡 😠 🤬 😈 👿 💀 ☠️ 💩 🤡 👹 👺 👻 👽 👾 🤖"
        )),
        Category("🙂", "چهره و مردم", e(
            "👋 🤚 🖐️ ✋ 🖖 👌 🤌 🤏 ✌️ 🤞 🫰 🤟 🤘 🤙 👈 👉 👆 🖕 👇 ☝️ 👍 👎 ✊ 👊 🤛 🤜 👏 🙌 🫶 👐 🤲 🤝 🙏 ✍️ 💅 🤳 💪 🦾 🦿 🦵 🦶 👂 🦻 👃 🧠 🫀 🫁 🦷 🦴 👀 👁️ 👅 👄 🫦 👶 👧 🧒 👦 👩 🧑 👨 👱 👵 🧓 👴 👲 🧕 👳 👮 👷 💂 🕵️ 👩‍⚕️ 🧑‍⚕️ 👨‍⚕️ 👩‍🌾 🧑‍🌾 👨‍🌾 👩‍🍳 🧑‍🍳 👨‍🍳 👩‍🎓 🧑‍🎓 👨‍🎓 👩‍🏫 🧑‍🏫 👨‍🏫 👩‍⚖️ 🧑‍⚖️ 👨‍⚖️ 👩‍💻 🧑‍💻 👨‍💻 👩‍🎤 🧑‍🎤 👨‍🎤 👩‍🎨 🧑‍🎨 👨‍🎨 👩‍✈️ 🧑‍✈️ 👨‍✈️ 👩‍🚀 🧑‍🚀 👨‍🚀 🦸 🦹 🧙 🧚 🧛 🧜 🧝 🧞 🧟 💆 💇 🚶 🧍 🧎 🏃 💃 🕺 🕴️ 👯 👭 👫 👬 💏 💑 👪 👨‍👩‍👧 👨‍👩‍👧‍👦 👨‍👩‍👦‍👦 👨‍👩‍👧‍👧 👩‍👩‍👦 👩‍👩‍👧 👩‍👩‍👧‍👦 👩‍👩‍👦‍👦 👩‍👩‍👧‍👧 👨‍👨‍👦 👨‍👨‍👧 👨‍👨‍👧‍👦 👨‍👨‍👦‍👦 👨‍👨‍👧‍👧 👩‍👦 👩‍👧 👩‍👧‍👦 👩‍👦‍👦 👨‍👦 👨‍👧 👨‍👧‍👦 👨‍👦‍👦"
        )),
        Category("🐶", "جانوران و طبیعت", e(
            "🐶 🐱 🐭 🐹 🐰 🦊 🦝 🐻 🐼 🦩 🦤 🦢 🦜 🐢 🦎 🐙 🦑 🦐 🦞 🦀 🐡 🐠 🐟 🐬 🐳 🐋 🦈 🪼 🐊 🐅 🐆 🦓 🫏 🦍 🦧 🐘 🦛 🦏 🐪 🐫 🦒 🦘 🦬 🐃 🐂 🐄 🐎 🐖 🐏 🐑 🦙 🐐 🦌 🐕 🐩 🦮 🐕‍🦺 🐈 🐈‍⬛ 🪶 🐓 🦃 🕊️ 🦅 🦆 🦢 🦉 🦩 🦚 🦜 🐸 🐊 🐢 🦎 🐍 🐲 🐉 🦕 🦖 🐳 🐋 🐬 🐟 🐠 🐡 🦈 🐙 🐚 🪸 🪼 🦋 🐌 🐞 🐜 🪰 🪱 🐝 🪲 🐛 🦗 🕷️ 🕸️ 🦂 🦟 🪳 🌸 💮 🪷 🏵️ 🌹 🥀 🌺 🌻 🌼 🌷 🪻 🌱 🪴 🌲 🌳 🌴 🌵 🌾 🌿 ☘️ 🍀 🍁 🍂 🍃 🪹 🪺 🍄"
        )),
        Category("🍔", "خوراکی", e(
            "🍇 🍈 🍉 🍊 🍋 🍋‍🟩 🍌 🍍 🥭 🍎 🍏 🍐 🍑 🍒 🍓 🫐 🥝 🍅 🫒 🥥 🥑 🍆 🥔 🥕 🌽 🌶️ 🫑 🥒 🥬 🥦 🧄 🧅 🥜 🫘 🌰 🫚 🫛 🍄‍🟫 🍞 🥐 🥖 🫓 🥨 🥯 🥞 🧇 🧀 🍖 🍗 🥩 🥓 🍔 🍟 🍕 🌭 🥪 🌮 🌯 🫔 🥙 🧆 🥚 🍳 🥘 🍲 🫕 🥣 🥗 🍿 🧈 🧂 🥫 🍱 🍘 🍙 🍚 🍛 🍜 🍝 🍠 🍢 🍣 🍤 🍥 🥮 🍡 🥟 🥠 🥡 🦀 🦞 🦐 🦑 🦪 🍦 🍧 🍨 🍩 🍪 🎂 🍰 🧁 🥧 🍫 🍬 🍭 🍮 🍯 🍼 🥛 ☕ 🫖 🍵 🍶 🍾 🍷 🍸 🍹 🍺 🍻 🥂 🥃 🫗 🥤 🧋 🧃 🧉 🧊 🥢 🍽️ 🍴 🥄 🔪 🏺"
        )),
        Category("🚗", "سفر و مکان‌ها", e(
            "🚗 🚕 🚙 🚌 🚎 🏎️ 🚓 🚑 🚒 🚐 🛻 🚚 🚛 🚜 🦯 🦽 🦼 🛴 🚲 🛵 🏍️ 🛺 🚨 🚔 🚍 🚘 🚖 🛞 🚂 🚃 🚄 🚅 🚆 🚇 🚈 🚉 ✈️ 🛫 🛬 🛩️ 🪂 💺 🚁 🛸 🚀 🛶 ⛵ 🚤 🛥️ 🛳️ ⛴️ 🚢 ⚓ 🪝 ⛽ 🚧 🚦 🚥 🗺️ 🗿 🗽 🗼 🏰 🏯 🏟️ 🎡 🎢 🎠 ⛲ ⛱️ 🏖️ 🏝️ 🏜️ 🌋 ⛰️ 🏔️ 🗻 🏕️ 🏠 🏡 🏘️ 🏚️ 🏗️ 🏭 🏢 🏬 🏣 🏤 🏥 🏦 🏨 🏪 🏫 🏩 💒 🏛️ ⛪ 🕌 🕍 🛕 🕋 ⛩️ 🛤️ 🛣️ 🗾 🎑 🌅 🌄 🌠 🎇 🎆 🌇 🌆 🏙️ 🌃 🌌 🌉 🌁"
        )),
        Category("⚽", "فعالیت‌ها", e(
            "⚽ 🏀 🏈 ⚾ 🥎 🎾 🏐 🏉 🥏 🎱 🪀 🏓 🏸 🏒 🏑 🥍 🏏 ⛳ 🪁 🏹 🎣 🤿 🥊 🥋 🎽 🛹 ⛷️ 🏂 🪂 🏋️ 🤸 🤼 🤾 🏌️ 🏇 🧘 🏄 🏊 🚣 🧗 🚵 🚴 🏆 🥇 🥈 🥉 🏅 🎖️ 🏵️ 🎗️ 🎫 🎟️ 🎭 🎨 🎬 🎤 🎧 🎼 🎹 🥁 🪘 🎷 🎺 🪗 🎸 🪕 🎻 🎲 ♟️ 🎯 🎳 🎮 🎰 🧩 🏎️ 🏍️ 🎪 🎡 🎢 🎠 🎭 🖼️ 🎨 🧵 🪡 🧶"
        )),
        Category("💡", "اشیاء", e(
            "⌚ 📱 💻 ⌨️ 🖥️ 🖨️ 🖱️ 🕹️ 💾 💿 📀 📷 📸 📹 🎥 📞 ☎️ 📺 📻 🎙️ 🎚️ 🎛️ 🧭 ⏰ ⏱️ ⏲️ 🕰️ ⏳ ⌛ 🔋 🪫 🔌 💡 🔦 🕯️ 🪔 🧯 🛢️ 💸 💵 💴 💶 💷 💰 💳 🪙 💎 ⚖️ 🪜 🧰 🔧 🔨 ⚒️ 🛠️ ⛏️ 🔩 ⚙️ 🪤 🧱 ⛓️ 🧲 🔫 💣 🧨 🪓 🔪 🗡️ ⚔️ 🛡️ 🚬 ⚰️ 🪦 ⚱️ 🏺 🔮 📿 🧿 🪬 💈 ⚗️ 🔭 🔬 🕳️ 💊 💉 🩸 🧬 🦠 🧫 🧪 🌡️ 🧹 🪣 🧺 🧻 🚽 🚿 🛁 🛀 🧼 🪥 🪒 🧽 🪣 🗝️ 🔑 🔐 🔒 🔓 🛋️ 🛏️ 🛌 🧸 🪆 🖼️ 🪞 🪟 🛍️ 🛒 🎁 🎈 🎏 🎀 🪄 🪅 🎊 🎉 🎎 🏮 🎐 🧧 ✉️ 📩 📨 📧 💌 📥 📤 📦 🏷️ 📪 📫 📬 📭 📮 📜 📃 📄 📑 🧾 📊 📈 📉 🗒️ 🗓️ 📆 📅 🗑️ 📇 🗃️ 🗳️ 🗄️ 🗂️ 🔖 📌 📍 ✂️ 🖊️ 🖋️ ✒️ 🖌️ 🖍️ 📝 ✏️ 🔍 🔎 🔏 🔐 🔑"
        )),
        Category("❤️", "نمادها", e(
            "❤️ 🧡 💛 💚 💙 💜 🖤 🤍 🤎 💔 ❣️ 💕 💞 💓 💗 💖 💘 💝 💟 ☮️ ✝️ ☪️ 🕉️ ☸️ ✡️ 🔯 🕎 ☯️ ☦️ 🛐 ⛎ ♈ ♉ ♊ ♋ ♌ ♍ ♎ ♏ ♐ ♑ ♒ ♓ 🆔 ⚛️ 🉑 ☢️ ☣️ 📴 📳 🈶 🈚 🈸 🈺 🈷️ ✴️ 🆚 💮 🉐 ㊙️ ㊗️ 🈴 🈵 🈹 🈲 🅰️ 🅱️ 🆎 🆑 🅾️ 🆘 ❌ ⭕ 🛑 ⛔ 📛 🚫 💯 💢 ♨️ 🚷 🚯 🚳 🚱 🔞 📵 🚭 ❗ ❕ ❓ ❔ ‼️ ⁉️ 🔅 🔆 ⚠️ 🚸 🔱 ⚜️ 🔰 ♻️ ✅ 🈯 💹 ❇️ ✳️ ❎ 🌐 💠 Ⓜ️ 🌀 💤 🏧 🚾 ♿ 🅿️ 🛗 🈳 🈂️ 🛂 🛃 🛄 🛅 ⚕️ ♟️ 🚹 🚺 🚼 🚻 🚮 🎦 📶 📳 📴 0️⃣ 1️⃣ 2️⃣ 3️⃣ 4️⃣ 5️⃣ 6️⃣ 7️⃣ 8️⃣ 9️⃣ 🔟"
        )),
        Category("🏳️", "پرچم‌ها", e(
            "🏳️ 🏴 🏴‍☠️ 🏁 🚩 🎌 🇮🇷 🇹🇷 🇦🇪 🇸🇦 🇮🇶 🇦🇫 🇵🇰 🇮🇳 🇨🇳 🇯🇵 🇰🇷 🇬🇧 🇺🇸 🇫🇷 🇩🇪 🇮🇹 🇪🇸 🇵🇹 🇷🇺 🇺🇦 🇨🇦 🇧🇷 🇦🇷 🇲🇽 🇦🇺 🇪🇬 🇿🇦 🇳🇬 🇰🇪 🇲🇦 🇩🇿 🇹🇳 🇱🇾 🇸🇩 🇪🇹 🇸🇴 🇮🇩 🇲🇾 🇸🇬 🇹🇭 🇻🇳 🇵🇭 🇧🇩 🇱🇰 🇳🇵 🇲🇲 🇰🇭 🇱🇦 🇹🇼 🇭🇰 🇲🇳 🇰🇿 🇺🇿 🇹🇲 🇹🇯 🇰🇬 🇦🇿 🇬🇪 🇦🇲 🇧🇾 🇵🇱 🇳🇱 🇧🇪 🇨🇭 🇦🇹 🇨🇿 🇸🇰 🇭🇺 🇷🇴 🇧🇬 🇬🇷 🇸🇪 🇳🇴 🇩🇰 🇫🇮 🇮🇪 🇮🇸 🇪🇪 🇱🇻 🇱🇹 🇭🇷 🇷🇸 🇧🇦 🇲🇪 🇦🇱 🇲🇰 🇸🇮 🇲🇩 🇨🇾 🇲🇹 🇵🇸 🇱🇧 🇸🇾 🇯🇴 🇰🇼 🇶🇦 🇧🇭 🇴🇲 🇾🇪"
        )),
    )

    /** Emojis that take a skin-tone modifier on long-press. */
    val toneSet: Set<String> = setOf(
        "👋", "🤚", "🖐️", "✋", "🖖", "👌", "🤌", "🤏", "✌️", "🤞", "🫰", "🤟", "🤘", "🤙",
        "👈", "👉", "👆", "🖕", "👇", "☝️", "👍", "👎", "✊", "👊", "🤛", "🤜", "👏", "🙌",
        "🫶", "👐", "🤲", "🤝", "🙏", "✍️", "💅", "🤳", "💪", "👂", "🦻", "👃", "👶", "👧",
        "🧒", "👦", "👩", "🧑", "👨", "👱", "👵", "🧓", "👴", "👮", "👷", "💂", "🕵️", "💆", "💇",
        "🚶", "🧍", "🧎", "🏃", "💃", "🕺", "🏋️", "🤸", "🤾", "🏌️", "🏇", "🧘", "🏄", "🏊", "🚣", "🧗", "🚵", "🚴"
    )
    val tones: List<String> = listOf("🏻", "🏼", "🏽", "🏾", "🏿")

    /** Search keywords: English + a few Persian words for common items. */
    val keywords: Map<String, String> = mapOf(
        "😀" to "grin smile happy خنده لبخند", "😂" to "joy laugh tears خنده گریه",
        "🤣" to "rofl laugh خنده", "😍" to "heart eyes love عشق",
        "🥰" to "love hearts عشق محبت", "😘" to "kiss بوس", "😎" to "cool sunglasses عینک",
        "🤔" to "think فکر", "😴" to "sleep خواب", "😷" to "mask sick ماسک",
        "🥺" to "pleading cute", "😭" to "cry sob گریه", "😡" to "angry mad عصبانی",
        "🤯" to "mind blown explode", "🥳" to "party جشن", "👍" to "thumbs up ok like پسند",
        "👎" to "thumbs down dislike", "🙏" to "pray please thanks دعا خواهش",
        "👏" to "clap دست زدن تشویق", "💪" to "muscle strong قوی بازو",
        "👋" to "wave hi bye سلام خداحافظ", "❤️" to "heart love red قلب عشق",
        "💔" to "broken heart قلب شکسته", "🔥" to "fire hot آتش",
        "✨" to "sparkles star درخشش", "🎉" to "party tada جشن",
        "🎂" to "birthday cake کیک تولد", "🎁" to "gift present هدیه کادو",
        "⚽" to "football soccer فوتبال توپ", "🏀" to "basketball بسکتبال",
        "🚗" to "car automobile ماشین خودرو", "✈️" to "airplane flight هواپیما پرواز",
        "🏠" to "house home خانه", "📱" to "phone mobile گوشی موبایل",
        "💻" to "laptop computer رایانه لپ‌تاپ", "📷" to "camera دوربین",
        "☕" to "coffee قهوه", "🍵" to "tea چای", "🍕" to "pizza پیتزا",
        "🍔" to "burger hamburger همبرگر", "🍟" to "fries سیب‌زمینی",
        "🍎" to "apple سیب", "🍌" to "banana موز", "🍇" to "grapes انگور",
        "🍓" to "strawberry توت‌فرنگی", "🌹" to "rose flower گل رز",
        "🌸" to "blossom flower گل شکوفه", "☀️" to "sun sunny خورشید آفتاب",
        "🌙" to "moon night ماه شب", "⭐" to "star ستاره", "🌧️" to "rain باران",
        "❄️" to "snow winter برف زمستان", "🐶" to "dog سگ", "🐱" to "cat گربه",
        "🐴" to "horse اسب", "🐦" to "bird پرنده", "🦋" to "butterfly پروانه",
        "🐝" to "bee زنبور", "💰" to "money bag پول", "💎" to "gem diamond الماس",
        "⏰" to "alarm clock ساعت", "🔑" to "key کلید", "💡" to "idea bulb لامپ ایده",
        "📚" to "books کتاب", "✏️" to "pencil مداد", "🎵" to "music note موسیقی",
        "🎸" to "guitar گیتار", "⚽" to "football فوتبال", "🏆" to "trophy cup جام",
        "🥇" to "gold medal طلا مدال", "🚀" to "rocket موشک", "⚓" to "anchor لنگر",
        "🏖️" to "beach ساحل", "🎄" to "christmas tree درخت", "👻" to "ghost روح",
        "🤖" to "robot ربات", "👽" to "alien فضایی", "💀" to "skull جمجمه",
        "🐪" to "camel شتر", "🐘" to "elephant فیل", "🦁" to "lion شیر",
        "🐸" to "frog قورباغه", "🌶️" to "pepper فلفل", "🥕" to "carrot هویج",
        "🍿" to "popcorn پاپ‌کورن", "🥐" to "croissant کروسان", "🧀" to "cheese پنیر",
        "🍩" to "donut دونات", "🍦" to "ice cream بستنی", "🥛" to "milk شیر",
        "🍷" to "wine شراب", "🍺" to "beer آبجو", "🔪" to "knife چاقو",
        "🗡️" to "dagger خنجر", "🛡️" to "shield سپر", "⚔️" to "swords شمشیر",
        "🇮🇷" to "iran flag پرچم ایران"
    )

    fun search(query: String): List<String> {
        val q = query.trim().lowercase()
        if (q.isEmpty()) return emptyList()
        val out = LinkedHashSet<String>()
        for (c in categories) for (item in c.items) {
            val kw = keywords[item]
            if (kw != null && kw.lowercase().split(' ').any { it.contains(q) || q.contains(it) && it.length > 2 }) {
                out.add(item)
            }
        }
        return out.toList()
    }
}
