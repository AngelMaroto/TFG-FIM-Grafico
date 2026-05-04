package com.fim.fim_backend.repository;

import com.fim.fim_backend.model.Alert;
import com.fim.fim_backend.model.Scan;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import org.springframework.data.jpa.repository.EntityGraph;
import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface AlertRepository extends JpaRepository<Alert, Long> {

    List<Alert> findByScan(Scan scan);
    List<Alert> findByTipoCambio(String tipoCambio);
    List<Alert> findByFileEntry_RutaArchivoContaining(String ruta);

    @EntityGraph(attributePaths = {"scan", "fileEntry"})
    @Query("SELECT a FROM Alert a WHERE " +
            "(:tipo IS NULL OR a.tipoCambio = :tipo) AND " +
            "(:ruta IS NULL OR a.fileEntry.rutaArchivo LIKE %:ruta%) AND " +
            "(:desde IS NULL OR a.scan.fechaEjecucion >= :desde) AND " +
            "(:hasta IS NULL OR a.scan.fechaEjecucion <= :hasta) " +
            "ORDER BY a.scan.fechaEjecucion DESC")
    List<Alert> findWithFilters(
            @Param("tipo")  String tipo,
            @Param("ruta")  String ruta,
            @Param("desde") LocalDateTime desde,
            @Param("hasta") LocalDateTime hasta
    );


    @EntityGraph(attributePaths = {"scan", "fileEntry"})
    @Query("SELECT a FROM Alert a WHERE " +
            "(:tipo IS NULL OR a.tipoCambio = :tipo) AND " +
            "(:ruta IS NULL OR a.fileEntry.rutaArchivo LIKE %:ruta%) AND " +
            "(:desde IS NULL OR a.scan.fechaEjecucion >= :desde) AND " +
            "(:hasta IS NULL OR a.scan.fechaEjecucion <= :hasta)")
    List<Alert> findWithFiltersPaged(
            @Param("tipo")  String tipo,
            @Param("ruta")  String ruta,
            @Param("desde") LocalDateTime desde,
            @Param("hasta") LocalDateTime hasta,
            Pageable pageable
    );
}