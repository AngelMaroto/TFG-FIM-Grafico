package com.fim.fim_backend.repository;

import com.fim.fim_backend.model.Alert;
import com.fim.fim_backend.model.Scan;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface AlertRepository extends JpaRepository<Alert, Long> {
    List<Alert> findByScan(Scan scan);
    List<Alert> findByTipoCambio(String tipoCambio);
    List<Alert> findByRutaArchivoContaining(String ruta);
}
