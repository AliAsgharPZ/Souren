package ir.ario.shell

import ir.souren.souren.MainActivity

/**
 * Ario is a first-class launcher Activity inside the Souren package.
 * It owns a dedicated Android task and Flutter engine/entrypoint.
 */
class ArioActivity : MainActivity() {
    override fun getDartEntrypointFunctionName(): String = "arioMain"
}
