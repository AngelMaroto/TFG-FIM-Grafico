-- ============================================================
-- DATOS DE PRUEBA FIM - Demo Timeline 28/04/2026
-- Adaptado al esquema real (alerts + scans)
-- ============================================================

-- SCAN 1 - 21/04/2026 - Baseline limpio (sin alertas)
INSERT INTO scans (id, fecha_ejecucion, hostname, resumen_cambios) VALUES
  (1, '2026-04-21 09:00:00', 'angel-server', '0 nuevos, 0 modificados, 0 eliminados');

-- SCAN 2 - 22/04/2026 - Incidente en /etc
INSERT INTO scans (id, fecha_ejecucion, hostname, resumen_cambios) VALUES
  (2, '2026-04-22 09:00:00', 'angel-server', '1 nuevo, 2 modificados, 0 eliminados');

INSERT INTO alerts (id, scan_id, ruta_archivo, nombre_archivo, tipo_cambio, severidad, timestamp, hash_actual, hash_anterior, permisos) VALUES
  (1,  2, '/etc/passwd',          'passwd',      'MODIFIED',    'ALTA',  '2026-04-22 09:01:12', 'a3f1c2d4e5b678901234', 'a1b2c3d4e5f678901234', '644'),
  (2,  2, '/etc/ssh/sshd_config', 'sshd_config', 'MODIFIED',    'ALTA',  '2026-04-22 09:01:15', 'b4e2d3c5f6a789012345', 'b2c3d4e5f6a789012345', '600'),
  (3,  2, '/etc/cron.d/backup',   'backup',      'NEW',         'ALTA',  '2026-04-22 09:01:18', 'c5f3e4d6a7b890123456', NULL,                   '644');

-- SCAN 3 - 23/04/2026 - Actividad en /home y /var/log
INSERT INTO scans (id, fecha_ejecucion, hostname, resumen_cambios) VALUES
  (3, '2026-04-23 09:00:00', 'angel-server', '1 nuevo, 1 modificado, 0 eliminados');

INSERT INTO alerts (id, scan_id, ruta_archivo, nombre_archivo, tipo_cambio, severidad, timestamp, hash_actual, hash_anterior, permisos) VALUES
  (4,  3, '/home/angel/.bashrc',              '.bashrc',          'MODIFIED', 'MEDIA', '2026-04-23 09:01:05', 'd6a4f5e7b8c901234567', 'd1e2f3a4b5c678901234', '644'),
  (5,  3, '/home/angel/.ssh/authorized_keys', 'authorized_keys',  'NEW',      'MEDIA', '2026-04-23 09:01:09', 'e7b5a6f8c9d012345678', NULL,                   '600'),
  (6,  3, '/var/log/syslog',                  'syslog',           'MODIFIED', 'BAJA',  '2026-04-23 09:01:22', 'f8c6b7a9d0e123456789', 'f1a2b3c4d5e678901234', '640');

-- SCAN 4 - 24/04/2026 - Binario sospechoso en /usr/bin
INSERT INTO scans (id, fecha_ejecucion, hostname, resumen_cambios) VALUES
  (4, '2026-04-24 09:00:00', 'angel-server', '1 nuevo, 0 modificados, 0 eliminados');

INSERT INTO alerts (id, scan_id, ruta_archivo, nombre_archivo, tipo_cambio, severidad, timestamp, hash_actual, hash_anterior, permisos) VALUES
  (7,  4, '/usr/bin/netcat', 'netcat', 'NEW', 'ALTA', '2026-04-24 09:01:33', 'a9d7c8b0e1f234567890', NULL, '755');

-- SCAN 5 - 25/04/2026 - Fichero eliminado en /etc
INSERT INTO scans (id, fecha_ejecucion, hostname, resumen_cambios) VALUES
  (5, '2026-04-25 09:00:00', 'angel-server', '0 nuevos, 1 modificado, 1 eliminado');

INSERT INTO alerts (id, scan_id, ruta_archivo, nombre_archivo, tipo_cambio, severidad, timestamp, hash_actual, hash_anterior, permisos) VALUES
  (8,  5, '/etc/hosts',         'hosts',  'MODIFIED', 'ALTA', '2026-04-25 09:01:08', 'b0e8d9c1f2a345678901', 'b9f0a1b2c3d456789012', '644'),
  (9,  5, '/etc/cron.d/backup', 'backup', 'DELETED',  'ALTA', '2026-04-25 09:01:11', NULL,                   'c5f3e4d6a7b890123456', '644');

-- SCAN 6 - 26/04/2026 - Cambio de permisos crítico
INSERT INTO scans (id, fecha_ejecucion, hostname, resumen_cambios) VALUES
  (6, '2026-04-26 09:00:00', 'angel-server', '0 nuevos, 0 modificados, 2 cambios de permisos');

INSERT INTO alerts (id, scan_id, ruta_archivo, nombre_archivo, tipo_cambio, severidad, timestamp, hash_actual, hash_anterior, permisos) VALUES
  (10, 6, '/etc/sudoers', 'sudoers', 'PERMISSIONS', 'ALTA', '2026-04-26 09:01:02', 'c1f9e0d2a3b456789012', NULL, '777'),
  (11, 6, '/bin/su',      'su',      'PERMISSIONS', 'ALTA', '2026-04-26 09:01:05', 'd2a0f1e3b4c567890123', NULL, '777');

-- SCAN 7 - 28/04/2026 - Hoy: actividad mixta
INSERT INTO scans (id, fecha_ejecucion, hostname, resumen_cambios) VALUES
  (7, '2026-04-28 09:00:00', 'angel-server', '1 nuevo, 2 modificados, 1 eliminado');

INSERT INTO alerts (id, scan_id, ruta_archivo, nombre_archivo, tipo_cambio, severidad, timestamp, hash_actual, hash_anterior, permisos) VALUES
  (12, 7, '/etc/nginx/nginx.conf', 'nginx.conf', 'NEW',      'ALTA',  '2026-04-28 09:01:14', 'e3b1a2d4c5e678901234', NULL,                   '644'),
  (13, 7, '/home/angel/script.sh', 'script.sh',  'MODIFIED', 'MEDIA', '2026-04-28 09:01:17', 'f4c2b3e5d6f789012345', 'f9d0e1a2b3c456789012', '755'),
  (14, 7, '/var/log/auth.log',     'auth.log',   'MODIFIED', 'BAJA',  '2026-04-28 09:01:21', 'a5d3c4f6e7a890123456', 'a0e1f2b3c4d567890123', '640'),
  (15, 7, '/tmp/tmpfile.sh',       'tmpfile.sh', 'DELETED',  'BAJA',  '2026-04-28 09:01:25', NULL,                   'b1f2a3c4d5e678901234', '755');
