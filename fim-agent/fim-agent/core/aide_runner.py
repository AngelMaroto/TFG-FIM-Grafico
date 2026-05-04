import subprocess
import logging
from pathlib import Path

logger = logging.getLogger(__name__)


class AideRunner:
    def __init__(self, config: dict):
        self.aide_config  = config['aide']['config_path']
        self.db_path      = config['aide']['database_path']
        self.db_new_path  = config['aide']['database_new_path']

    def init(self) -> bool:
        logger.info("Inicializando base de datos AIDE...")
        result = self._run_aide('--init')
        if result.returncode == 0:
            mv = subprocess.run(
                ['mv', '-f', self.db_new_path, self.db_path],
                capture_output=True, text=True
            )
            if mv.returncode == 0:
                logger.info("Base de datos AIDE inicializada correctamente.")
                return True
            logger.error(f"Error al mover BD inicial: {mv.stderr}")
            return False
        logger.error(f"Error al inicializar AIDE: {result.stderr}")
        return False

    def check(self) -> str:
        logger.info("Ejecutando comprobación AIDE...")
        # IMPORTANTE: stderr=subprocess.STDOUT para combinar ambos streams.
        # AIDE escribe el report completo (bloques File: con hashes) a stderr.
        # Sin esta combinación el parser recibe un output incompleto sin hashes.
        result = subprocess.run(
            ['aide', '--check', f'--config={self.aide_config}'],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True
        )
        if result.returncode > 1:
            logger.warning("AIDE warnings presentes en el report.")
        return result.stdout

    def update(self) -> bool:
        """
        Actualiza la baseline AIDE tras enviar los eventos al backend.
        Sin este update, AIDE redetecta los mismos ficheros en cada ciclo.
        FIX: usa 'mv -f' via subprocess en lugar de Path.rename().
        Path.rename() falla cuando db_new_path es propiedad de root y el
        proceso no tiene permisos de escritura en el directorio padre.
        subprocess hereda los permisos del proceso (root via systemd).
        """
        logger.info("Actualizando baseline AIDE...")
        result = self._run_aide('--update')
        # rc=0 sin cambios, rc=1 cambios detectados — ambos son OK para update
        if result.returncode in (0, 1, 4, 5):
            new_db = Path(self.db_new_path)
            if new_db.exists() and new_db.stat().st_size > 0:
                mv = subprocess.run(
                    ['mv', '-f', self.db_new_path, self.db_path],
                    capture_output=True, text=True
                )
                if mv.returncode == 0:
                    logger.info("Baseline AIDE actualizada correctamente.")
                    return True
                else:
                    logger.error(f"Error al mover nueva BD: {mv.stderr}")
                    return False
            else:
                logger.warning("--update no generó nueva BD o está vacía.")
                return True
        logger.error(
            f"Error al actualizar baseline AIDE (rc={result.returncode}): {result.stderr}")
        return False

    def _run_aide(self, command: str) -> subprocess.CompletedProcess:
        return subprocess.run(
            ['aide', command, f'--config={self.aide_config}'],
            capture_output=True,
            text=True
        )
