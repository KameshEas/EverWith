import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../core/constants/app_spacing.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

/// A simple music player for calming audio tracks.
class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  int _currentTrackIndex = 0;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // Playlist of calming tracks (asset paths)
  final List<MusicTrack> _tracks = [
    MusicTrack(
      title: 'Gentle Piano',
      artist: 'Relaxation Series',
      assetPath: 'assets/audio/gentle_piano.mp3',
      duration: const Duration(minutes: 5),
    ),
    MusicTrack(
      title: 'Forest Ambience',
      artist: 'Nature Sounds',
      assetPath: 'assets/audio/forest_ambience.mp3',
      duration: const Duration(minutes: 6),
    ),
    MusicTrack(
      title: 'Ocean Waves',
      artist: 'Natural Soundscapes',
      assetPath: 'assets/audio/ocean_waves.mp3',
      duration: const Duration(minutes: 5),
    ),
    MusicTrack(
      title: 'Meditation',
      artist: 'Wellness Collection',
      assetPath: 'assets/audio/meditation.mp3',
      duration: const Duration(minutes: 7),
    ),
    MusicTrack(
      title: 'Rainfall',
      artist: 'Weather Sounds',
      assetPath: 'assets/audio/rainfall.mp3',
      duration: const Duration(minutes: 4, seconds: 30),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playTrack(int index) async {
    if (index < 0 || index >= _tracks.length) return;
    try {
      await _audioPlayer.play(AssetSource(_tracks[index].assetPath));
      setState(() => _currentTrackIndex = index);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not play this track.'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        if (_audioPlayer.state == PlayerState.stopped) {
          await _playTrack(_currentTrackIndex);
        } else {
          await _audioPlayer.resume();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Playback error.'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _nextTrack() async {
    final nextIndex = (_currentTrackIndex + 1) % _tracks.length;
    await _playTrack(nextIndex);
  }

  Future<void> _previousTrack() async {
    final prevIndex =
        (_currentTrackIndex - 1 + _tracks.length) % _tracks.length;
    await _playTrack(prevIndex);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final currentTrack = _tracks[_currentTrackIndex];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Relaxing Music',
                        style: AppTextStyles.heading.copyWith(fontSize: 32),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_tracks.length} calming tracks',
                        style: AppTextStyles.body.copyWith(fontSize: 15),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.cardWhite,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadow.withAlpha(38),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.close_rounded,
                          size: 22, color: AppColors.iconMuted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl + AppSpacing.lg),

              // ── Album artwork placeholder ───────────────────────────────
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadow.withAlpha(50),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.music_note_rounded,
                  size: 80,
                  color: AppColors.primaryBlue.withAlpha(100),
                ),
              ),
              const SizedBox(height: AppSpacing.xl + AppSpacing.lg),

              // ── Track title ─────────────────────────────────────────────
              Text(
                currentTrack.title,
                style: AppTextStyles.heading.copyWith(fontSize: 24),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                currentTrack.artist,
                style: AppTextStyles.body.copyWith(
                  fontSize: 14,
                  color: AppColors.textGray,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Progress bar ────────────────────────────────────────────
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _duration.inMilliseconds > 0
                          ? _position.inMilliseconds /
                              _duration.inMilliseconds
                          : 0,
                      minHeight: 6,
                      backgroundColor: AppColors.inputBorder,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: AppTextStyles.body.copyWith(
                          fontSize: 12,
                          color: AppColors.textGray,
                        ),
                      ),
                      Text(
                        _formatDuration(_duration),
                        style: AppTextStyles.body.copyWith(
                          fontSize: 12,
                          color: AppColors.textGray,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl + AppSpacing.lg),

              // ── Playback controls ───────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Previous
                  GestureDetector(
                    onTap: _previousTrack,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.cardWhite,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadow.withAlpha(25),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.skip_previous_rounded,
                        color: AppColors.primaryBlue,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),

                  // Play/Pause
                  GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryBlue.withAlpha(110),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),

                  // Next
                  GestureDetector(
                    onTap: _nextTrack,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.cardWhite,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadow.withAlpha(25),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.skip_next_rounded,
                        color: AppColors.primaryBlue,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl + AppSpacing.lg),

              // ── Playlist ────────────────────────────────────────────────
              Text(
                'PLAYLIST',
                style: AppTextStyles.body.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textGray,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ..._tracks.asMap().entries.map((entry) {
                final index = entry.key;
                final track = entry.value;
                final isCurrentTrack = index == _currentTrackIndex;
                return GestureDetector(
                  onTap: () => _playTrack(index),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: isCurrentTrack
                          ? AppColors.chipBlueLight
                          : AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(
                        color: isCurrentTrack
                            ? AppColors.primaryBlue
                            : AppColors.inputBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isCurrentTrack ? Icons.play_circle : Icons.music_note,
                          color: isCurrentTrack
                              ? AppColors.primaryBlue
                              : AppColors.iconMuted,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track.title,
                                style: AppTextStyles.body.copyWith(
                                  fontSize: 14,
                                  color: isCurrentTrack
                                      ? AppColors.primaryBlueDark
                                      : AppColors.textDark,
                                  fontWeight: isCurrentTrack
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                              Text(
                                track.artist,
                                style: AppTextStyles.body.copyWith(
                                  fontSize: 12,
                                  color: AppColors.textGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          _formatDuration(track.duration),
                          style: AppTextStyles.body.copyWith(
                            fontSize: 12,
                            color: AppColors.textGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  MusicTrack  — represents an audio track
// ─────────────────────────────────────────────────────────────────────────────
class MusicTrack {
  final String title;
  final String artist;
  final String assetPath;
  final Duration duration;

  MusicTrack({
    required this.title,
    required this.artist,
    required this.assetPath,
    required this.duration,
  });
}
