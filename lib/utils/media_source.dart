import '../config/env.dart';

bool isAbsoluteMediaUrl(String path) {
  final uri = Uri.tryParse(path);
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
}

bool isServerRelativeMediaPath(String path) {
  return path.startsWith('/uploads/');
}

bool isLocalMediaPath(String path) {
  return !isAbsoluteMediaUrl(path) && !isServerRelativeMediaPath(path);
}

String resolveMediaUrl(String path) {
  if (isAbsoluteMediaUrl(path)) {
    return path;
  }
  if (isServerRelativeMediaPath(path)) {
    return '${EnvConfig.serverBaseUrl}$path';
  }
  return path;
}

String normalizedMediaPathForTypeCheck(String path) {
  if (isAbsoluteMediaUrl(path)) {
    final uri = Uri.tryParse(path);
    return (uri?.path ?? path).toLowerCase();
  }
  return path.toLowerCase();
}

bool isImageMediaPath(String path) {
  final normalized = normalizedMediaPathForTypeCheck(path);
  return normalized.endsWith('.jpg') ||
      normalized.endsWith('.jpeg') ||
      normalized.endsWith('.png') ||
      normalized.endsWith('.gif') ||
      normalized.endsWith('.webp') ||
      normalized.endsWith('.bmp');
}

bool isVideoMediaPath(String path) {
  final normalized = normalizedMediaPathForTypeCheck(path);
  return normalized.endsWith('.mp4') ||
      normalized.endsWith('.mov') ||
      normalized.endsWith('.avi') ||
      normalized.endsWith('.mkv') ||
      normalized.endsWith('.webm');
}

bool isAudioMediaPath(String path) {
  final normalized = normalizedMediaPathForTypeCheck(path);
  return normalized.endsWith('.mp3') ||
      normalized.endsWith('.m4a') ||
      normalized.endsWith('.aac') ||
      normalized.endsWith('.wav');
}
