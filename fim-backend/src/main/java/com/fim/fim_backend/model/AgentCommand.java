package com.fim.fim_backend.model;

import jakarta.persistence.*;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@Entity
@Table(name = "Agent_Commands")
public class AgentCommand {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "tipo", nullable = false)
    private String tipo = "CHECK";

    @Column(name = "estado", nullable = false)
    private String estado = "PENDING"; // PENDING | CONSUMED

    @Column(name = "creado_en", nullable = false)
    private LocalDateTime creadoEn = LocalDateTime.now();

    @Column(name = "consumido_en")
    private LocalDateTime consumidoEn;
}