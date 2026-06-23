#!/bin/bash
if [ -z "$1" ]; then
    echo "Использование: $0 <username>"
    exit 1
fi

USERNAME=$1
CDIR="/etc/ocserv-crt/ca"
USER_DIR="$CDIR/users/$USERNAME"

mkdir -p "$USER_DIR"

# 1. Автоматическая генерация 32-значного пароля (0-9, a-z, A-Z)
PASSWORD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)

if [ -z "$PASSWORD" ]; then
    echo "Ошибка генерации пароля."
    exit 1
fi

# 2. Сохранение пароля в файл .p12.pass
PASS_FILE="$USER_DIR/$USERNAME.p12.pass"
echo "$PASSWORD" > "$PASS_FILE"
chmod 600 "$PASS_FILE" # Ограничиваем доступ только для root

# 3. Создание шаблона сертификата пользователя
cat << UTMPL > "$USER_DIR/user.tmpl"
cn = "$USERNAME"
unit = "VPN Users"
expiration_days = 1825
signing_key
tls_client
UTMPL

# 4. Генерация ключа пользователя
certtool --generate-privkey  --ecdsa --outfile "$USER_DIR/user-key.pem"

# 5. Генерация и подпись сертификата
certtool --generate-certificate \
    --load-privkey "$USER_DIR/user-key.pem" \
    --load-ca-certificate "$CDIR/ca-cert.pem" \
    --load-ca-privkey "$CDIR/ca-key.pem" \
    --template "$USER_DIR/user.tmpl" \
    --outfile "$USER_DIR/user-cert.pem"

# 6. Упаковка в формат .p12 с использованием сгенерированного пароля
openssl pkcs12 -export \
    -inkey "$USER_DIR/user-key.pem" \
    -in "$USER_DIR/user-cert.pem" \
    -certfile "$CDIR/ca-cert.pem" \
    -out "$USER_DIR/$USERNAME.p12" \
    -name "$USERNAME VPN Certificate" \
    -passout pass:"$PASSWORD"

echo "--------------------------------------------------"
echo "Процесс завершен без ошибок."
echo "Сгенерирован пароль: $PASSWORD"
echo "Файл сертификата:    $USER_DIR/$USERNAME.p12"
echo "Файл с паролем:      $PASS_FILE"
echo "--------------------------------------------------"
