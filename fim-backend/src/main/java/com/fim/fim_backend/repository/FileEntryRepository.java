package com.fim.fim_backend.repository;

import com.fim.fim_backend.model.FileEntry;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface FileEntryRepository extends JpaRepository<FileEntry, Long> {
}