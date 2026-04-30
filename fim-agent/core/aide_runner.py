import subprocess
import logging
from pathlib import Path

logger = logging.getLogger(__name__)

class AideRunner:
    def __init__(self, config: dict):
        self.aide_config = config['aide']['config_path']
        self.db_path     = config['aide']['database_path']
        self.db_new_path = config['aide']['database_new_path']

    def init(self) -> bool:
        logger.info("Inicializando base de datos AIDE...")
        result = self._run_aide('--init')
        if result.returncode == 0:
            Path(self.db_new_path).rename(self.db_path)
            logger.info("Base de datos AIDE inicializada correctamente.")
            return True
        logger.error(f"Error al inicializar AIDE: {result.stderr}")
        return False

    def check(self) -> str:
        logger.info("Ejecutando comprobación AIDE...")
        result = self._run_aide('--check')
        if result.returncode > 1:
            logger.warning(f"AIDE warnings: {result.stderr}")
        return result.stdout

    def _run_aide(self, command: str) -> subprocess.CompletedProcess:
        return subprocess.run(
            ['aide', command, f'--config={self.aide_config}'],
            capture_output=True,
            text=True
        )
