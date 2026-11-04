"""Prototipo académico de persistencia por alcanzabilidad con Durus.

No contiene datos reales ni sustituye el modelo relacional de producción.
"""

from datetime import datetime, timezone

from durus.connection import Connection
from durus.file_storage import FileStorage
from durus.persistent import Persistent
from durus.persistent_list import PersistentList


class EmotionEvent(Persistent):
    def __init__(self, emotion: str, intensity: int, context: str = "") -> None:
        if not 1 <= intensity <= 10:
            raise ValueError("intensity must be between 1 and 10")
        self.emotion = emotion
        self.intensity = intensity
        self.context = context
        self.occurred_at = datetime.now(timezone.utc)

    def summary(self) -> str:
        return f"{self.emotion} ({self.intensity}/10)"


class UserProfile(Persistent):
    def __init__(self, external_user_id: int, display_name: str) -> None:
        self.external_user_id = external_user_id
        self.display_name = display_name
        self.events = PersistentList()

    def add_event(self, event: EmotionEvent) -> None:
        self.events.append(event)


def open_demo(path: str = "moodsitto-demo.durus") -> Connection:
    connection = Connection(FileStorage(path))
    root = connection.get_root()
    if "profiles" not in root:
        root["profiles"] = PersistentList()
        connection.commit()
    return connection


if __name__ == "__main__":
    db = open_demo()
    profile = UserProfile(1001, "Usuario ficticio")
    profile.add_event(EmotionEvent("Motivación", 6, "Demostración académica"))
    db.get_root()["profiles"].append(profile)
    db.commit()
    print(profile.events[0].summary())
    db.get_storage().close()

