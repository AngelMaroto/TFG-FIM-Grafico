# fim_agent.py
import sys
import time
import logging
import argparse
import yaml
from core.aide_runner import AideRunner
from core.event_parser import EventParser
from core.api_client import ApiClient

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(name)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

DEFAULT_INTERVAL = 60


def cargar_config(path: str = 'config.yaml') -> dict:
    with open(path, 'r') as f:
        return yaml.safe_load(f)


def ejecutar_check(runner: AideRunner, parser: EventParser,
                   client: ApiClient, hostname: str) -> None:
    """Ejecuta un ciclo completo de comprobación FIM."""
    logger.info("--- Iniciando comprobación FIM ---")
    aide_output = runner.check()
    eventos = parser.parse(aide_output)

    if eventos:
        resumen = (f"NEW={sum(1 for e in eventos if e.tipo=='NEW')}, "
                   f"DELETED={sum(1 for e in eventos if e.tipo=='DELETED')}, "
                   f"MODIFIED={sum(1 for e in eventos if e.tipo=='MODIFIED')}, "
                   f"PERMISSIONS={sum(1 for e in eventos if e.tipo=='PERMISSIONS')}")
        scan_id = client.enviar_scan(hostname, resumen)
        if scan_id:
            enviado = client.enviar_eventos(eventos, scan_id)
            # FIX: actualizar baseline AIDE solo si los eventos se enviaron
            # correctamente. Sin este update, AIDE redetecta los mismos
            # ficheros en cada ciclo → miles de eventos duplicados en la BD.
            if enviado:
                runner.update()
            else:
                logger.warning(
                    "Eventos no enviados al backend — "
                    "baseline NO actualizada para reintentar en el próximo ciclo.")
    else:
        logger.info("Sin cambios detectados.")


def cmd_init(config: dict):
    runner = AideRunner(config)
    ok = runner.init()
    if ok:
        logger.info("Sistema FIM inicializado correctamente.")
    else:
        logger.error("Fallo al inicializar el sistema FIM.")
        sys.exit(1)


def cmd_check(config: dict, daemon: bool = False):
    runner   = AideRunner(config)
    parser   = EventParser()
    client   = ApiClient(config)
    hostname = config['agent']['hostname']
    intervalo_fallback = config['agent']['check_interval']

    while True:
        ejecutar_check(runner, parser, client, hostname)

        if not daemon:
            break

        intervalo = client.obtener_intervalo(intervalo_fallback)
        logger.info(f"Esperando {intervalo}s hasta la próxima comprobación...")

        transcurrido = 0
        while transcurrido < intervalo:
            time.sleep(10)
            transcurrido += 10

            pendiente, cmd_id = client.hay_check_pendiente()
            if pendiente and cmd_id:
                logger.info(
                    f"Check manual solicitado (cmd_id={cmd_id}). Ejecutando ahora...")
                ejecutar_check(runner, parser, client, hostname)
                client.marcar_comando_consumido(cmd_id)
                transcurrido = 0
                intervalo = client.obtener_intervalo(intervalo_fallback)
                logger.info(
                    f"Esperando {intervalo}s hasta la próxima comprobación...")


def main():
    argparser = argparse.ArgumentParser(
        description='Agente FIM para auditoría de sistemas Linux')
    argparser.add_argument('comando', choices=['init', 'check'],
                           help='init: inicializar BD | check: detectar cambios')
    argparser.add_argument('--daemon', action='store_true',
                           help='Ejecutar en modo continuo (solo con check)')
    argparser.add_argument('--config', default='config.yaml',
                           help='Ruta al fichero de configuración')
    args = argparser.parse_args()
    config = cargar_config(args.config)

    if args.comando == 'init':
        cmd_init(config)
    elif args.comando == 'check':
        cmd_check(config, daemon=args.daemon)


if __name__ == '__main__':
    main()
