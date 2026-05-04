package com.fim.fim_backend.controller;

import com.fim.fim_backend.dto.EventoDTO;
import com.fim.fim_backend.model.Alert;
import com.fim.fim_backend.model.Scan;
import com.fim.fim_backend.service.FimService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.stream.Collectors;
import com.fim.fim_backend.dto.AlertResponseDTO;
import java.util.List;
import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
public class FimController {

    private final FimService fimService;

    // POST /api/scans
    @PostMapping("/scans")
    public ResponseEntity<Scan> crearScan(@RequestBody Scan scan) {
        return ResponseEntity.ok(fimService.crearScan(scan));
    }

    // POST /api/events
    @PostMapping("/events")
    public ResponseEntity<List<AlertResponseDTO>> crearAlertas(@RequestBody List<EventoDTO> eventos) {
        return ResponseEntity.ok(
                fimService.crearAlertas(eventos)
                        .stream()
                        .map(AlertResponseDTO::from)
                        .collect(Collectors.toList()));
    }

    // GET /api/scans
    @GetMapping("/scans")
    public ResponseEntity<List<Scan>> getAllScans() {
        return ResponseEntity.ok(fimService.getAllScans());
    }

    /**
     * GET /api/events
     *
     * Parámetros opcionales:
     *   tipo   → filtra por tipo de cambio (NEW, DELETED, MODIFIED, PERMISSIONS)
     *   ruta   → filtra por ruta (contiene)
     *   desde  → fecha inicio yyyy-MM-dd (inclusive)
     *   hasta  → fecha fin   yyyy-MM-dd (inclusive, fin de día)
     *   limit  → número máximo de resultados (default 50)
     *   offset → desplazamiento para paginación (default 0)
     *
     * FIX: antes el endpoint ignoraba limit y offset y devolvía TODOS los
     * registros siempre. Flutter mandaba offset=50, offset=100… pero Spring
     * devolvía los mismos datos → duplicados en la lista + crash por memoria.
     */
    @GetMapping("/events")
    public ResponseEntity<List<AlertResponseDTO>> getAllAlertas(
            @RequestParam(required = false) String tipo,
            @RequestParam(required = false) String ruta,
            @RequestParam(required = false) String desde,
            @RequestParam(required = false) String hasta,
            @RequestParam(defaultValue = "50")  int limit,
            @RequestParam(defaultValue = "0")   int offset) {

        // Sanitizar: evitar valores absurdos que puedan saturar la BD
        int safeLimit  = Math.min(Math.max(limit,  1), 500);
        int safeOffset = Math.max(offset, 0);

        return ResponseEntity.ok(
                fimService.getAlertasPaginadas(tipo, ruta, desde, hasta,
                                safeLimit, safeOffset)
                        .stream()
                        .map(AlertResponseDTO::from)
                        .collect(Collectors.toList()));
    }

    // GET /api/status
    @GetMapping("/status")
    public ResponseEntity<Map<String, Object>> getStatus() {
        List<Scan>  scans  = fimService.getAllScans();
        List<Alert> events = fimService.getAllAlertas();

        String ultimoScan = scans.isEmpty() ? null :
                scans.get(scans.size() - 1).getFechaEjecucion().toString();

        String hostname = "desconocido";
        try {
            hostname = java.net.InetAddress.getLocalHost().getHostName();
        } catch (Exception ignored) {}

        return ResponseEntity.ok(Map.of(
                "status",     "running",
                "scans",      scans.size(),
                "events",     events.size(),
                "ultimoScan", ultimoScan != null ? ultimoScan : "Sin escaneos",
                "hostname",   hostname
        ));
    }
}