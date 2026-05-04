import requests
import logging
from typing import List
from core.event_parser import FimEvent

logger = logging.getLogger(__name__)

EP_SYSTEM_CONFIG = '/api/config/system'


class ApiClient:
    def __init__(self, config: dict):
        self.base_url    = config['backend']['url']
        self.timeout     = config['backend']['timeout']
        self.ep_events   = config['backend']['api_events']
        self.ep_scans    = config['backend']['api_scans']
        self.ep_pending  = '/api/agent/pending'
        self.ep_consumed = '/api/agent/commands/{id}/consumed'

    def enviar_scan(self, hostname: str, resumen: str) -> int | None:
        url = f"{self.base_url}{self.ep_scans}"
        payload = {"hostname": hostname, "resumenCambios": resumen}
        try:
            response = requests.post(url, json=payload, timeout=self.timeout)
            response.raise_for_status()
            scan_id = response.json().get('id')
            logger.info(f"Scan registrado en backend con id={scan_id}")
            return scan_id
        except requests.exceptions.ConnectionError:
            logger.warning("Backend no disponible.")
            return None
        except requests.exceptions.RequestException as e:
            logger.error(f"Error al registrar scan: {e}")
            return None

    def enviar_eventos(self, eventos: List[FimEvent], scan_id: int) -> bool:
        if not eventos:
            logger.info("Sin eventos que enviar.")
            return True
        url = f"{self.base_url}{self.ep_events}"
        payload = [
            {
                "tipoCambio":    evento.tipo,
                "rutaArchivo":   evento.ruta,
                "nombreArchivo": evento.nombre,
                "hashActual":    evento.hash_actual,
                "hashAnterior":  evento.hash_anterior,
                "permisos":      evento.permisos,
                "timestamp":     evento.timestamp,
                "severidad":     "MEDIA",
                "scan":          {"id": scan_id}
            }
            for evento in eventos
        ]
        try:
            response = requests.post(url, json=payload, timeout=self.timeout)
            response.raise_for_status()
            logger.info(f"{len(eventos)} eventos enviados correctamente.")
            return True
        except requests.exceptions.ConnectionError:
            logger.warning("Backend no disponible.")
            return False
        except requests.exceptions.RequestException as e:
            logger.error(f"Error al enviar eventos: {e}")
            return False

    def hay_check_pendiente(self) -> tuple[bool, int | None]:
        url = f"{self.base_url}{self.ep_pending}"
        try:
            response = requests.get(url, timeout=self.timeout)
            response.raise_for_status()
            data = response.json()
            if data.get('pending'):
                return True, data.get('id')
            return False, None
        except requests.exceptions.RequestException:
            return False, None

    def marcar_comando_consumido(self, cmd_id: int) -> None:
        url = f"{self.base_url}{self.ep_consumed.format(id=cmd_id)}"
        try:
            requests.put(url, timeout=self.timeout)
            logger.info(f"Comando {cmd_id} marcado como consumido.")
        except requests.exceptions.RequestException as e:
            logger.warning(f"No se pudo marcar comando {cmd_id}: {e}")

    def obtener_intervalo(self, fallback: int) -> int:
        url = f"{self.base_url}{EP_SYSTEM_CONFIG}/scan_interval"
        try:
            response = requests.get(url, timeout=self.timeout)
            if response.status_code == 200:
                valor = response.json().get('configValue')
                intervalo = int(valor)
                if intervalo < 10:
                    intervalo = 10
                logger.debug(f"Intervalo obtenido del backend: {intervalo}s")
                return intervalo
            return fallback
        except (requests.exceptions.RequestException, ValueError, TypeError):
            return fallback
