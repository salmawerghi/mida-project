package tn.mida.mida_livreur

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        creerCanalNotifications()
    }

    /**
     * US23 : canal « Commandes » en importance haute, pour que les
     * notifications push s'affichent en haut de l'écran avec un son.
     * Son identifiant est repris par l'Edge Function envoyer-push et par
     * le manifeste (default_notification_channel_id).
     */
    private fun creerCanalNotifications() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val canal = NotificationChannel("commandes_mida", "Commandes", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "Suivi des commandes et des courses Mida"
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(canal)
    }
}
