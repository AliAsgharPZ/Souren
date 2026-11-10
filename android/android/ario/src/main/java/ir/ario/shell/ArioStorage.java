package ir.ario.shell;

import android.content.Context;
import android.content.SharedPreferences;

import java.io.File;

/**
 * Ario-owned storage namespace.
 *
 * Keep Ario preferences, databases and files under these names/paths rather
 * than reusing Souren's storage keys or database.
 */
public final class ArioStorage {
    private static final String PREFERENCES = "ario_preferences";
    private static final String DATABASE = "ario.db";

    private ArioStorage() {}

    public static File directory(Context context) {
        return context.getDir("ario", Context.MODE_PRIVATE);
    }

    public static SharedPreferences preferences(Context context) {
        return context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE);
    }

    public static String databaseName() {
        return DATABASE;
    }

    /** Explicitly clears only Ario-owned local state. */
    public static void clearLocalData(Context context) {
        preferences(context).edit().clear().apply();
        context.deleteDatabase(DATABASE);
        deleteRecursively(directory(context));
    }

    private static void deleteRecursively(File file) {
        if (file.isDirectory()) {
            File[] children = file.listFiles();
            if (children != null) {
                for (File child : children) {
                    deleteRecursively(child);
                }
            }
        }
        // Best effort: the caller can recreate the namespace on next launch.
        //noinspection ResultOfMethodCallIgnored
        file.delete();
    }
}
