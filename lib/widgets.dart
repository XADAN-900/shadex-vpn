import 'package:flutter/material.dart';

import 'theme.dart';

/// Yarı saydam, kenarlıklı kart. onTap verilirse dokunulabilir olur.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.highlight,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    return Container(
      decoration: BoxDecoration(
        color: highlight?.withAlpha(40) ?? Colors.white.withAlpha(13),
        borderRadius: radius,
        border: Border.all(
          color: highlight?.withAlpha(120) ?? Colors.white.withAlpha(22),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Renkli metin (marka degradesi).
class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => AppColors.brandGradient.createShader(r),
      child: Text(text, style: style, maxLines: 1),
    );
  }
}

/// Üstteki durum hapı: nokta + metin.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color, blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Büyük bağlan düğmesi. Bağlıyken etrafında nabız halkaları atar.
class PowerButton extends StatefulWidget {
  const PowerButton({
    super.key,
    required this.size,
    required this.color,
    required this.connected,
    required this.busy,
    required this.label,
    required this.onTap,
  });

  final double size;
  final Color color;
  final bool connected;
  final bool busy;
  final String label;
  final VoidCallback onTap;

  @override
  State<PowerButton> createState() => _PowerButtonState();
}

class _PowerButtonState extends State<PowerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant PowerButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.connected) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else if (_pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Widget _ring(double t) {
    final d = widget.size * (1 + 0.32 * t);
    return Opacity(
      opacity: ((1 - t) * 0.55).clamp(0.0, 1.0).toDouble(),
      child: Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: widget.color, width: 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final label = widget.label;

    return SizedBox(
      width: s * 1.34,
      height: s * 1.34,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.connected)
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => Stack(
                alignment: Alignment.center,
                children: [
                  _ring(_pulse.value),
                  _ring((_pulse.value + 0.5) % 1.0),
                ],
              ),
            ),
          if (widget.busy)
            SizedBox(
              width: s + 22,
              height: s + 22,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: widget.color,
                strokeCap: StrokeCap.round,
              ),
            ),
          Semantics(
            button: true,
            label: label,
            child: GestureDetector(
              onTap: widget.onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                width: s,
                height: s,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(widget.color, Colors.white, 0.15)!,
                      Color.lerp(widget.color, Colors.black, 0.45)!,
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withAlpha(45),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withAlpha(widget.connected ? 140 : 80),
                      blurRadius: widget.connected ? 50 : 28,
                      spreadRadius: widget.connected ? 4 : 0,
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(s * 0.2),
                  child: FittedBox(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.power_settings_new_rounded,
                          size: 76,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// İndirme / yükleme kutucuğu.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.sub,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withAlpha(35),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withAlpha(140),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  sub ?? ' ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withAlpha(110),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Yuvarlak bayrak rozeti.
class FlagBadge extends StatelessWidget {
  const FlagBadge(this.flag, {super.key, this.size = 44});

  final String flag;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(16),
        shape: BoxShape.circle,
      ),
      child: Text(flag, style: TextStyle(fontSize: size * 0.52)),
    );
  }
}

/// Ping rozeti: yeşil iyi, sarı orta, kırmızı kötü; ulaşılamıyorsa "Kapalı".
class PingBadge extends StatelessWidget {
  const PingBadge(
    this.ping, {
    super.key,
    this.offline = false,
    this.offlineText = 'Offline',
  });

  final int ping;
  final bool offline;
  final String offlineText;

  @override
  Widget build(BuildContext context) {
    final color = offline
        ? AppColors.red
        : ping <= 0
            ? Colors.white54
            : ping < 120
                ? AppColors.green
                : ping < 300
                    ? AppColors.amber
                    : AppColors.red;
    final text = offline ? offlineText : (ping > 0 ? '$ping ms' : '— ms');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
