import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

/// Reads text from an image file, on the device. Nothing is uploaded.
abstract class OcrEngine {
  Future<String> readFile(String path);

  /// The engine for this platform, or null where there is none.
  static OcrEngine? forPlatform() {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows => WindowsOcr(),
      TargetPlatform.android => MlKitOcr(),
      _ => null,
    };
  }
}

/// The OCR engine built into Windows 10/11, reached through PowerShell.
class WindowsOcr implements OcrEngine {
  /// The image path travels in an environment variable, so a file name can
  /// never be parsed as PowerShell.
  static const _script = r'''
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
$null = [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime]
$null = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics, ContentType = WindowsRuntime]
$asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
  $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and
  $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
} | Select-Object -First 1
function Await($op, [Type]$type) {
  $task = $asTask.MakeGenericMethod($type).Invoke($null, @($op))
  $task.Wait()
  $task.Result
}
$file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($env:DOCUVEIL_OCR_IMAGE)) ([Windows.Storage.StorageFile])
$stream = Await ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
$decoder = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
$bitmap = Await ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
$engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
if ($null -eq $engine) { throw 'No Windows OCR language is installed.' }
$result = Await ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])
foreach ($line in $result.Lines) { [Console]::Out.WriteLine($line.Text) }
''';

  @override
  Future<String> readFile(String path) async {
    final dir = await Directory.systemTemp.createTemp('docuveil_ocr');
    try {
      final script = File(p.join(dir.path, 'ocr.ps1'));
      await script.writeAsString(_script);
      final r = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          script.path,
        ],
        environment: {'DOCUVEIL_OCR_IMAGE': p.absolute(path)},
        stdoutEncoding: const Utf8Codec(allowMalformed: true),
      );
      if (r.exitCode != 0) throw Exception('Windows OCR failed: ${r.stderr}');
      return (r.stdout as String).trim();
    } finally {
      await dir.delete(recursive: true);
    }
  }
}

/// Google ML Kit text recognition, on-device, for Android.
class MlKitOcr implements OcrEngine {
  @override
  Future<String> readFile(String path) async {
    final r = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      return (await r.processImage(InputImage.fromFilePath(path))).text;
    } finally {
      await r.close();
    }
  }
}

/// OCR for bytes that are not on disk yet. The temporary copy holds a personal
/// document, so it is always deleted afterwards.
Future<String> ocrBytes(OcrEngine engine, Uint8List bytes, String extension) async {
  final base = await getTemporaryDirectory();
  final dir = await base.createTemp('docuveil_scan');
  try {
    final f = File(p.join(dir.path, 'page.$extension'));
    await f.writeAsBytes(bytes);
    return await engine.readFile(f.path);
  } finally {
    await dir.delete(recursive: true);
  }
}

/// Render a scanned PDF's pages and OCR them. At most [maxPages] pages.
Future<String> ocrPdf(OcrEngine engine, Uint8List bytes, {int maxPages = 5}) async {
  final doc = await PdfDocument.openData(bytes);
  try {
    final out = <String>[];
    for (final page in doc.pages.take(maxPages)) {
      // About 200 dpi: PDF sizes are in points, 72 to the inch.
      const scale = 200 / 72;
      final w = (page.width * scale).round(), h = (page.height * scale).round();
      final rendered = await page.render(
        fullWidth: w.toDouble(),
        fullHeight: h.toDouble(),
        width: w,
        height: h,
        backgroundColor: 0xFFFFFFFF,
      );
      if (rendered == null) continue;
      try {
        final image = img.Image.fromBytes(
          width: rendered.width,
          height: rendered.height,
          bytes: rendered.pixels.buffer,
          numChannels: 4,
          order: img.ChannelOrder.bgra,
        );
        out.add(await ocrBytes(engine, img.encodePng(image), 'png'));
      } finally {
        rendered.dispose();
      }
    }
    return out.join('\n');
  } finally {
    await doc.dispose();
  }
}
