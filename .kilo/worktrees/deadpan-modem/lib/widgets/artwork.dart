import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/song.dart';
import '../theme/app_colors.dart';

/// Album/song artwork (spec §33).
///
/// If the [Song] has an `artworkPath` the real image is used. Otherwise a
/// deterministic generated cover is painted: gradient + geometric shapes +
/// initials. The same id always produces the same cover, so covers stay stable
/// across restarts without shipping any image assets.
class Artwork extends StatelessWidget {
  const Artwork({
    super.key,
    required this.seed,
    this.size = 76,
    this.radius,
    this.label,
    this.song,
    this.showGlyph = true,
    this.borderRadiusFactor = 0.22,
  });

  /// Stable seed — usually `Song.id` or `playlist.artworkSeed`.
  final int seed;
  final double size;
  final double? radius;
  final String? label;
  final Song? song;
  final bool showGlyph;
  final double borderRadiusFactor;

  @override
  Widget build(BuildContext context) {
    final double r = radius ?? size * borderRadiusFactor;
    final ImageProvider<Object>? provider = _imageProvider(song);
    final (Color a, Color b) = VibeColors.accentPairFor(seed);

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: b.withValues(alpha: 0.28),
            blurRadius: size * 0.34,
            offset: Offset(0, size * 0.10),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (provider != null)
            Image(
              image: provider,
              fit: BoxFit.cover,
              errorBuilder: (BuildContext _, Object __, StackTrace? ___) =>
                  const SizedBox.shrink(),
            )
          else
            CustomPaint(painter: _GeneratedCoverPainter(seed: seed, a: a, b: b)),
          if (provider == null && showGlyph)
            _ArtworkGlyph(seed: seed, label: label, song: song, size: size),
          if (provider != null)
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(r),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.center,
                  colors: <Color>[
                    Colors.white.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(r),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.16),
                width: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static ImageProvider<Object>? _imageProvider(Song? song) {
    if (song == null || !song.hasArtwork) {
      return null;
    }
    return AssetImage(song.artworkAssetPath);
  }
}

/// Abstract generated cover: gradient base plus three deterministic shapes.
class _GeneratedCoverPainter extends CustomPainter {
  _GeneratedCoverPainter({
    required this.seed,
    required this.a,
    required this.b,
  });

  final int seed;
  final Color a;
  final Color b;

  @override
  void paint(Canvas canvas, Size size) {
    final math.Random rng = math.Random(seed);
    final Rect rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[a, Color.lerp(a, b, 0.55)!, b],
        ).createShader(rect),
    );

    // Two large soft circles.
    for (int i = 0; i < 2; i++) {
      final double radius = size.shortestSide * (0.28 + rng.nextDouble() * 0.24);
      final Offset center = Offset(
        size.width * rng.nextDouble(),
        size.height * rng.nextDouble(),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = (i.isEven ? Colors.white : VibeColors.softPink)
              .withValues(alpha: 0.10 + rng.nextDouble() * 0.10)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.shortestSide * 0.09),
      );
    }

    // Diagonal light streak.
    final Paint streak = Paint()
      ..shader = LinearGradient(
        colors: <Color>[
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.16),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const <double>[0, 0.5, 1],
      ).createShader(rect);
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-math.pi / 5);
    canvas.translate(-size.width / 2, -size.height / 2);
    canvas.drawRect(
      Rect.fromLTWH(
        -size.width * 0.2,
        size.height * (0.28 + rng.nextDouble() * 0.2),
        size.width * 1.4,
        size.height * 0.10,
      ),
      streak,
    );
    canvas.restore();

    // A couple of crisp dots for texture.
    final Paint dot = Paint()..color = Colors.white.withValues(alpha: 0.20);
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(
          size.width * (0.15 + rng.nextDouble() * 0.7),
          size.height * (0.15 + rng.nextDouble() * 0.7),
        ),
        size.shortestSide * 0.022,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GeneratedCoverPainter oldDelegate) =>
      oldDelegate.seed != seed;
}

/// The glyph drawn on top of the generated cover.
class _ArtworkGlyph extends StatelessWidget {
  const _ArtworkGlyph({
    required this.seed,
    required this.size,
    this.label,
    this.song,
  });

  final int seed;
  final double size;
  final String? label;
  final Song? song;

  @override
  Widget build(BuildContext context) {
    final String? text = label ??
        (song == null || size < 44
            ? null
            : song!.title
                .split(RegExp(r'\s+'))
                .where((String w) => w.isNotEmpty)
                .take(2)
                .map((String w) => w[0].toUpperCase())
                .join());

    return Center(
      child: SizedBox(
        width: size * 0.72,
        height: size * 0.72,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ),
            ),
            if (text != null)
              Text(
                text,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: VibeColors.white.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w800,
                  fontSize: size * (text.length > 1 ? 0.24 : 0.32),
                  letterSpacing: 0.5,
                  height: 1,
                ),
              )
            else
              Icon(
                Icons.graphic_eq_rounded,
                size: size * 0.34,
                color: VibeColors.white.withValues(alpha: 0.80),
              ),
          ],
        ),
      ),
    );
  }
}

/// Generated user avatar used by the Profile header.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.initials, required this.seed, this.size = 92});

  final String initials;
  final int seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (Color a, Color b) = VibeColors.accentPairFor(seed);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[a, b],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(color: b.withValues(alpha: 0.4), blurRadius: size * 0.3),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.24), width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.34,
          fontWeight: FontWeight.w800,
          color: VibeColors.white,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

/// Backwards-compatible alias for the original starter widget name.
typedef GradientArt = Artwork;
