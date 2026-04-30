import re
import logging
from dataclasses import dataclass, field
from datetime import datetime
from typing import List

logger = logging.getLogger(__name__)

@dataclass
class FimEvent:
    tipo:          str
    ruta:          str
    nombre:        str
    hash_actual:   str = ""
    hash_anterior: str = ""
    permisos:      str = ""
    tamanio:       int = 0
    timestamp:     str = field(default_factory=lambda: datetime.utcnow().isoformat())


class EventParser:
    # Patrones reales de la salida de AIDE 0.18
    NEW_PATTERN      = re.compile(r'^f\+{10,}:\s+(.+)$', re.MULTILINE)
    DELETED_PATTERN  = re.compile(r'^f-{10,}:\s+(.+)$', re.MULTILINE)
    MODIFIED_PATTERN = re.compile(r'^f[a-zA-Z.= ]{5,}:\s+(.+)$', re.MULTILINE)
    PERMS_PATTERN    = re.compile(r'^f[a-zA-Z.= ]{5,}p[a-zA-Z.= ]{3,}:\s+(.+)$', re.MULTILINE)

    def parse(self, aide_output: str) -> List[FimEvent]:
        if not aide_output:
            return []

        events: List[FimEvent] = []
        rutas_procesadas = set()

        for match in self.NEW_PATTERN.finditer(aide_output):
            ruta = match.group(1).strip()
            if ruta not in rutas_procesadas:
                rutas_procesadas.add(ruta)
                events.append(FimEvent(
                    tipo='NEW',
                    ruta=ruta,
                    nombre=ruta.split('/')[-1]
                ))

        for match in self.DELETED_PATTERN.finditer(aide_output):
            ruta = match.group(1).strip()
            if ruta not in rutas_procesadas:
                rutas_procesadas.add(ruta)
                events.append(FimEvent(
                    tipo='DELETED',
                    ruta=ruta,
                    nombre=ruta.split('/')[-1]
                ))

        for match in self.MODIFIED_PATTERN.finditer(aide_output):
            ruta = match.group(1).strip()
            if ruta not in rutas_procesadas:
                rutas_procesadas.add(ruta)
                events.append(FimEvent(
                    tipo='MODIFIED',
                    ruta=ruta,
                    nombre=ruta.split('/')[-1]
                ))

        logger.info(f"Eventos parseados: {len(events)} "
                    f"(NEW={sum(1 for e in events if e.tipo=='NEW')}, "
                    f"DELETED={sum(1 for e in events if e.tipo=='DELETED')}, "
                    f"MODIFIED={sum(1 for e in events if e.tipo=='MODIFIED')}, "
                    f"PERMISSIONS={sum(1 for e in events if e.tipo=='PERMISSIONS')})")
        return events
