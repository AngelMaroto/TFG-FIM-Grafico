package com.fim.fim_backend.repository;

import com.fim.fim_backend.model.AgentCommand;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface AgentCommandRepository extends JpaRepository<AgentCommand, Long> {

    // El agente consulta si hay algún comando PENDING
    Optional<AgentCommand> findFirstByEstadoOrderByCreadoEnAsc(String estado);
}