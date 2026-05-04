package com.fim.fim_backend.dto;

import lombok.Data;

@Data
public class EventoDTO {
    private String tipoCambio;
    private String rutaArchivo;
    private String nombreArchivo;
    private String hashActual;
    private String hashAnterior;
    private String permisos;
    private Integer tamanio;
    private String timestamp;
    private String severidad;
    private ScanRef scan;

    @Data
    public static class ScanRef {
        private Long id;
    }
}