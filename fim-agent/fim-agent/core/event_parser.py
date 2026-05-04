import re
import hashlib
import base64
import logging
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
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

    # Línea de entrada: cualquier tipo (f/d/l...) seguido de flags y ": /ruta"
    ENTRY_PATTERN = re.compile(r'^[fFdDlLpPs].+?:\s+(?P<ruta>/.+)$')

    # Bloque de detalle: "File: /ruta\n atributos..."
    DETAIL_BLOCK_PATTERN = re.compile(
        r'^(?:File|Directory):\s+(?P<ruta>.+?)\n(?P<attrs>(?:[ \t]+[^\n]+\n)*)',
        re.MULTILINE
    )

    @staticmethod
    def _calc_sha256(ruta: str) -> str:
        """Calcula SHA256 en base64 (formato AIDE) de un fichero local."""
        try:
            h = hashlib.sha256()
            with open(ruta, 'rb') as f:
                for chunk in iter(lambda: f.read(65536), b''):
                    h.update(chunk)
            return base64.b64encode(h.digest()).decode()
        except (OSError, PermissionError):
            return ''

    def _parse_aide_value(self, lines: List[str], start_idx: int):
        """
        Lee el valor de una clave AIDE que puede estar partido en varias líneas.
        AIDE imprime los valores largos (hashes) así:
          ' SHA256    : IZQUIERDA_FRAG1 | DERECHA_FRAG1'
          '             IZQUIERDA_FRAG2 | DERECHA_FRAG2'
        Devuelve (izquierda, derecha) con los fragmentos concatenados,
        o (valor, None) si no hay separador '|'.
        """
        first = lines[start_idx].split(':', 1)[1].strip()

        # Recoger líneas de continuación (indentadas, sin nueva clave)
        fragments = [first]
        i = start_idx + 1
        while i < len(lines):
            stripped = lines[i].strip()
            if not stripped:
                break
            # Nueva clave: contiene ':' antes de cualquier '|'
            pre_pipe = stripped.split('|')[0]
            if ':' in pre_pipe:
                break
            fragments.append(stripped)
            i += 1

        if not any('|' in f for f in fragments):
            return (''.join(f.replace(' ', '') for f in fragments), None)

        # Unir fragmentos izquierda y derecha por separado
        left_parts  = []
        right_parts = []
        for frag in fragments:
            if '|' in frag:
                l, r = frag.split('|', 1)
                left_parts.append(l.strip())
                right_parts.append(r.strip())
            else:
                # Fragmento sin '|': pertenece a la parte que ya teníamos
                # (caso raro, añadir a ambos por seguridad)
                left_parts.append(frag.strip())
                right_parts.append(frag.strip())

        return (''.join(left_parts), ''.join(right_parts))

    def _parse_detail_block(self, attrs_text: str) -> dict:
        """
        Extrae hash_anterior, hash_actual, permisos y tamaño del bloque
        de atributos de AIDE, gestionando valores partidos en varias líneas.
        """
        result = {
            'hash_anterior': '',
            'hash_actual':   '',
            'permisos':      '',
            'tamanio':       0,
        }

        lines = attrs_text.splitlines()

        for i, line in enumerate(lines):
            stripped = line.strip()
            if not stripped or ':' not in stripped:
                continue

            key = stripped.split(':')[0].strip().upper()

            if key == 'SHA256':
                left, right = self._parse_aide_value(lines, i)
                result['hash_anterior'] = left  or ''
                result['hash_actual']   = right or ''

            elif key == 'PERM':
                left, right = self._parse_aide_value(lines, i)
                result['permisos'] = right or left or ''

            elif key == 'SIZE':
                left, right = self._parse_aide_value(lines, i)
                try:
                    result['tamanio'] = int((right or left or '0').split()[0])
                except ValueError:
                    pass

        return result

    def parse(self, aide_output: str) -> List[FimEvent]:
        if not aide_output:
            return []

        # 1. Construir mapa ruta -> bloque de atributos
        detail_map = {}
        for m in self.DETAIL_BLOCK_PATTERN.finditer(aide_output):
            detail_map[m.group('ruta').strip()] = m.group('attrs')

        events: List[FimEvent] = []
        rutas_procesadas = set()

        # 2. Recorrer línea a línea detectando sección activa
        section = None
        for line in aide_output.splitlines():
            stripped = line.strip()

            if stripped == 'Added entries:':
                section = 'NEW'
                continue
            elif stripped == 'Removed entries:':
                section = 'DELETED'
                continue
            elif stripped == 'Changed entries:':
                section = 'MODIFIED'
                continue
            elif stripped.startswith('Detailed information'):
                break
            elif stripped.startswith('---') or stripped == '':
                continue

            if section is None:
                continue

            m = self.ENTRY_PATTERN.match(stripped)
            if not m:
                continue

            # Solo ficheros (f) y directorios (d)
            if stripped[0].lower() not in ('f', 'd'):
                continue

            ruta = m.group('ruta').strip()
            if ruta in rutas_procesadas:
                continue
            rutas_procesadas.add(ruta)

            detail = {}
            if ruta in detail_map:
                detail = self._parse_detail_block(detail_map[ruta])

            # Para ficheros NEW, AIDE no reporta hashes en el detalle.
            # Los calculamos directamente del fichero si es accesible.
            hash_actual = detail.get('hash_actual', '')
            if section == 'NEW' and not hash_actual and Path(ruta).is_file():
                hash_actual = self._calc_sha256(ruta)

            events.append(FimEvent(
                tipo          = section,
                ruta          = ruta,
                nombre        = ruta.split('/')[-1],
                hash_anterior = detail.get('hash_anterior', ''),
                hash_actual   = hash_actual,
                permisos      = detail.get('permisos',      ''),
                tamanio       = detail.get('tamanio',       0),
            ))

        logger.info(
            f"Eventos parseados: {len(events)} "
            f"(NEW={sum(1 for e in events if e.tipo=='NEW')}, "
            f"DELETED={sum(1 for e in events if e.tipo=='DELETED')}, "
            f"MODIFIED={sum(1 for e in events if e.tipo=='MODIFIED')})"
        )
        return events
