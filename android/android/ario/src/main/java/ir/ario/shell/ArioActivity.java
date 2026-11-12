package ir.ario.shell;

import ir.souren.souren.MainActivity;

/**
 * Ario's real launcher Activity. It inherits the native file/share bridges
 * but runs its own Flutter engine and Dart entrypoint in a separate task.
 */
public final class ArioActivity extends MainActivity {
    @Override
    public String getDartEntrypointFunctionName() {
        return "arioMain";
    }
}
