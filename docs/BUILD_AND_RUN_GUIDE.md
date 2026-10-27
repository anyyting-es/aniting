# Guía de Ejecución y Compilación (Con / Sin Servidor)

Esta guía detalla los comandos y scripts automatizados para ejecutar y compilar Aniting en sus dos modos operativos: **Completo (Con servidor Go embebido)** y **Cliente Ligero (Sin backend Go)**.

---

## 1. Modos de Operación

| Modo | Descripción | Tamaño APK | Caso de uso principal |
| :--- | :--- | :--- | :--- |
| **Completo (Full)** | Incluye el runtime Go (`seanime.aar`), SQLite GORM y motor Torrent embebido. Arranca el servidor local automáticamente. | ~100–120 MB por ABI | Móviles, Smart TVs autónomas, Waydroid, Emuladores Android. |
| **Cliente Ligero (Client-Only)** | Excluye el backend Go (`seanime.aar`). Se conecta vía Wi-Fi / LAN o Internet a un servidor Seanime externo (PC). | ~30–35 MB por ABI | Smart TVs de bajos recursos, teléfonos con almacenamiento limitado, clientes remotos. |

---

## 2. Scripts Rápidos de Ejecución (Modo Debug)

### A. Ejecutar con Servidor Go Embebido
Inicia la aplicación incluyendo las librerías nativas del backend Go y auto-inicia el servidor local:
```bash
# Linux / macOS:
./run_debug_server.sh

# Para especificar dispositivo explícito (ej. Waydroid, emulador o Linux desktop):
./run_debug_server.sh -d 192.168.240.112:5555
./run_debug_server.sh -d linux

# Windows:
run_debug_server.bat
```

*Comando Flutter directo equivalente:*
```bash
flutter run -PincludeBackend=true
```

---

### B. Ejecutar Sin Servidor (Modo Cliente Ligero)
Inicia la app omitiendo el empaquetado del servidor Go. La app arranca en modo cliente remoto sin demoras de inicio local:
```bash
# Linux / macOS:
./run_debug_client.sh

# Especificando dispositivo:
./run_debug_client.sh -d 192.168.240.112:5555
./run_debug_client.sh -d linux

# Windows:
run_debug_client.bat
```

*Comando Flutter directo equivalente:*
```bash
flutter run --dart-define=NO_BACKEND=true -PincludeBackend=false
```

---

## 3. Scripts de Compilación (Modo Release)

### A. Compilar APK Completo (Con Servidor Go)
Genera APKs optimizados y divididos por arquitectura (`split-per-abi`) con el backend Go integrado:
```bash
# Linux / macOS:
./build_apk_full.sh

# Windows:
build_apk_full.bat
```
**Salida (`build/app/outputs/flutter-apk/`)**:
- `app-arm64-v8a-release.apk` (Smartphones modernos y Google TV)
- `app-x86_64-release.apk` (Waydroid en PC y emuladores x86_64)
- `app-armeabi-v7a-release.apk` (TV boxes o dispositivos antiguos de 32 bits)

---

### B. Compilar APK Cliente Ligero (Sin Servidor Go)
Genera APKs ultraligeros para operar conectándose a un servidor en red local o remoto:
```bash
# Linux / macOS:
./build_apk_client.sh

# Windows:
build_apk_client.bat
```
**Salida (`build/app/outputs/flutter-apk/`)**:
- `app-arm64-v8a-release.apk` (~33 MB)
- `app-x86_64-release.apk` (~35 MB)
- `app-armeabi-v7a-release.apk` (~30 MB)

---

### C. Compilar Servidor Standalone para Linux Desktop
Compila el binario ejecutable del backend Go para la versión de escritorio de Linux:
```bash
./build_server.sh
```
**Salida**:
- `backend/seanime-server` (Ejecutable nativo para Linux x86_64)

---

## 4. Mecanismo Técnico Interno

1. **Gradle (`android/app/build.gradle.kts`)**:
   - Detecta la propiedad `-PincludeBackend=false` o el define de Dart `NO_BACKEND=true`.
   - Si está deshabilitado, excluye `seanime.aar` de las dependencias (`exclude = ["seanime.aar"]`), reduciendo drásticamente el tamaño del APK y evitando la carga de librerías nativas Go.
2. **Dart (`AppConstants.isNoBackend`)**:
   - Compilado vía `bool.fromEnvironment('NO_BACKEND', defaultValue: false)`.
   - Cuando es `true`, `ServerManager` y `serverNotifierProvider` omiten el ciclo de sondeo y arranque local, dirigiéndose de inmediato a la búsqueda de servidores LAN o configuración remota.
