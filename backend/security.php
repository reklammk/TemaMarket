<?php

function jsonResponse(array $payload, int $status = 200): void
{
    http_response_code($status);
    echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function normalizeTurkishPhone(string $phone): ?string
{
    $digits = preg_replace('/\D+/', '', $phone) ?? '';
    if (str_starts_with($digits, '90') && strlen($digits) === 12) {
        $digits = substr($digits, 2);
    }
    if (str_starts_with($digits, '0') && strlen($digits) === 11) {
        $digits = substr($digits, 1);
    }
    if (!preg_match('/^5\d{9}$/', $digits)) {
        return null;
    }
    return '+90' . $digits;
}

function getBearerToken(): ?string
{
    $header = $_SERVER['HTTP_AUTHORIZATION']
        ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION']
        ?? '';
    if (!preg_match('/^Bearer\s+(.+)$/i', trim($header), $matches)) {
        return null;
    }
    return trim($matches[1]);
}

function safeUser(array $user): array
{
    $allowed = [
        'id', 'phone', 'role', 'name', 'email', 'company_name',
        'vehicle_type', 'city_district', 'status', 'branch_id',
        'birth_date', 'special_day', 'sms_consent', 'push_consent',
        'kvkk_consent', 'user_barcode', 'discount_preferences',
    ];
    $safe = array_intersect_key($user, array_flip($allowed));

    $preferences = json_decode((string)($safe['discount_preferences'] ?? '[]'), true);
    $safe['discount_preferences'] = is_array($preferences)
        ? array_values(array_filter($preferences, 'is_string'))
        : [];

    if (isset($safe['phone'])) {
        // TEMA Kart barkodu doğrudan müşterinin telefon numarasını temsil eder.
        $safe['user_barcode'] = preg_replace('/\D+/', '', (string)$safe['phone']) ?? '';
    }

    return $safe;
}

function safeCourier(array $user): array
{
    $allowed = ['id', 'name', 'vehicle_type', 'city_district', 'status', 'branch_id'];
    return array_intersect_key($user, array_flip($allowed));
}

function currentApiUser(PDO $pdo): ?array
{
    $token = getBearerToken();
    if ($token === null || strlen($token) < 32) {
        return null;
    }

    $hash = hash('sha256', $token);
    $stmt = $pdo->prepare(
        "SELECT u.*
         FROM api_tokens t
         INNER JOIN users u ON u.id = t.user_id
         WHERE t.token_hash = ? AND t.expires_at > CURRENT_TIMESTAMP
           AND u.status = 'AKTIF'
         LIMIT 1"
    );
    $stmt->execute([$hash]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$user) {
        return null;
    }

    $pdo->prepare('UPDATE api_tokens SET last_used_at = CURRENT_TIMESTAMP WHERE token_hash = ?')
        ->execute([$hash]);
    return $user;
}

function requireAuth(PDO $pdo, array $allowedRoles = []): array
{
    $user = currentApiUser($pdo);
    if ($user === null) {
        jsonResponse(['success' => false, 'message' => 'Oturum gerekli.'], 401);
    }
    if ($allowedRoles && !in_array($user['role'] ?? '', $allowedRoles, true)) {
        jsonResponse(['success' => false, 'message' => 'Bu işlem için yetkiniz yok.'], 403);
    }
    return $user;
}

function issueApiToken(PDO $pdo, int $userId): string
{
    $rawToken = bin2hex(random_bytes(32));
    $hash = hash('sha256', $rawToken);
    $expiresAt = date('Y-m-d H:i:s', strtotime('+30 days'));

    $pdo->prepare('DELETE FROM api_tokens WHERE expires_at <= CURRENT_TIMESTAMP')->execute();
    $stmt = $pdo->prepare(
        'INSERT INTO api_tokens (user_id, token_hash, expires_at) VALUES (?, ?, ?)'
    );
    $stmt->execute([$userId, $hash, $expiresAt]);
    return $rawToken;
}

function revokeCurrentApiToken(PDO $pdo): void
{
    $token = getBearerToken();
    if ($token !== null) {
        $pdo->prepare('DELETE FROM api_tokens WHERE token_hash = ?')
            ->execute([hash('sha256', $token)]);
    }
}
