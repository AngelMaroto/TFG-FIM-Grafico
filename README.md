# 🔍 FIM Gráfico para Auditoría de Sistemas Linux

**Trabajo de Fin de Grado — DAM IFC02S**  
Ángel Maroto García

---

## 📋 Descripción

Aplicación multiplataforma que permite monitorizar la integridad del sistema de archivos de un servidor Linux, visualizando los cambios detectados como un **grafo de nodos interactivo** y una **línea temporal de eventos**.

El sistema detecta modificaciones, nuevos archivos y eliminaciones en tiempo real, registrando también cambios en metadatos y permisos.

---

## 🏗️ Arquitectura
```
┌─────────────────┐        API REST / WebSocket        ┌──────────────────┐
│  Agente FIM     │ ──────────────────────────────────▶ │    Backend       │
│  (Python)       │                                     │  (Spring Boot)   │
│                 │                                     │  (SQLite)        │
└─────────────────┘                                     └────────┬─────────┘
      AIDE                                                       │
 Motor de detección                                              │ API REST
                                                                 ▼
                                                      ┌──────────────────┐
                                                      │   Frontend       │
                                                      │   (Flutter)      │
                                                      │  Grafo + Timeline│
                                                      └──────────────────┘
```

---

## 🧩 Componentes

### 🐍 Agente FIM (Python)
- Orquesta AIDE (Advanced Intrusion Detection Environment)
- Comandos: `init`, `check`, `report`
- Detecta eventos: `NEW`, `DELETED`, `MODIFIED`
- Envía eventos al backend vía API REST

### ☕ Backend (Java / Spring Boot)
- API REST + WebSockets
- Persistencia con SQLite (Spring Data JPA)
- Gestión del historial de eventos y snapshots

### 🦋 Frontend (Flutter / Dart)
- Grafo de nodos interactivo del sistema de archivos
- Línea temporal de eventos
- Compatible con escritorio, web y móvil

---

## 🗂️ Estructura del repositorio
```
tfg-fim-grafico/
├── agent/          # Agente FIM en Python
├── backend/        # API REST en Spring Boot
├── frontend/       # App Flutter
└── docs/           # Memoria y documentación
```

---

## 🚀 Requisitos

| Componente | Tecnología |
|------------|-----------|
| Agente | Python 3.10+, AIDE |
| Backend | Java 17+, Maven |
| Frontend | Flutter 3.x, Dart |
| Sistema monitorizado | Linux (Ubuntu Server recomendado) |

---

## 📅 Estado del proyecto

> 🚧 En desarrollo — TFG en curso

---

## ⚠️ Dependencias externas
Este proyecto requiere AIDE (licencia GPL v2) instalado 
en el sistema. AIDE no está incluido en este repositorio.

---

## 📄 Licencia

MIT License — ver [LICENSE](LICENSE)
