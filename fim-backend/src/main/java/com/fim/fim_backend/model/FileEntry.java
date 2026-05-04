package com.fim.fim_backend.model;

import jakarta.persistence.*;
import lombok.Data;

@Data
@Entity
@Table(name = "File_Entries")
public class FileEntry {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne
    @JoinColumn(name = "scan_id", nullable = false)
    private Scan scan;

    @Column(name = "ruta_archivo", nullable = false)
    private String rutaArchivo;

    @Column(name = "nombre_archivo", nullable = false)
    private String nombreArchivo;

    @Column(name = "hash_actual")
    private String hashActual;

    @Column(name = "hash_anterior")
    private String hashAnterior;

    @Column(name = "tamanio")
    private Integer tamanio;

    @Column(name = "permisos")
    private String permisos;
}