# Changelog

## 2026-05-10

### Bugfixes

#### SocketCAN "was not properly shut down" Warnung (canpi.py)
- `bus.shutdown()` im Destruktor war auskommentiert — reaktiviert. Verhindert die ständige Log-Warnung von python-can.
- Fehlender `import os` ergänzt — ohne den Import crashte der Fehlerfall (`os.EX_CONFIG`) beim Öffnen des CAN-Bus.

#### Config-Timeout wurde ignoriert (canpi.py)
- `get_with_default()` prüfte `if "config" not in config.sections()` statt `if section not in config.sections()`. Dadurch wurde die `[CANPI]` Sektion aus `pyhpsu.conf` nie gelesen und immer der Default (`timeout=0.05`) verwendet.

#### MQTT-Verbindungsabbruch → Totaler Kommunikationsverlust (pyHPSU.py)
- Neuer `on_connect` Callback: Re-subscribed automatisch auf das Command-Topic nach jedem (Re-)Connect. Ohne diesen Callback gingen nach einem Reconnect alle MQTT-Subscriptions verloren.
- `on_disconnect` gefixt: Rief vorher `client.loop_stop()` auf, was den automatischen Reconnect von paho-mqtt verhinderte.
- `reconnect_delay_set(min_delay=1, max_delay=30)` hinzugefügt: Reconnect startet nach 1s mit exponentiellem Backoff bis max 30s.

#### MQTT-Plugin Nachrichten nie gesendet (HPSU/plugins/mqtt.py)
- `pushValues()` rief `publish()` auf, ohne den paho-mqtt Network-Loop zu starten. Nachrichten wurden daher nie tatsächlich an den Broker übermittelt.
- Fix: `loop_start()` vor dem Publish, `wait_for_publish()` pro Nachricht, `loop_stop()` + `disconnect()` danach.
- Gleichzeitig den `retain`-Parameter aus der Config korrekt an `publish()` durchgereicht (vorher immer `retain=False` hardcoded in der `msg`-Variable).

#### Exception-Handler crash (pyHPSU.py)
- `os.SOFTWARE` → `os.EX_SOFTWARE` — das Attribut `os.SOFTWARE` existiert nicht, wodurch der Exception-Handler selbst crashte.

### Verbesserungen

#### exec() im Auto-Modus entfernt (pyHPSU.py)
- `exec('thread_%s = threading.Thread(...)' % period)` durch normalen `threading.Thread(...)` Aufruf ersetzt.
- Altes Verhalten war problematisch: Die Variable `period` hatte nach der for-Schleife nur den letzten Wert, und `exec()` ist ein Sicherheitsrisiko.

#### HPSU/CAN-Bus Objekt wird wiederverwendet (pyHPSU.py)
- Im Auto-Modus wurde bei **jedem Tick** (jede Sekunde) ein neues `HPSU()` Objekt erstellt, das einen neuen SocketCAN-Bus öffnete. Jetzt wird das HPSU-Objekt einmalig mit allen Job-Kommandos erstellt.
- Im MQTT-Daemon-Modus wurde bei **jedem eingehenden MQTT-Befehl** ein neues `HPSU()` Objekt erstellt. Jetzt wird ein bestehendes Objekt wiederverwendet und fehlende Kommandos dynamisch aus dem Command-Dictionary nachgeladen.
- Reduziert massiven Ressourcen-Overhead und eliminiert die Quelle der "SocketcanBus was not properly shut down" Warnung im laufenden Betrieb.

### Betroffene Dateien
- `pyHPSU.py`
- `HPSU/canpi.py`
- `HPSU/plugins/mqtt.py`
