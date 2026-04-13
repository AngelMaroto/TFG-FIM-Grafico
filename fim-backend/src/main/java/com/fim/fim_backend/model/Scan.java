package com.fim.fim_backend.model;

import jakarta.persistence.*;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@Entity
@Table(name = "Scans")
public class Scan {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "fecha_ejecucion", nullable = false)
    private LocalDateTime fechaEjecucion = LocalDateTime.now();

    @Column(name = "hostname", nullable = false)
    private String hostname;

    @Column(name = "resumen_cambios")
    private String resumenCambios;
}