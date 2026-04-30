package com.fim.fim_backend.model;

import jakarta.persistence.*;
import lombok.Data;

@Data
@Entity
@Table(name = "System_Config")
public class SystemConfig {

    @Id
    @Column(name = "config_key", nullable = false)
    private String configKey;

    @Column(name = "config_value", nullable = false)
    private String configValue;

    @Column(name = "descripcion")
    private String descripcion;
}