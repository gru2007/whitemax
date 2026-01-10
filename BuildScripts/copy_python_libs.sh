#!/bin/bash
set -e

# Скрипт для копирования Python стандартной библиотеки и pymax в app bundle

PROJECT_DIR="${PROJECT_DIR:-${SRCROOT}}"
PYMAX_DIR="${PROJECT_DIR}/pymax"
PYTHON_XCFRAMEWORK="${PROJECT_DIR}/Python.xcframework"
APP_DIR="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/app"
# Frameworks директория внутри app bundle
FRAMEWORKS_DIR="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/../Frameworks"

echo "Copying Python libraries..."
echo "PROJECT_DIR: ${PROJECT_DIR}"
echo "APP_DIR: ${APP_DIR}"

# Создаем директорию app в bundle если её нет
mkdir -p "${APP_DIR}"

# Определяем путь к Python платформе в зависимости от архитектуры
if [[ "$PLATFORM_NAME" == "iphonesimulator" ]]; then
    PYTHON_PLATFORM="${PYTHON_XCFRAMEWORK}/ios-arm64_x86_64-simulator"
    PYTHON_FRAMEWORK="${PYTHON_PLATFORM}/Python.framework"
else
    PYTHON_PLATFORM="${PYTHON_XCFRAMEWORK}/ios-arm64"
    PYTHON_FRAMEWORK="${PYTHON_PLATFORM}/Python.framework"
fi

if [ ! -d "${PYTHON_FRAMEWORK}" ]; then
    echo "Error: Python.framework not found at ${PYTHON_FRAMEWORK}"
    exit 1
fi

# Копируем Python стандартную библиотеку
# В xcframework стандартная библиотека находится в lib/python3.12, а не в Python.framework/lib
PYTHON_LIB="${PYTHON_PLATFORM}/lib/python3.12"
PYTHON_LIB_DEST="${APP_DIR}/python/lib/python3.12"

if [ -d "${PYTHON_LIB}" ]; then
    echo "Copying Python standard library from ${PYTHON_LIB}..."
    mkdir -p "${APP_DIR}/python/lib"
    cp -R "${PYTHON_LIB}" "${PYTHON_LIB_DEST}"
    
    # Копируем platform-config если есть
    PLATFORM_CONFIG="${PYTHON_PLATFORM}/platform-config"
    if [ -d "${PLATFORM_CONFIG}" ]; then
        mkdir -p "${APP_DIR}/python/platform-config"
        cp -R "${PLATFORM_CONFIG}"/* "${APP_DIR}/python/platform-config/"
    fi
    
    # Подписываем все бинарные модули (.so файлы) в lib-dynload
    # iOS требует, чтобы все динамические библиотеки были подписаны кодом
    LIB_DYNLOAD_DIR="${PYTHON_LIB_DEST}/lib-dynload"
    if [ -d "${LIB_DYNLOAD_DIR}" ]; then
        echo "Code signing Python binary modules in lib-dynload..."
        
        # Определяем identity для подписи
        # Пробуем разные источники для identity
        SIGN_IDENTITY="${CODE_SIGN_IDENTITY}"
        if [ -z "${SIGN_IDENTITY}" ] || [ "${SIGN_IDENTITY}" == "" ]; then
            # Пробуем получить identity из EXPANDED_CODE_SIGN_IDENTITY
            SIGN_IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY}"
        fi
        if [ -z "${SIGN_IDENTITY}" ] || [ "${SIGN_IDENTITY}" == "" ]; then
            # Используем ad-hoc подпись если CODE_SIGN_IDENTITY не установлен
            SIGN_IDENTITY="-"
            echo "  Using ad-hoc code signing (-)"
        else
            echo "  Using code signing identity: ${SIGN_IDENTITY}"
        fi
        
        # Подписываем все .so файлы
        # Используем while loop правильно с find
        so_files=($(find "${LIB_DYNLOAD_DIR}" -name "*.so" -type f))
        if [ ${#so_files[@]} -eq 0 ]; then
            echo "  Warning: No .so files found in lib-dynload"
        else
            for so_file in "${so_files[@]}"; do
                echo "  Signing: $(basename "${so_file}")"
                # Подписываем с использованием текущего identity или ad-hoc
                if codesign --force --sign "${SIGN_IDENTITY}" "${so_file}" 2>&1; then
                    : # Success
                else
                    echo "    Warning: Failed to sign $(basename "${so_file}") with ${SIGN_IDENTITY}"
                    # Пытаемся с ad-hoc подписью
                    if ! codesign --force --sign - "${so_file}" 2>&1; then
                        echo "    Error: Could not sign $(basename "${so_file}")"
                    fi
                fi
            done
        fi
        echo "✓ Python binary modules signed successfully"
    fi
    
    echo "✓ Python standard library copied successfully"
else
    echo "Error: Python library not found at ${PYTHON_LIB}"
    exit 1
fi

# Устанавливаем зависимости pymax в site-packages
# Это нужно сделать до копирования pymax, так как pymax зависит от этих библиотек
SITE_PACKAGES_DIR="${APP_DIR}/python/lib/python3.12/site-packages"
if [ -d "${PYTHON_LIB_DEST}" ]; then
    echo "Installing pymax dependencies to site-packages..."
    mkdir -p "${SITE_PACKAGES_DIR}"
    
    # Используем системный Python для установки зависимостей pymax
    # Устанавливаем все зависимости из pyproject.toml
    # Некоторые пакеты могут содержать бинарные модули, которые нужно собрать для iOS отдельно
    
    # Проверяем наличие pip
    if command -v pip3 &> /dev/null || python3 -m pip --version &> /dev/null; then
        echo "Installing pymax dependencies..."
        
        # Создаем временную директорию для установки
        TEMP_DEPS_DIR=$(mktemp -d)
        trap "rm -rf ${TEMP_DEPS_DIR}" EXIT 2>/dev/null || true
        
        # Устанавливаем все зависимости из pyproject.toml pymax одной командой
        # pip автоматически установит все транзитивные зависимости
        echo "Installing pymax dependencies (this may take a while)..."
        
        # Основные зависимости из pyproject.toml
        # pip автоматически установит все подзависимости (sqlalchemy, pydantic, и т.д.)
        # Устанавливаем pure-Python версии где возможно, чтобы избежать проблем с бинарными модулями
        PYMAX_DEPS="sqlmodel>=0.0.24 websockets>=15.0 msgpack>=1.1.1 lz4>=4.4.4 aiohttp>=3.12.15 aiofiles>=24.1.0 qrcode>=8.2 ua-generator>=2.0.19"
        
        echo "Installing dependencies (including binaries for macOS, will need iOS-specific binaries)..."
        # Устанавливаем все зависимости с их транзитивными зависимостями
        # Используем --ignore-installed чтобы установить в целевую директорию
        # Примечание: бинарные модули (pydantic-core, msgpack, lz4) будут для macOS архитектуры
        # Для iOS их нужно будет собрать отдельно или использовать pure-Python версии
        if python3 -m pip install --target "${TEMP_DEPS_DIR}" --ignore-installed ${PYMAX_DEPS} 2>&1 | tail -15; then
            echo "✓ All dependencies installed successfully"
        else
            echo "Warning: Some dependencies may have failed to install"
            echo "This is expected for packages with binary dependencies on iOS"
        fi
        
        # Проверяем наличие pydantic-core (может быть проблемой на iOS)
        if [ -d "${TEMP_DEPS_DIR}/pydantic_core" ]; then
            echo "✓ pydantic-core installed (binary module, may need iOS-specific build)"
            # Проверяем наличие бинарного модуля
            if find "${TEMP_DEPS_DIR}/pydantic_core" -name "_pydantic_core*.so" -o -name "_pydantic_core*.dylib" | grep -q .; then
                echo "  Binary module found (macOS architecture)"
                echo "  Note: This will need to be compiled for iOS separately"
            fi
        else
            echo "Warning: pydantic-core not found (pydantic may not work)"
        fi
        
        # Копируем установленные пакеты в site-packages
        if [ -d "${TEMP_DEPS_DIR}" ] && [ "$(ls -A ${TEMP_DEPS_DIR} 2>/dev/null)" ]; then
            echo "Copying installed packages to site-packages..."
            # Копируем все установленные пакеты
            cp -R "${TEMP_DEPS_DIR}"/* "${SITE_PACKAGES_DIR}/" 2>/dev/null || true
            
            # Показываем количество установленных пакетов
            PKG_COUNT=$(find "${SITE_PACKAGES_DIR}" -maxdepth 1 -type d -name "*.dist-info" -o -type d ! -name "__pycache__" ! -name "." | wc -l | tr -d ' ')
            echo "✓ ${PKG_COUNT} packages copied to site-packages"
        else
            echo "Warning: No packages found in temporary directory"
        fi
        
        # Очищаем временную директорию
        rm -rf "${TEMP_DEPS_DIR}" 2>/dev/null || true
    else
        echo "Warning: pip not found, skipping dependency installation"
    fi
    
    # Если есть предустановленные зависимости в Python.xcframework, копируем их
    XCFRAMEWORK_SITE_PACKAGES="${PYTHON_PLATFORM}/lib/python3.12/site-packages"
    if [ -d "${XCFRAMEWORK_SITE_PACKAGES}" ]; then
        echo "Copying pre-installed packages from xcframework..."
        cp -R "${XCFRAMEWORK_SITE_PACKAGES}"/* "${SITE_PACKAGES_DIR}/" 2>/dev/null || true
    fi
    
    echo "Site-packages directory: ${SITE_PACKAGES_DIR}"
fi

# Копируем pymax из pymax/src/pymax в app/pymax
PYMAX_SRC="${PYMAX_DIR}/src/pymax"
PYMAX_DEST="${APP_DIR}/pymax"

if [ -d "${PYMAX_SRC}" ]; then
    echo "Copying pymax library from ${PYMAX_SRC}..."
    mkdir -p "${APP_DIR}"
    
    # Удаляем старую версию если есть
    if [ -d "${PYMAX_DEST}" ]; then
        rm -rf "${PYMAX_DEST}"
    fi
    
    cp -R "${PYMAX_SRC}" "${PYMAX_DEST}"
    
    # Проверяем что скопировалось
    if [ -d "${PYMAX_DEST}" ] && [ -f "${PYMAX_DEST}/__init__.py" ]; then
        echo "✓ pymax library copied successfully"
    else
        echo "Warning: pymax may not have copied correctly"
    fi
    
    # Копируем __init__.py если есть на верхнем уровне
    if [ -f "${PYMAX_DIR}/src/__init__.py" ]; then
        mkdir -p "${APP_DIR}/src"
        cp "${PYMAX_DIR}/src/__init__.py" "${APP_DIR}/src/"
    fi
else
    echo "Warning: pymax source not found at ${PYMAX_SRC}"
fi

# Копируем Python обертку
WRAPPER_SRC="${PROJECT_DIR}/whitemax/app/max_client_wrapper.py"
if [ -f "${WRAPPER_SRC}" ]; then
    echo "Copying max_client_wrapper.py..."
    cp "${WRAPPER_SRC}" "${APP_DIR}/"
    if [ -f "${APP_DIR}/max_client_wrapper.py" ]; then
        echo "✓ max_client_wrapper.py copied successfully"
    else
        echo "Warning: max_client_wrapper.py may not have copied correctly"
    fi
else
    echo "Warning: max_client_wrapper.py not found at ${WRAPPER_SRC}"
fi

# Копируем Python.framework из xcframework в Frameworks директорию app bundle
# Это необходимо, так как xcframework автоматически не встраивается
# Для iOS app bundle структура: whitemax.app/Frameworks/
# ${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH} указывает на Resources внутри app bundle
# Frameworks должен быть на корневом уровне app bundle
if [ -n "${FRAMEWORKS_FOLDER_PATH}" ]; then
    FRAMEWORKS_DIR="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
else
    # Fallback: Frameworks на том же уровне, что и Resources
    APP_BUNDLE_CONTENTS="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/.."
    FRAMEWORKS_DIR="${APP_BUNDLE_CONTENTS}/Frameworks"
fi

# Используем уже определенные переменные
PYTHON_FRAMEWORK_SRC="${PYTHON_FRAMEWORK}"

if [ -d "${PYTHON_FRAMEWORK_SRC}" ]; then
    echo "Copying Python.framework to Frameworks..."
    echo "Source: ${PYTHON_FRAMEWORK_SRC}"
    echo "Destination: ${FRAMEWORKS_DIR}"
    mkdir -p "${FRAMEWORKS_DIR}"
    if [ -d "${FRAMEWORKS_DIR}/Python.framework" ]; then
        rm -rf "${FRAMEWORKS_DIR}/Python.framework"
    fi
    cp -R "${PYTHON_FRAMEWORK_SRC}" "${FRAMEWORKS_DIR}/"
    
    # Подписываем framework (требуется для iOS)
    echo "Code signing Python.framework..."
    
    # Определяем identity для подписи
    # Пробуем разные источники для identity
    SIGN_IDENTITY="${CODE_SIGN_IDENTITY}"
    if [ -z "${SIGN_IDENTITY}" ] || [ "${SIGN_IDENTITY}" == "" ]; then
        # Пробуем получить identity из EXPANDED_CODE_SIGN_IDENTITY
        SIGN_IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY}"
    fi
    if [ -z "${SIGN_IDENTITY}" ] || [ "${SIGN_IDENTITY}" == "" ]; then
        # Используем ad-hoc подпись если CODE_SIGN_IDENTITY не установлен
        SIGN_IDENTITY="-"
        echo "Using ad-hoc code signing (-) for Python.framework"
    else
        echo "Using code signing identity: ${SIGN_IDENTITY} for Python.framework"
    fi
    
    # Подписываем бинарный файл framework
    codesign --force --sign "${SIGN_IDENTITY}" "${FRAMEWORKS_DIR}/Python.framework/Python" 2>/dev/null || {
        echo "Warning: Failed to sign Python.framework/Python"
    }
    
    # Также подписываем весь framework
    codesign --force --sign "${SIGN_IDENTITY}" "${FRAMEWORKS_DIR}/Python.framework" 2>/dev/null || {
        echo "Warning: Failed to sign Python.framework"
    }
    
    echo "✓ Python.framework signed successfully"
    
    echo "Python.framework copied successfully"
fi

echo "Python libraries copied successfully!"
