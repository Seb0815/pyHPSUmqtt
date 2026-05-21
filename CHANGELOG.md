# Changelog

## 2026-05-21

### Bugfixes

#### CAN-Bus Thread-Unsicherheit → "msg not sync" Kaskade (pyHPSU.py)
- Im Auto-Modus konnten mehrere Threads gleichzeitig auf den CAN-Bus zugreifen (z.B. wenn ein Timer feuert während der vorherige Thread noch läuft, oder ein MQTT-Daemon-Befehl zeitgleich eingeht). Dadurch wurden CAN-Antworten vertauscht → endlose "msg not sync" Retries → Timeout aller Kommandos.
- Fix: Globaler `threading.Lock()` (`can_lock`) um alle CAN-Bus-Operationen in `read_can()`. Nur noch ein Thread kann gleichzeitig CAN-Kommandos senden/empfangen.

#### MQTT-Broker-Ausfall crasht Auto-Mode Threads (pyHPSU.py)
- Wenn der MQTT-Broker kurzzeitig nicht erreichbar war, warf das MQTT-Plugin (oder ein anderes Output-Plugin) eine unbehandelte `ConnectionRefusedError`. Da `read_can()` in einem Thread läuft, starb der Thread still — CAN-Werte wurden nicht mehr abgefragt.
- Fix: Alle Output-Plugin-Aufrufe in `read_can()` sind jetzt in `try/except` gewrappt. Fehler werden geloggt, aber der Thread überlebt.

#### Initialer MQTT-Connect blockiert bei Broker-Ausfall (pyHPSU.py)
- `mqtt_client.connect()` beim Start warf eine Exception wenn der Broker nicht erreichbar war → Service-Start schlug fehl.
- Fix: Retry-Loop mit 5s Wartezeit bis der Broker verfügbar ist.

### Betroffene Dateien
- `pyHPSU.py`

## 2026-05-21a

### Bugfixes

#### CAN-Bus Empfangspuffer voll mit alten Nachrichten → "msg not sync" Timeout (canpi.py)
- Die HPSU sendet ständig interne Status-Nachrichten auf dem CAN-Bus. Diese sammelten sich im Empfangspuffer an. Beim Senden eines Kommandos wurden dann erst die alten Nachrichten abgearbeitet statt der eigentlichen Antwort — nach 15 Versuchen war die richtige Antwort oft nicht dabei → Timeout.
- Fix: Vor jedem `bus.send()` wird der Empfangspuffer mit `bus.recv(timeout=0)` komplett geleert. So kommen nach dem Senden nur noch frische Nachrichten an.

#### read_can() fragt alle Kommandos ab statt nur die angeforderten (pyHPSU.py)
- Regression vom vorherigen Refactoring: Da `n_hpsu` jetzt global mit allen Job-Kommandos erstellt wird, iterierte `read_can()` über **alle** Kommandos statt nur über die im `cmd`-Parameter angeforderten. Dadurch wurde bei jedem Timer-Tick jedes Kommando abgefragt, unabhängig von der konfigurierten Periode.
- Fix: `read_can()` filtert jetzt auf die angeforderten Kommandonamen und überspringt den Rest.

### Betroffene Dateien
- `HPSU/canpi.py`
- `pyHPSU.py`

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
