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

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "file_entry_id", nullable = false)
    private FileEntry fileEntry;

    @Column(name = "tipo_cambio", nullable = false)
    private String tipoCambio;

    @Column(name = "severidad", nullable = false)
    private String severidad = "MEDIA";

    @Column(name = "timestamp", nullable = false)
    private String timestamp;
}