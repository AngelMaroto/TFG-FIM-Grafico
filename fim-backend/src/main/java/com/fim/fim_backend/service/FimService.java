package com.fim.fim_backend.service;

import com.fim.fim_backend.model.Alert;
import com.fim.fim_backend.model.Scan;
import com.fim.fim_backend.repository.AlertRepository;
import com.fim.fim_backend.repository.ScanRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;
import com.fim.fim_backend.dto.EventoDTO;
import com.fim.fim_backend.model.FileEntry;
import com.fim.fim_backend.repository.FileEntryRepository;

@Slf4j
@Service
@RequiredArgsConstructor
public class FimService {

    private final ScanRepository          scanRepository;
    private final AlertRepository         alertRepository;
    private final SimpMessagingTemplate   messagingTemplate;
    private final FileEntryRepository fileEntryRepository;

    public Scan crearScan(Scan scan) {
        Scan saved = scanRepository.save(scan);
        log.info("Scan creado con id={}", saved.getId());
        return saved;
    }

    public List<Alert> crearAlertas(List<EventoDTO> dtos) {
        List<Alert> saved = dtos.stream().map(dto -> {
            // 1. Recuperar el Scan
            Scan scan = new Scan();
            scan.setId(dto.getScan().getId());

            // 2. Crear y persistir FileEntry
            FileEntry fe = new FileEntry();
            fe.setScan(scan);
            fe.setRutaArchivo(dto.getRutaArchivo());
            fe.setNombreArchivo(dto.getNombreArchivo());
            fe.setHashActual(dto.getHashActual());
            fe.setHashAnterior(dto.getHashAnterior());
            fe.setPermisos(dto.getPermisos());
            fe.setTamanio(dto.getTamanio());
            FileEntry savedFe = fileEntryRepository.save(fe);

            // 3. Crear Alert referenciando el FileEntry
            Alert alert = new Alert();
            alert.setScan(scan);
            alert.setFileEntry(savedFe);
            alert.setTipoCambio(dto.getTipoCambio());
            alert.setSeveridad(dto.getSeveridad() != null ? dto.getSeveridad() : "MEDIA");
            alert.setTimestamp(dto.getTimestamp());
            return alert;
        }).collect(java.util.stream.Collectors.toList());

        List<Alert> result = alertRepository.saveAll(saved);
        log.info("{} alertas guardadas", result.size());
        result.forEach(alert ->
                messagingTemplate.convertAndSend("/topic/events", alert));
        return result;
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
        return alertRepository.findByFileEntry_RutaArchivoContaining(ruta);
    }

    /**
     * Filtro combinado con paginación real.
     *
     * FIX: método nuevo que sustituye a getAlertasWithFilters() para el
     * endpoint GET /api/events. Usa Pageable de Spring Data para que la BD
     * aplique LIMIT + OFFSET a nivel SQL, evitando cargar toda la tabla en
     * memoria y devolverla entera a Flutter.
     *
     * Antes: SELECT * FROM alerts → 4000 filas → Flutter recibía siempre
     *        las mismas 4000 filas independientemente del offset pedido.
     * Ahora: SELECT * FROM alerts ... LIMIT ? OFFSET ? → página real.
     */
    public List<Alert> getAlertasPaginadas(
            String tipo, String ruta, String desde, String hasta,
            int limit, int offset) {

        // Pageable: Spring calcula page = offset / limit (redondeado)
        // Usamos offset directo porque limit puede no dividir exactamente.
        // La forma más sencilla con Spring Data es pageNumber = offset/limit.
        // Para offset arbitrario usamos el método @Query con parámetros nativos.
        LocalDateTime desdeDate = null;
        LocalDateTime hastaDate = null;

        try {
            if (desde != null && !desde.isBlank()) {
                desdeDate = LocalDate.parse(desde).atStartOfDay();
            }
            if (hasta != null && !hasta.isBlank()) {
                hastaDate = LocalDate.parse(hasta).atTime(LocalTime.MAX);
            }
        } catch (Exception e) {
            log.warn("Formato de fecha inválido: desde={} hasta={}", desde, hasta);
        }

        // Ordenar por id DESC (más recientes primero) y paginar
        Pageable pageable = PageRequest.of(
                offset / limit,   // número de página
                limit,            // tamaño de página
                Sort.by(Sort.Direction.DESC, "id")
        );

        return alertRepository.findWithFiltersPaged(
                tipo, ruta, desdeDate, hastaDate, pageable);
    }

    // Mantener para compatibilidad con otros usos internos
    public List<Alert> getAlertasWithFilters(
            String tipo, String ruta, String desde, String hasta) {

        LocalDateTime desdeDate = null;
        LocalDateTime hastaDate = null;

        try {
            if (desde != null && !desde.isBlank()) {
                desdeDate = LocalDate.parse(desde).atStartOfDay();
            }
            if (hasta != null && !hasta.isBlank()) {
                hastaDate = LocalDate.parse(hasta).atTime(LocalTime.MAX);
            }
        } catch (Exception e) {
            log.warn("Formato de fecha inválido: desde={} hasta={}", desde, hasta);
        }

        return alertRepository.findWithFilters(tipo, ruta, desdeDate, hastaDate);
    }
}