package com.fim.fim_backend.repository;

import com.fim.fim_backend.model.ConfigRule;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface ConfigRuleRepository extends JpaRepository<ConfigRule, Long> {

    // Para detectar duplicados antes de insertar
    Optional<ConfigRule> findByRuta(String ruta);
}
