package com.fim.fim_backend.controller;

import com.fim.fim_backend.model.AgentCommand;
import com.fim.fim_backend.repository.AgentCommandRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.Map;
import java.util.Optional;

@Slf4j
@RestController
@RequestMapping("/api/agent")
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
public class AgentController {

    private final AgentCommandRepository commandRepository;

    // POST /api/agent/check — Flutter solicita check manual
    @PostMapping("/check")
    public ResponseEntity<Map<String, Object>> requestCheck() {
        AgentCommand cmd = new AgentCommand();
        cmd.setTipo("CHECK");
        cmd.setEstado("PENDING");
        AgentCommand saved = commandRepository.save(cmd);
        log.info("Check manual solicitado desde el frontend (cmd id={})", saved.getId());
        return ResponseEntity.ok(Map.of(
                "id",      saved.getId(),
                "estado",  saved.getEstado(),
                "mensaje", "Check solicitado. El agente lo ejecutará en su próximo ciclo."
        ));
    }

    // GET /api/agent/pending — el agente consulta si hay comandos pendientes
    @GetMapping("/pending")
    public ResponseEntity<Map<String, Object>> getPending() {
        Optional<AgentCommand> pending =
                commandRepository.findFirstByEstadoOrderByCreadoEnAsc("PENDING");

        if (pending.isPresent()) {
            AgentCommand cmd = pending.get();
            return ResponseEntity.ok(Map.of(
                    "pending", true,
                    "id",      cmd.getId(),
                    "tipo",    cmd.getTipo()
            ));
        }
        return ResponseEntity.ok(Map.of("pending", false));
    }

    // PUT /api/agent/commands/{id}/consumed — el agente marca el comando como consumido
    @PutMapping("/commands/{id}/consumed")
    public ResponseEntity<Map<String, Object>> markConsumed(@PathVariable Long id) {
        Optional<AgentCommand> found = commandRepository.findById(id);
        if (found.isEmpty()) {
            return ResponseEntity.notFound().build();
        }
        AgentCommand cmd = found.get();
        cmd.setEstado("CONSUMED");
        cmd.setConsumidoEn(LocalDateTime.now());
        commandRepository.save(cmd);
        log.info("Comando {} marcado como CONSUMED", id);
        return ResponseEntity.ok(Map.of("id", id, "estado", "CONSUMED"));
    }
}