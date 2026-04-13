package com.fim.fim_backend.model;

import jakarta.persistence.*;
import lombok.Data;

@Data
@Entity
@Table(name = "Alerts")
public class Alert {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne
    @JoinColumn(name = "scan_id", nullable = false)
    private Scan scan;

    @Column(name = "tipo_cambio", nullable = false)
    private String tipoCambio;

    @Column(name = "ruta_archivo", nullable = false)
    private String rutaArchivo;

    @Column(name = "nombre_archivo", nullable = false)
    private String nombreArchivo;

    @Column(name = "severidad", nullable = false)
    private String severidad = "MEDIA";

    @Column(name = "hash_anterior")
    private String hashAnterior;

    @Column(name = "hash_actual")
    private String hashActual;

    @Column(name = "permisos")
    private String permisos;

    @Column(name = "timestamp", nullable = false)
    private String timestamp;
}
