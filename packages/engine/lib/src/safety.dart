import 'dart:convert';
import 'dart:typed_data';

/// Basic-layer safety checks. These are simple static heuristics, built and
/// cited, not research claims. The scan is NOT an antivirus: it only spots
/// common places a document can carry active content.

class ScriptFinding {
  const ScriptFinding(this.what);

  final String what;
}

bool _hasBytes(Uint8List data, String text) {
  final needle = latin1.encode(text);
  outer:
  for (var i = 0; i + needle.length <= data.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (data[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}

/// Look for macros in Office files, and scripts or auto-run actions in PDFs.
/// The file is only read, never opened or run.
List<ScriptFinding> scanForHiddenScript(String fileName, Uint8List bytes) {
  final out = <ScriptFinding>[];
  final isPdf = bytes.length > 4 && latin1.decode(bytes.sublist(0, 4)) == '%PDF';
  final isZip = bytes.length > 2 && bytes[0] == 0x50 && bytes[1] == 0x4B;
  final isOle = bytes.length > 4 && bytes[0] == 0xD0 && bytes[1] == 0xCF;
  if (isPdf) {
    const tokens = {
      '/JavaScript': 'JavaScript',
      '/JS': 'JavaScript',
      '/OpenAction': 'an action that runs when opened',
      '/AA': 'an automatic action',
      '/Launch': 'a command that launches a program',
      '/EmbeddedFile': 'an embedded file',
    };
    final seen = <String>{};
    tokens.forEach((token, what) {
      if (_hasBytes(bytes, token) && seen.add(what)) {
        out.add(ScriptFinding('This PDF contains $what.'));
      }
    });
  } else if (isZip) {
    // File names in a zip are stored uncompressed.
    if (_hasBytes(bytes, 'vbaProject.bin')) {
      out.add(const ScriptFinding('This Office file contains a macro.'));
    }
    if (_hasBytes(bytes, 'oleObject')) {
      out.add(const ScriptFinding('This Office file contains an embedded object.'));
    }
  } else if (isOle) {
    if (_hasBytes(bytes, '_VBA_PROJECT') || _hasBytes(bytes, 'VBA')) {
      out.add(const ScriptFinding('This older Office file contains a macro.'));
    }
  }
  final lower = fileName.toLowerCase();
  if (RegExp(r'\.(pdf|docx?|xlsx?|pptx?|jpe?g|png|txt)\.(exe|scr|bat|cmd|js|vbs)$').hasMatch(lower)) {
    out.add(const ScriptFinding('This file pretends to be a document but is a program.'));
  }
  return out;
}

class SensitiveFinding {
  const SensitiveFinding(this.kind, this.masked);

  final String kind;

  /// The number with all but its last four characters hidden.
  final String masked;
}

String _mask(String v) {
  final t = v.replaceAll(RegExp(r'\s'), '');
  return '${'*' * (t.length - 4)}${t.substring(t.length - 4)}';
}

/// ID numbers that appear in a document's text. Pattern matches only, so
/// other 12-digit numbers can also match; treat it as a prompt to look.
List<SensitiveFinding> findSensitive(String text) {
  final out = <SensitiveFinding>[];
  final seen = <String>{};
  void scan(String kind, RegExp re) {
    for (final m in re.allMatches(text)) {
      final masked = _mask(m.group(0)!);
      if (seen.add('$kind$masked')) out.add(SensitiveFinding(kind, masked));
    }
  }

  scan('Aadhaar-style number', RegExp(r'(?<![0-9])[2-9][0-9]{3} ?[0-9]{4} ?[0-9]{4}(?![0-9])'));
  scan('PAN-style number', RegExp(r'\b[A-Z]{5}[0-9]{4}[A-Z]\b'));
  scan('Passport-style number', RegExp(r'\b[A-Z][0-9]{7}\b'));
  return out;
}

/// True if a path looks like somewhere other people can open.
bool looksShared(String path) => RegExp(
  r'(^|[\\/])(shared|share|public|whatsapp|telegram|dropbox|google ?drive|onedrive)',
  caseSensitive: false,
).hasMatch(path);

/// Ransomware-style burst: many different files changing in a short time.
/// Thresholds are a first guess. Decoy-aware ransomware can avoid this.
class MassChangeDetector {
  MassChangeDetector({
    this.threshold = 20,
    this.window = const Duration(seconds: 10),
  });

  final int threshold;
  final Duration window;
  final _events = <(DateTime, String)>[];

  /// Record a change. Returns true once [threshold] different files have
  /// changed within [window].
  bool record(String path, DateTime at) {
    _events
      ..add((at, path))
      ..removeWhere((e) => at.difference(e.$1) > window);
    return _events.map((e) => e.$2).toSet().length >= threshold;
  }
}
