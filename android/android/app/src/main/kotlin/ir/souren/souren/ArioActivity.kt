package ir.souren.souren

/**
 * First-class Ario launcher Activity. It reuses the native host integrations
 * while starting an independent Flutter engine/Dart entrypoint and task.
 */
class ArioActivity : MainActivity() {
    override fun getDartEntrypointFunctionName(): String = "arioMain"
}
