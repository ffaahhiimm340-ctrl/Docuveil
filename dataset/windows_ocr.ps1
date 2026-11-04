# The OCR built into Windows 10/11. Same script as app/lib/data/ocr_service.dart.
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
# Windows may split a line with wide gaps and return the pieces out of order,
# so rebuild lines from each word's position, undoing the page's tilt first.
$a = 0.0
if ($null -ne $result.TextAngle) { $a = [double]$result.TextAngle * [Math]::PI / 180 }
$cos = [Math]::Cos($a); $sin = [Math]::Sin($a)
$words = foreach ($line in $result.Lines) { foreach ($w in $line.Words) {
  $r = $w.BoundingRect
  $cx = $r.X + $r.Width / 2; $cy = $r.Y + $r.Height / 2
  [pscustomobject]@{ T = $w.Text; X = $cx * $cos + $cy * $sin; Y = $cy * $cos - $cx * $sin; H = $r.Height }
} }
$group = @(); $sum = 0.0; $tallest = 0.0
function Flush { if ($group.Count) { [Console]::Out.WriteLine((($group | Sort-Object X | ForEach-Object { $_.T }) -join ' ')) } }
foreach ($w in ($words | Sort-Object Y)) {
  if ($group.Count -and [Math]::Abs($w.Y - $sum / $group.Count) -ge 0.6 * [Math]::Max($tallest, $w.H)) {
    Flush; $group = @(); $sum = 0.0; $tallest = 0.0
  }
  $group += $w; $sum += $w.Y; $tallest = [Math]::Max($tallest, $w.H)
}
Flush
