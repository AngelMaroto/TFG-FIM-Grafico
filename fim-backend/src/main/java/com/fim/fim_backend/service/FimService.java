package com.fim.fim_backend.service;

import com.fim.fim_backend.model.Alert;
import com.fim.fim_backend.model.Scan;
import com.fim.fim_backend.repository.AlertRepository;
import com.fim.fim_backend.repository.ScanRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class FimService {

    private final ScanRepository scanRepository;
    private final AlertRepository alertRepository;
    private final SimpMessagingTemplate messagingTemplate;

    public Scan crearScan(Scan scan) {
        Scan saved = scanRepository.save(scan);
        log.info("Scan creado con id={}", saved.getId());
        return saved;
    }

    public List<Alert> crearAlertas(List<Alert> alertas) {
        List<Alert> saved = alertRepository.saveAll(alertas);
        log.info("{} alertas guardadas", saved.size());
        // Notificar en tiempo real via WebSocket
        saved.forEach(alert ->
                messagingTemplate.convertAndSend("/topic/events", alert)
        );
        return saved;
    }

    public List<Scan> getAllScans() {
        return scanRepository.findAll();
    }

    public List<Alert> getAllAlertas() {
        return alertRepository.findAll();
    }

    public List<Alert> getAlertasByTipo(String tipo) {
        return alertRepository.findByTipoCambio(tipo);
    }

    public List<Alert> getAlertasByRuta(String ruta) {
        return alertRepository.findByRutaArchivoContaining(ruta);
    }
}
