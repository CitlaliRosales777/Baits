<?php
declare(strict_types=1);

// El servidor PHP integrado delega en este archivo para servir el frontend local.
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
if ($method !== 'GET' && $method !== 'HEAD') {
    http_response_code(405);
    header('Allow: GET, HEAD');
    header('Cache-Control: no-store');
    return;
}

$types = [
    'html' => 'text/html; charset=UTF-8',
    'css' => 'text/css; charset=UTF-8',
    'js' => 'application/javascript; charset=UTF-8',
    'svg' => 'image/svg+xml',
    'png' => 'image/png',
    'jpg' => 'image/jpeg',
    'jpeg' => 'image/jpeg',
    'webp' => 'image/webp',
    'ico' => 'image/x-icon',
    'otf' => 'font/otf',
    'woff' => 'font/woff',
    'woff2' => 'font/woff2',
    'pdf' => 'application/pdf',
    'txt' => 'text/plain; charset=UTF-8',
];

$root = realpath(__DIR__ . '/fronted');
$requestPath = rawurldecode(explode('?', $_SERVER['REQUEST_URI'] ?? '/', 2)[0]);
$relativePath = $requestPath === '/' ? 'index.html' : ltrim($requestPath, '/');
// realpath resuelve enlaces y segmentos antes de comprobar que el archivo es público.
$file = $root !== false && !str_contains($relativePath, "\0")
    ? realpath($root . DIRECTORY_SEPARATOR . $relativePath)
    : false;
$extension = strtolower(pathinfo($relativePath, PATHINFO_EXTENSION));
if ($file === false || !str_starts_with($file, $root . DIRECTORY_SEPARATOR)
    || !is_file($file) || !isset($types[$extension])
    || $extension !== strtolower(pathinfo($file, PATHINFO_EXTENSION))) {
    http_response_code(404);
    header('Cache-Control: no-store');
    return;
}

$cache = match ($extension) {
    'html' => 'no-cache',
    'css', 'js' => 'public, max-age=60, must-revalidate',
    default => 'public, max-age=86400, must-revalidate',
};
$etag = '"' . hash_file('sha256', $file) . '"';
$modified = filemtime($file);

header('Content-Type: ' . $types[$extension]);
header('X-Content-Type-Options: nosniff');
header('Cache-Control: ' . $cache);
header('ETag: ' . $etag);
header('Last-Modified: ' . gmdate('D, d M Y H:i:s', $modified) . ' GMT');

$requestedEtags = $_SERVER['HTTP_IF_NONE_MATCH'] ?? null;
if ($requestedEtags !== null) {
    foreach (explode(',', $requestedEtags) as $candidate) {
        $candidate = trim($candidate);
        if ($candidate === '*' || $candidate === $etag || $candidate === 'W/' . $etag) {
            http_response_code(304);
            return;
        }
    }
} else {
    $since = strtotime($_SERVER['HTTP_IF_MODIFIED_SINCE'] ?? '');
    if ($since !== false && $modified <= $since) {
        http_response_code(304);
        return;
    }
}

header('Content-Length: ' . filesize($file));
if ($method === 'GET') {
    readfile($file);
}
