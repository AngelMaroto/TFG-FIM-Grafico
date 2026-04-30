package com.fim.fim_backend.model;

import jakarta.persistence.*;
import lombok.Data;

@Data
@Entity
@Table(name = "Config_Rules")
public class ConfigRule {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "ruta", nullable = false)
    private String ruta;

    @Column(name = "nivel_severidad", nullable = false)
    private String nivelSeveridad = "MEDIA";
}
