import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:stranger_connect/screens/chat_screen.dart';
import 'package:stranger_connect/services/matchmaking_service.dart';
import 'package:stranger_connect/utils/app_theme.dart';

class MatchingScreen extends StatefulWidget {
  const MatchingScreen({super.key});

  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen> {
  late MatchmakingService _matchmakingService;
  StreamSubscription<MatchmakingState>? _subscription;
  MatchmakingStatus _status = MatchmakingStatus.searching;

  @override
  void initState() {
    super.initState();
    _matchmakingService = context.read<MatchmakingService>();
    _subscription = _matchmakingService.stateStream.listen(_onStateChange);
    _matchmakingService.joinQueue();
  }

  void _onStateChange(MatchmakingState state) {
    if (!mounted) return;

    setState(() => _status = state.status);

    if (state.status == MatchmakingStatus.matched && state.chatRoomId != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(chatRoomId: state.chatRoomId!),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    if (_status == MatchmakingStatus.searching) {
      _matchmakingService.leaveQueue();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_status) {
      case MatchmakingStatus.searching:
        return _buildSearching();
      case MatchmakingStatus.matched:
        return _buildMatched();
      case MatchmakingStatus.timeout:
        return _buildTimeout();
      case MatchmakingStatus.error:
        return _buildError();
      default:
        return _buildSearching();
    }
  }

  Widget _buildSearching() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.people_alt_rounded,
          size: 80,
          color: AppTheme.primaryColor,
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 1000.ms),
        const SizedBox(height: 32),
        const Text(
          'Looking for a stranger...',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Waiting for someone else\nto shake their phone',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 40),
        const CircularProgressIndicator(color: AppTheme.primaryColor),
      ],
    );
  }

  Widget _buildMatched() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.check_circle_rounded,
          size: 80,
          color: AppTheme.secondaryColor,
        ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
        const SizedBox(height: 24),
        const Text(
          'Match Found!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.secondaryColor,
          ),
        ).animate().fadeIn(duration: 300.ms),
      ],
    );
  }

  Widget _buildTimeout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.hourglass_empty_rounded,
          size: 80,
          color: AppTheme.textSecondary,
        ),
        const SizedBox(height: 24),
        const Text(
          'No one found',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Try again - someone might be\nshaking right now!',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: () {
            setState(() => _status = MatchmakingStatus.searching);
            _matchmakingService.joinQueue();
          },
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try Again'),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          size: 80,
          color: Colors.redAccent,
        ),
        const SizedBox(height: 24),
        const Text(
          'Something went wrong',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Go Back'),
        ),
      ],
    );
  }
}
