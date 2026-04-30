-- ============================================================
-- DATOS DE PRUEBA FIM - Demo Timeline 28/04/2026
-- ============================================================

-- Reglas de configuración (directorios típicos Linux)
INSERT INTO Config_Rules (ruta, nivel_severidad) VALUES
  ('/etc',          'ALTA'),
  ('/bin',          'ALTA'),
  ('/usr/bin',      'ALTA'),
  ('/home',         'MEDIA'),
  ('/var/log',      'BAJA'),
  ('/tmp',          'BAJA');

-- ============================================================
-- SCAN 1 - 21/04/2026 09:00 - Baseline limpio
-- ============================================================
INSERT INTO Scans (fecha_ejecucion, hostname, resumen_cambios) VALUES
  ('2026-04-21 09:00:00', 'angel-server', '0 nuevos, 0 modificados, 0 eliminados');

-- ============================================================
-- SCAN 2 - 22/04/2026 09:00 - Primer incidente: /etc
-- ============================================================
INSERT INTO Scans (fecha_ejecucion, hostname, resumen_cambios) VALUES
  ('2026-04-22 09:00:00', 'angel-server', '1 nuevo, 2 modificados, 0 eliminados');

INSERT INTO File_Entries (scan_id, ruta_archivo, hash_actual, tamaño, permisos, nombre_archivo) VALUES
  (2, '/etc/passwd',       'a3f1c2d4e5b6789012345678901234567890abcd', 2048, '644', 'passwd'),
  (2, '/etc/ssh/sshd_config', 'b4e2d3c5f6a7890123456789012345678901bcde', 3712, '600', 'sshd_config'),
  (2, '/etc/cron.d/backup', 'c5f3e4d6a7b8901234567890123456789012cdef', 512,  '644', 'backup');

INSERT INTO Alerts (scan_id, file_entry_id, config_rules_id, tipo_cambio, severidad, hash_anterior) VALUES
  (2, 1, 1, 'MODIFIED',    'ALTA', 'a1b2c3d4e5f6789012345678901234567890aaaa'),
  (2, 2, 1, 'MODIFIED',    'ALTA', 'b2c3d4e5f6a7890123456789012345678901bbbb'),
  (2, 3, 1, 'NEW',         'ALTA', NULL);

-- ============================================================
-- SCAN 3 - 23/04/2026 09:00 - Actividad en /home y /var/log
-- ============================================================
INSERT INTO Scans (fecha_ejecucion, hostname, resumen_cambios) VALUES
  ('2026-04-23 09:00:00', 'angel-server', '2 nuevos, 1 modificado, 0 eliminados');

INSERT INTO File_Entries (scan_id, ruta_archivo, hash_actual, tamaño, permisos, nombre_archivo) VALUES
  (3, '/home/angel/.bashrc',     'd6a4f5e7b8c9012345678901234567890123defg', 3200, '644', '.bashrc'),
  (3, '/home/angel/.ssh/authorized_keys', 'e7b5a6f8c9d0123456789012345678901234efgh', 1024, '600', 'authorized_keys'),
  (3, '/var/log/syslog',         'f8c6b7a9d0e1234567890123456789012345fghi', 102400, '640', 'syslog');

INSERT INTO Alerts (scan_id, file_entry_id, config_rules_id, tipo_cambio, severidad, hash_anterior) VALUES
  (3, 4, 4, 'MODIFIED', 'MEDIA', 'd1e2f3a4b5c6789012345678901234567890dddd'),
  (3, 5, 4, 'NEW',      'MEDIA', NULL),
  (3, 6, 5, 'MODIFIED', 'BAJA',  'f1a2b3c4d5e6789012345678901234567890ffff');

-- ============================================================
-- SCAN 4 - 24/04/2026 09:00 - Binario sospechoso en /usr/bin
-- ============================================================
INSERT INTO Scans (fecha_ejecucion, hostname, resumen_cambios) VALUES
  ('2026-04-24 09:00:00', 'angel-server', '1 nuevo, 0 modificados, 0 eliminados');

INSERT INTO File_Entries (scan_id, ruta_archivo, hash_actual, tamaño, permisos, nombre_archivo) VALUES
  (4, '/usr/bin/netcat',  'a9d7c8b0e1f2345678901234567890123456ghij', 40960, '755', 'netcat');

INSERT INTO Alerts (scan_id, file_entry_id, config_rules_id, tipo_cambio, severidad, hash_anterior) VALUES
  (4, 7, 3, 'NEW', 'ALTA', NULL);

-- ============================================================
-- SCAN 5 - 25/04/2026 09:00 - Fichero eliminado en /etc
-- ============================================================
INSERT INTO Scans (fecha_ejecucion, hostname, resumen_cambios) VALUES
  ('2026-04-25 09:00:00', 'angel-server', '0 nuevos, 1 modificado, 1 eliminado');

INSERT INTO File_Entries (scan_id, ruta_archivo, hash_actual, tamaño, permisos, nombre_archivo) VALUES
  (5, '/etc/hosts',           'b0e8d9c1f2a3456789012345678901234567hijk', 312,  '644', 'hosts'),
  (5, '/etc/cron.d/backup',   NULL,                                        NULL, NULL,  'backup');

INSERT INTO Alerts (scan_id, file_entry_id, config_rules_id, tipo_cambio, severidad, hash_anterior) VALUES
  (5, 8,  1, 'MODIFIED', 'ALTA', 'b9f0a1b2c3d4567890123456789012345678hhhh'),
  (5, 9,  1, 'DELETED',  'ALTA', 'c5f3e4d6a7b8901234567890123456789012cdef');

-- ============================================================
-- SCAN 6 - 26/04/2026 09:00 - Cambio de permisos crítico
-- ============================================================
INSERT INTO Scans (fecha_ejecucion, hostname, resumen_cambios) VALUES
  ('2026-04-26 09:00:00', 'angel-server', '0 nuevos, 0 modificados, 0 eliminados, 2 permisos');

INSERT INTO File_Entries (scan_id, ruta_archivo, hash_actual, tamaño, permisos, nombre_archivo) VALUES
  (6, '/etc/sudoers',  'c1f9e0d2a3b4567890123456789012345678ijkl', 1024, '777', 'sudoers'),
  (6, '/bin/su',       'd2a0f1e3b4c5678901234567890123456789jklm', 36864, '777', 'su');

INSERT INTO Alerts (scan_id, file_entry_id, config_rules_id, tipo_cambio, severidad, hash_anterior) VALUES
  (6, 10, 1, 'PERMISSIONS', 'ALTA', NULL),
  (6, 11, 2, 'PERMISSIONS', 'ALTA', NULL);

-- ============================================================
-- SCAN 7 - 28/04/2026 09:00 - Hoy: actividad mixta
-- ============================================================
INSERT INTO Scans (fecha_ejecucion, hostname, resumen_cambios) VALUES
  ('2026-04-28 09:00:00', 'angel-server', '1 nuevo, 2 modificados, 1 eliminado');

INSERT INTO File_Entries (scan_id, ruta_archivo, hash_actual, tamaño, permisos, nombre_archivo) VALUES
  (7, '/etc/nginx/nginx.conf',  'e3b1a2d4c5e6789012345678901234567890klmn', 2048, '644', 'nginx.conf'),
  (7, '/home/angel/script.sh',  'f4c2b3e5d6f7890123456789012345678901lmno', 512,  '755', 'script.sh'),
  (7, '/var/log/auth.log',      'a5d3c4f6e7a8901234567890123456789012mnop', 204800, '640', 'auth.log'),
  (7, '/tmp/tmpfile.sh',        NULL,                                         NULL,  NULL,  'tmpfile.sh');

INSERT INTO Alerts (scan_id, file_entry_id, config_rules_id, tipo_cambio, severidad, hash_anterior) VALUES
  (7, 12, 1, 'NEW',      'ALTA', NULL),
  (7, 13, 4, 'MODIFIED', 'MEDIA', 'f9d0e1a2b3c4567890123456789012345678llll'),
  (7, 14, 5, 'MODIFIED', 'BAJA',  'a0e1f2b3c4d5678901234567890123456789mmmm'),
  (7, 15, 6, 'DELETED',  'BAJA',  'b1f2a3c4d5e6789012345678901234567890nnnn');

