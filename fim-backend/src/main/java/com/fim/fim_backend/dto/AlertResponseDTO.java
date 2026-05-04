package com.fim.fim_backend.dto;

import com.fim.fim_backend.model.Alert;

import java.time.LocalDateTime;

public class AlertResponseDTO {

    private Long id;
    private Long scanId;
    private LocalDateTime fechaEjecucion;  // de Scans, via Alert -> FileEntry -> Scan

    // Datos del fichero (FileEntry)
    private String rutaArchivo;
    private String nombreArchivo;
    private String hashActual;
    private String hashAnterior;
    private Integer tamanio;
    private String permisos;

    // Datos de la alerta
    private String tipoCambio;
    private String severidad;

    // Constructor desde entidad Alert
    public static AlertResponseDTO from(Alert alert) {
        AlertResponseDTO dto = new AlertResponseDTO();
        dto.id             = alert.getId();
        dto.scanId         = alert.getScan().getId();
        dto.fechaEjecucion = alert.getScan().getFechaEjecucion();

        if (alert.getFileEntry() != null) {
            dto.rutaArchivo   = alert.getFileEntry().getRutaArchivo();
            dto.nombreArchivo = alert.getFileEntry().getNombreArchivo();
            dto.hashActual    = alert.getFileEntry().getHashActual();
            dto.hashAnterior  = alert.getFileEntry().getHashAnterior();  // ← aquí, no en Alert
            dto.tamanio       = alert.getFileEntry().getTamanio();       // Integer
            dto.permisos      = alert.getFileEntry().getPermisos();
        }

        dto.tipoCambio = alert.getTipoCambio();
        dto.severidad  = alert.getSeveridad();

        return dto;
    }

    // Getters (sin setters — DTO de solo lectura)
    public Long getId()                    { return id; }
    public Long getScanId()                { return scanId; }
    public LocalDateTime getFechaEjecucion(){ return fechaEjecucion; }
    public String getRutaArchivo()         { return rutaArchivo; }
    public String getNombreArchivo()       { return nombreArchivo; }
    public String getHashActual()          { return hashActual; }
    public String getHashAnterior()        { return hashAnterior; }
    public Integer getTamanio()               { return tamanio; }
    public String getPermisos()            { return permisos; }
    public String getTipoCambio()          { return tipoCambio; }
    public String getSeveridad()           { return severidad; }
}