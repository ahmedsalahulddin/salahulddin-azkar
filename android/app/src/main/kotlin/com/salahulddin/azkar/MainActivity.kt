package com.salahulddin.azkar

import android.content.Context
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // The flutter_local_notifications plugin serialises scheduled
        // notifications to SharedPreferences. When the plugin is updated the
        // stored JSON may be missing a field the new deserialiser requires
        // ("Missing type parameter"), and every zonedSchedule() call then
        // fails because it loads that list before appending.
        //
        // We remove the stale entry once — before Flutter initialises — so
        // the plugin finds a clean slate. A null value causes the plugin to
        // return an empty list without parsing, which is exactly what we need.
        // The reminders are rebuilt immediately by main() after init().
        clearCorruptScheduledNotifications()
        super.onCreate(savedInstanceState)
    }

    private fun clearCorruptScheduledNotifications() {
        val migrationPrefs = getSharedPreferences("azkar_migration", Context.MODE_PRIVATE)
        if (migrationPrefs.getBoolean("flln_v18_cleared", false)) return

        getSharedPreferences("scheduled_notifications", Context.MODE_PRIVATE)
            .edit()
            .remove("scheduled_notifications")
            .apply()

        migrationPrefs.edit().putBoolean("flln_v18_cleared", true).apply()
    }
}
