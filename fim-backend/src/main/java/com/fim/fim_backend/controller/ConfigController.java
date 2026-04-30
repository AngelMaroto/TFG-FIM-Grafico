package com.fim.fim_backend.controller;

import com.fim.fim_backend.dto.ConfigRuleDTO;
import com.fim.fim_backend.model.ConfigRule;
import com.fim.fim_backend.repository.ConfigRuleRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.Optional;

@Slf4j
@RestController
@RequestMapping("/api/config")
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
public class ConfigController {

    private final ConfigRuleRepository configRuleRepository;

    // GET /api/config/rules — obtener todas las reglas
    @GetMapping("/rules")
    public ResponseEntity<List<ConfigRule>> getRules() {
        return ResponseEntity.ok(configRuleRepository.findAll());
    }

    // POST /api/config/rules — crear nueva regla
    @PostMapping("/rules")
    public ResponseEntity<?> createRule(@RequestBody ConfigRuleDTO dto) {

        // Validación básica
        if (dto.getRuta() == null || dto.getRuta().isBlank()) {
            return ResponseEntity.badRequest()
                    .body(Map.of("error", "La ruta no puede estar vacía"));
        }

        // Comprobar duplicado
        Optional<ConfigRule> existing = configRuleRepository.findByRuta(dto.getRuta());
        if (existing.isPresent()) {
            return ResponseEntity.status(HttpStatus.CONFLICT)
                    .body(Map.of("error", "Ya existe una regla para la ruta: " + dto.getRuta()));
        }

        ConfigRule rule = new ConfigRule();
        rule.setRuta(dto.getRuta());
        rule.setNivelSeveridad(
                dto.getNivelSeveridad() != null ? dto.getNivelSeveridad() : "MEDIA"
        );

        ConfigRule saved = configRuleRepository.save(rule);
        log.info("Nueva regla creada: {} → {}", saved.getRuta(), saved.getNivelSeveridad());
        return ResponseEntity.status(HttpStatus.CREATED).body(saved);
    }

    // PUT /api/config/rules/{id} — actualizar severidad de una regla existente
    @PutMapping("/rules/{id}")
    public ResponseEntity<?> updateRule(@PathVariable Long id,
                                        @RequestBody ConfigRuleDTO dto) {
        return configRuleRepository.findById(id)
                .map(rule -> {
                    if (dto.getRuta() != null && !dto.getRuta().isBlank()) {
                        rule.setRuta(dto.getRuta());
                    }
                    if (dto.getNivelSeveridad() != null) {
                        rule.setNivelSeveridad(dto.getNivelSeveridad());
                    }
                    ConfigRule updated = configRuleRepository.save(rule);
                    log.info("Regla {} actualizada: {} → {}",
                            id, updated.getRuta(), updated.getNivelSeveridad());
                    return ResponseEntity.ok(updated);
                })
                .orElse(ResponseEntity.notFound().build());
    }

    // DELETE /api/config/rules/{id} — eliminar una regla
    @DeleteMapping("/rules/{id}")
    public ResponseEntity<?> deleteRule(@PathVariable Long id) {
        if (!configRuleRepository.existsById(id)) {
            return ResponseEntity.notFound().build();
        }
        configRuleRepository.deleteById(id);
        log.info("Regla {} eliminada", id);
        return ResponseEntity.noContent().build();
    }
}