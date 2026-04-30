package com.fim.fim_backend.service;

import com.fim.fim_backend.model.Alert;
import com.fim.fim_backend.model.Scan;
import com.fim.fim_backend.repository.AlertRepository;
import com.fim.fim_backend.repository.ScanRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
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

    /**
     * Filtro combinado: tipo, ruta y rango de fechas del scan.
     * Cualquier parámetro puede ser null (se ignora en la query).
     * @param desde  fecha inicio en formato "yyyy-MM-dd" (inclusive)
     * @param hasta  fecha fin   en formato "yyyy-MM-dd" (inclusive, fin de día)
     */
    public List<Alert> getAlertasWithFilters(
            String tipo, String ruta, String desde, String hasta) {

        LocalDateTime desdeDate = null;
        LocalDateTime hastaDate = null;

        try {
            if (desde != null && !desde.isBlank()) {
                desdeDate = LocalDate.parse(desde).atStartOfDay();
            }
            if (hasta != null && !hasta.isBlank()) {
                // Incluir todo el día "hasta"
                hastaDate = LocalDate.parse(hasta).atTime(LocalTime.MAX);
            }
        } catch (Exception e) {
            log.warn("Formato de fecha inválido: desde={} hasta={}", desde, hasta);
        }

        return alertRepository.findWithFilters(
                tipo,
                ruta,
                desdeDate,
                hastaDate
        );
    }
}