package com.fim.fim_backend.controller;

import com.fim.fim_backend.model.Alert;
import com.fim.fim_backend.model.Scan;
import com.fim.fim_backend.service.FimService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

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
    public ResponseEntity<List<Alert>> crearAlertas(@RequestBody List<Alert> alertas) {
        return ResponseEntity.ok(fimService.crearAlertas(alertas));
    }

    // GET /api/scans
    @GetMapping("/scans")
    public ResponseEntity<List<Scan>> getAllScans() {
        return ResponseEntity.ok(fimService.getAllScans());
    }

    /**
     * GET /api/events
     * Parámetros opcionales: tipo, ruta, desde (yyyy-MM-dd), hasta (yyyy-MM-dd)
     *
     * Ejemplos:
     *   /api/events
     *   /api/events?tipo=NEW
     *   /api/events?desde=2025-04-01&hasta=2025-04-30
     *   /api/events?tipo=MODIFIED&desde=2025-04-20
     */
    @GetMapping("/events")
    public ResponseEntity<List<Alert>> getAllAlertas(
            @RequestParam(required = false) String tipo,
            @RequestParam(required = false) String ruta,
            @RequestParam(required = false) String desde,
            @RequestParam(required = false) String hasta) {

        // Si hay cualquier filtro activo → usar el método combinado
        if (tipo != null || ruta != null || desde != null || hasta != null) {
            return ResponseEntity.ok(
                    fimService.getAlertasWithFilters(tipo, ruta, desde, hasta));
        }
        return ResponseEntity.ok(fimService.getAllAlertas());
    }


    // GET /api/status — estado del sistema para la pantalla de ajustes
    @GetMapping("/status")
    public ResponseEntity<Map<String, Object>> getStatus() {
        List<Scan> scans = fimService.getAllScans();
        List<Alert> events = fimService.getAllAlertas();

        // Último escaneo
        String ultimoScan = scans.isEmpty() ? null :
                scans.get(scans.size() - 1).getFechaEjecucion().toString();

        // Hostname del servidor
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