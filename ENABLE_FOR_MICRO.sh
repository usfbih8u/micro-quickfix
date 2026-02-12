#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
CURRENT_DIR="$(pwd)"

if [ "$SCRIPT_DIR" != "$CURRENT_DIR" ]; then
    echo >&2 -e \
        "\e[031mERROR: ${SCRIPT_NAME} MUST be executed from its own directory.\e[0m"
    exit 1
fi

ln --symbolic "$CURRENT_DIR" "$HOME/.config/micro/plug"