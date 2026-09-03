// Generates CalT's launcher icon assets.
//
//   dart run tools/icon/generate_icon.dart
//   dart run flutter_launcher_icons
//
// The mark is a calorie ring opened into a "C" — the monogram and the
// progress ring are the same shape — with a bolt of energy inside it.
// Everything is drawn from geometry rather than stored as art so the
// three variants (opaque master, adaptive foreground, monochrome) stay
// in sync and can be re-cut at any size.
//
// Rendering is done at 4x and box-filtered down with premultiplied
// alpha, which anti-aliases the curves without the dark fringing a
// naive RGBA average leaves around transparent edges.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Straight sRGB triplet. Kept deliberately dumb — the renderer does its
/// own blending and needs the raw channels.
class Rgb {
  const Rgb(this.r, this.g, this.b);
  final int r, g, b;

  static Rgb lerp(Rgb a, Rgb b, double t) => Rgb(
    (a.r + (b.r - a.r) * t).round(),
    (a.g + (b.g - a.g) * t).round(),
    (a.b + (b.b - a.b) * t).round(),
  );
}

// Palette. The ring runs from the brand coral into a warm amber so the
// arc reads as heat building around the circle; on a deep, slightly
// warm charcoal the whole mark keeps its punch next to other icons.
const _bgCenter = Rgb(0x22, 0x1E, 0x18);
const _bgEdge = Rgb(0x13, 0x11, 0x10);
const _ringStart = Rgb(0xC7, 0x40, 0x1F);
const _ringEnd = Rgb(0xEE, 0xA1, 0x3C);
const _bolt = Rgb(0xFA, 0xF6, 0xEE);
const _white = Rgb(0xFF, 0xFF, 0xFF);

const _size = 1024;
const _ss = 4; // supersampling factor

/// The arc leaves a gap at the upper right, pointing the same way the
/// bolt leans, so the mark has one clear diagonal of movement.
const _gapCenterDeg = -45.0;
const _gapHalfDeg = 31.0;

/// Bolt outline in units of [_boltScale], origin at the icon's centre,
/// y pointing down. The six points are rotationally symmetric about the
/// centre, which is what keeps the zigzag from looking top-heavy.
const _boltPath = <(double, double)>[
  (0.19, -0.60),
  (-0.35, 0.05),
  (-0.05, 0.05),
  (-0.19, 0.60),
  (0.35, -0.05),
  (0.05, -0.05),
];

class IconSpec {
  const IconSpec({
    required this.ringRadius,
    required this.ringHalfStroke,
    required this.boltScale,
    required this.opaqueBackground,
    required this.flatColor,
  });

  /// Radius of the ring's centreline, in final-image pixels.
  final double ringRadius;
  final double ringHalfStroke;
  final double boltScale;

  /// Paint the charcoal ground (master icon) rather than leaving the
  /// canvas transparent (adaptive foreground / monochrome).
  final bool opaqueBackground;

  /// When set, ring and bolt are both filled with this single colour —
  /// used for the Android themed-icon and iOS tinted variants.
  final Rgb? flatColor;
}

/// Full-bleed icon: the ring sits at 74% of the canvas, comfortable
/// inside iOS's rounded-rect mask.
const _master = IconSpec(
  ringRadius: 338,
  ringHalfStroke: 43,
  boltScale: 330,
  opaqueBackground: true,
  flatColor: null,
);

/// Android's adaptive mask only guarantees the middle 66% of the canvas,
/// so the same mark is drawn smaller and the system paints the ground.
const _foreground = IconSpec(
  ringRadius: 283,
  ringHalfStroke: 36,
  boltScale: 276,
  opaqueBackground: false,
  flatColor: null,
);

const _monochrome = IconSpec(
  ringRadius: 283,
  ringHalfStroke: 36,
  boltScale: 276,
  opaqueBackground: false,
  flatColor: _white,
);

void main() {
  final outDir = Directory('assets/icon');
  if (!outDir.existsSync()) {
    stderr.writeln('Run this from the project root: ${outDir.path} not found.');
    exitCode = 1;
    return;
  }

  final master = _render(_master);
  _write(master, 'assets/icon/calt_icon_master_1024.png');
  _write(_render(_foreground), 'assets/icon/calt_icon_foreground_1024.png');
  _write(_render(_monochrome), 'assets/icon/calt_icon_monochrome_1024.png');

  // A rounded 512px cut for the README header, so the logo shown on
  // GitHub is the same mark the launcher shows rather than a hard square.
  Directory('docs').createSync(recursive: true);
  _write(
    _roundCorners(
      img.copyResize(
        master,
        width: 512,
        height: 512,
        interpolation: img.Interpolation.cubic,
      ),
      0.225,
    ),
    'docs/logo.png',
  );
}

/// Masks [image] to a rounded square, [radiusRatio] of its width, with a
/// one-pixel feathered edge so the corners don't stair-step.
img.Image _roundCorners(img.Image image, double radiusRatio) {
  final w = image.width.toDouble();
  final half = w / 2;
  final radius = w * radiusRatio;
  final inner = half - radius;
  final out = img.Image(width: image.width, height: image.height, numChannels: 4);

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final px = (x + 0.5 - half).abs() - inner;
      final py = (y + 0.5 - half).abs() - inner;
      // Signed distance to the rounded square.
      final qx = math.max(px, 0.0);
      final qy = math.max(py, 0.0);
      final d =
          math.sqrt(qx * qx + qy * qy) + math.min(math.max(px, py), 0.0) - radius;
      final coverage = (0.5 - d).clamp(0.0, 1.0);
      if (coverage <= 0) {
        out.setPixelRgba(x, y, 0, 0, 0, 0);
        continue;
      }
      final p = image.getPixel(x, y);
      out.setPixelRgba(
        x,
        y,
        p.r.toInt(),
        p.g.toInt(),
        p.b.toInt(),
        (coverage * 255).round(),
      );
    }
  }
  return out;
}

void _write(img.Image image, String path) {
  File(path).writeAsBytesSync(img.encodePng(image));
  stdout.writeln('wrote $path');
}

img.Image _render(IconSpec spec) {
  final hi = _size * _ss;
  final centre = hi / 2;

  final ringR = spec.ringRadius * _ss;
  final hs = spec.ringHalfStroke * _ss;
  final boltScale = spec.boltScale * _ss;
  final maxRadius = centre * math.sqrt2;

  final arcStart = _degToRad(_gapCenterDeg + _gapHalfDeg);
  final sweep = _degToRad(360 - _gapHalfDeg * 2);

  // Round caps: a disc at each end of the arc, coloured to match the
  // gradient where it terminates.
  final capA = _polar(centre, ringR, arcStart);
  final capB = _polar(centre, ringR, arcStart + sweep);

  final bolt = [
    for (final (x, y) in _boltPath)
      (centre + x * boltScale, centre + y * boltScale),
  ];
  final boltColor = spec.flatColor ?? _bolt;

  // Premultiplied accumulators, one bucket per output pixel.
  final n = _size * _size;
  final accA = Float64List(n);
  final accR = Float64List(n);
  final accG = Float64List(n);
  final accB = Float64List(n);

  final bandOuter = ringR + hs;
  final bandInner = ringR - hs;

  for (var py = 0; py < hi; py++) {
    final dy = py + 0.5 - centre;
    final row = (py ~/ _ss) * _size;
    for (var px = 0; px < hi; px++) {
      final dx = px + 0.5 - centre;
      final dist = math.sqrt(dx * dx + dy * dy);

      Rgb? colour;
      var alpha = 0.0;

      if (spec.opaqueBackground) {
        colour = Rgb.lerp(_bgCenter, _bgEdge, (dist / maxRadius).clamp(0, 1));
        alpha = 1.0;
      }

      // Ring body first — the angular test is only worth running for
      // pixels already inside the annulus — then the two round caps,
      // whose discs spill just past the arc's flat ends.
      Rgb? ring;
      if (dist <= bandOuter && dist >= bandInner) {
        final theta = math.atan2(dy, dx);
        var along = (theta - arcStart) % (math.pi * 2);
        if (along < 0) along += math.pi * 2;
        if (along <= sweep) {
          ring = spec.flatColor ?? Rgb.lerp(_ringStart, _ringEnd, along / sweep);
        }
      }
      if (ring == null) {
        final x = px + 0.5;
        final y = py + 0.5;
        if (_within(x, y, capA, hs)) {
          ring = spec.flatColor ?? _ringStart;
        } else if (_within(x, y, capB, hs)) {
          ring = spec.flatColor ?? _ringEnd;
        }
      }
      if (ring != null) {
        colour = ring;
        alpha = 1.0;
      }

      if (_inPolygon(px + 0.5, py + 0.5, bolt)) {
        colour = boltColor;
        alpha = 1.0;
      }

      if (alpha == 0 || colour == null) continue;
      final i = row + (px ~/ _ss);
      accA[i] += alpha;
      accR[i] += colour.r * alpha;
      accG[i] += colour.g * alpha;
      accB[i] += colour.b * alpha;
    }
  }

  final samples = (_ss * _ss).toDouble();
  final out = img.Image(width: _size, height: _size, numChannels: 4);
  for (var y = 0; y < _size; y++) {
    for (var x = 0; x < _size; x++) {
      final i = y * _size + x;
      final a = accA[i];
      if (a <= 0) {
        out.setPixelRgba(x, y, 0, 0, 0, 0);
        continue;
      }
      out.setPixelRgba(
        x,
        y,
        (accR[i] / a).round().clamp(0, 255),
        (accG[i] / a).round().clamp(0, 255),
        (accB[i] / a).round().clamp(0, 255),
        (a / samples * 255).round().clamp(0, 255),
      );
    }
  }
  return out;
}

double _degToRad(double deg) => deg * math.pi / 180;

(double, double) _polar(double centre, double radius, double angle) =>
    (centre + radius * math.cos(angle), centre + radius * math.sin(angle));

bool _within(double x, double y, (double, double) c, double radius) {
  final dx = x - c.$1;
  final dy = y - c.$2;
  return dx * dx + dy * dy <= radius * radius;
}

bool _inPolygon(double x, double y, List<(double, double)> poly) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final (xi, yi) = poly[i];
    final (xj, yj) = poly[j];
    if ((yi > y) != (yj > y) &&
        x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
      inside = !inside;
    }
  }
  return inside;
}
