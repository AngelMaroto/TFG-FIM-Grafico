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

    // POST /api/scans - El agente crea un nuevo scan
    @PostMapping("/scans")
    public ResponseEntity<Scan> crearScan(@RequestBody Scan scan) {
        return ResponseEntity.ok(fimService.crearScan(scan));
    }

    // POST /api/events - El agente envía los eventos detectados
    @PostMapping("/events")
    public ResponseEntity<List<Alert>> crearAlertas(@RequestBody List<Alert> alertas) {
        return ResponseEntity.ok(fimService.crearAlertas(alertas));
    }

    // GET /api/scans - Obtener todos los scans
    @GetMapping("/scans")
    public ResponseEntity<List<Scan>> getAllScans() {
        return ResponseEntity.ok(fimService.getAllScans());
    }

    // GET /api/events - Obtener todas las alertas
    @GetMapping("/events")
    public ResponseEntity<List<Alert>> getAllAlertas(
            @RequestParam(required = false) String tipo,
            @RequestParam(required = false) String ruta) {

        if (tipo != null) return ResponseEntity.ok(fimService.getAlertasByTipo(tipo));
        if (ruta != null) return ResponseEntity.ok(fimService.getAlertasByRuta(ruta));
        return ResponseEntity.ok(fimService.getAllAlertas());
    }

    // GET /api/status - Estado del sistema
    @GetMapping("/status")
    public ResponseEntity<Map<String, Object>> getStatus() {
        return ResponseEntity.ok(Map.of(
                "status", "running",
                "scans", fimService.getAllScans().size(),
                "events", fimService.getAllAlertas().size()
        ));
    }
}
