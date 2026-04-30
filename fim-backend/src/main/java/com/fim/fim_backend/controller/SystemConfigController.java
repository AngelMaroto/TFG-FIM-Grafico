package com.fim.fim_backend.controller;

import com.fim.fim_backend.model.SystemConfig;
import com.fim.fim_backend.repository.SystemConfigRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/api/config/system")
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
public class SystemConfigController {

    private final SystemConfigRepository systemConfigRepository;

    // GET /api/config/system — obtener todas las claves
    @GetMapping
    public ResponseEntity<List<SystemConfig>> getAll() {
        return ResponseEntity.ok(systemConfigRepository.findAll());
    }

    // GET /api/config/system/{key} — obtener un valor concreto
    @GetMapping("/{key}")
    public ResponseEntity<SystemConfig> getByKey(@PathVariable String key) {
        return systemConfigRepository.findById(key)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    // PUT /api/config/system/{key} — crear o actualizar un valor
    @PutMapping("/{key}")
    public ResponseEntity<SystemConfig> upsert(
            @PathVariable String key,
            @RequestBody Map<String, String> body) {

        String value = body.get("value");
        String desc  = body.get("descripcion");

        if (value == null || value.isBlank()) {
            return ResponseEntity.badRequest().build();
        }

        SystemConfig config = systemConfigRepository.findById(key)
                .orElse(new SystemConfig());
        config.setConfigKey(key);
        config.setConfigValue(value);
        if (desc != null) config.setDescripcion(desc);

        SystemConfig saved = systemConfigRepository.save(config);
        log.info("Config actualizada: {} = {}", key, value);
        return ResponseEntity.ok(saved);
    }

    // DELETE /api/config/system/{key} — eliminar una clave
    @DeleteMapping("/{key}")
    public ResponseEntity<Void> delete(@PathVariable String key) {
        if (!systemConfigRepository.existsById(key)) {
            return ResponseEntity.notFound().build();
        }
        systemConfigRepository.deleteById(key);
        log.info("Config eliminada: {}", key);
        return ResponseEntity.noContent().build();
    }
}