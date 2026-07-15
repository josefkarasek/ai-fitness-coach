import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/app_backend.dart';
import '../settings/app_preferences.dart';
import '../storage/local/local_cache_repository.dart';

const Color _bgTop = Color(0xFF050608);
const Color _bgBottom = Color(0xFF11151B);
const Color _surface = Color(0xFF15191F);
const Color _surfaceAlt = Color(0xFF101419);
const Color _surfaceRaised = Color(0xFF1B2027);
const Color _outline = Color(0xFF2A313B);
const Color _outlineSoft = Color(0xFF1F252D);
const Color _textPrimary = Color(0xFFF4F7FB);
const Color _textSecondary = Color(0xFFB1BBC8);
const Color _textMuted = Color(0xFF808B98);
const Color _accentGreen = Color(0xFF42D392);
const Color _accentBlue = Color(0xFF5EA4FF);
const Duration _backendRequestTimeout = Duration(seconds: 60);
const String _trainingPlanJobQueuedStatus = 'queued';
const String _trainingPlanJobRunningStatus = 'running';
const String _trainingPlanJobCompletedStatus = 'completed';
const String _trainingPlanJobFailedStatus = 'failed';
const List<String> _storedSessionFeelLabels = <String>[
  'Easy',
  'Good',
  'Hard',
  'Brutal',
];

enum _WorkoutFieldKind {
  reps,
  value,
  loadValue,
}

enum _RootTab {
  home,
  program,
  history,
  me,
}

String _formatTrimmedNumber(double value) {
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}

String _formatVolumeValue(double value) => _formatTrimmedNumber(value);

String _formatWorkoutFieldNumber(double value) => _formatTrimmedNumber(value);

String _formatRepsValue(double value) => value.round().toString();

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.preferences,
    required this.localCacheRepository,
  });

  final AppPreferences preferences;
  final DriftLocalCacheRepository localCacheRepository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _promoCodeController = TextEditingController();
  final TextEditingController _meUrlController = TextEditingController(
    text: AppBackend.me().toString(),
  );
  final TextEditingController _promoCodesRedeemUrlController =
      TextEditingController(
    text: AppBackend.redeemPromoCode().toString(),
  );
  final TextEditingController _importsUrlController = TextEditingController(
    text: AppBackend.imports().toString(),
  );
  final TextEditingController _workoutsUrlController = TextEditingController(
    text: AppBackend.workouts().toString(),
  );
  final TextEditingController _workoutLogsUrlController = TextEditingController(
    text: AppBackend.workoutLogs().toString(),
  );
  final TextEditingController _trainingPlansUrlController =
      TextEditingController(
    text: AppBackend.trainingPlans().toString(),
  );
  final TextEditingController _trainingPlansLatestUrlController =
      TextEditingController(
    text: AppBackend.latestTrainingPlan().toString(),
  );
  final TextEditingController _planObjectiveController = TextEditingController(
    text: 'Build a 12-week strength block',
  );
  final TextEditingController _planDurationWeeksController =
      TextEditingController(
    text: '12',
  );
  final TextEditingController _planDaysPerWeekController =
      TextEditingController(
    text: '4',
  );
  final TextEditingController _planConstraintsController =
      TextEditingController(
    text: 'Protect low back fatigue and keep sessions under 75 minutes',
  );
  final TextEditingController _planEquipmentController = TextEditingController(
    text: 'Barbell, dumbbells, cable machine, sled',
  );
  final TextEditingController _planNotesController = TextEditingController(
    text: 'Bias squat and deadlift progress while keeping upper body balanced.',
  );

  PlatformFile? _selectedArchive;
  bool _busy = false;
  String? _status;
  List<_WorkoutLogItem> _workoutLogs = <_WorkoutLogItem>[];
  _BackendUserProfile? _backendUser;
  bool _generatingTrainingPlan = false;
  bool _loadingAppState = true;
  bool _showPlanBuilder = false;
  _RootTab _selectedRootTab = _RootTab.home;
  String? _selectedWeekday;
  _TrainingPlanResult? _latestTrainingPlan;
  _TrainingPlanJob? _pendingTrainingPlanJob;
  _WeeklyCoachingPreview? _weeklyCoachingPreview;
  Map<String, _WorkoutSessionDraftSummary> _workoutSessionDraftsByKey =
      <String, _WorkoutSessionDraftSummary>{};
  String _deviceMeasurementSystem = _measurementSystemMetric;
  int? _viewedWeekNumber;
  int? _activeDisplayedWeekNumber;
  int? _activeDisplayedWeekPlanID;
  double _weekStripDragDistance = 0;
  double _weekStripOffset = 0;
  String? _lastResumePromptedDraftKey;
  bool _resumePromptVisible = false;
  late final AnimationController _weekStripAnimationController;
  Animation<double>? _weekStripOffsetAnimation;
  StreamSubscription<User?>? _authStateSubscription;
  StreamSubscription<String>? _fcmTokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _fcmForegroundSubscription;
  StreamSubscription<RemoteMessage>? _fcmOpenedSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _weekStripAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        if (!mounted || _weekStripOffsetAnimation == null) {
          return;
        }
        setState(() {
          _weekStripOffset = _weekStripOffsetAnimation!.value;
        });
      });
    _deviceMeasurementSystem = widget.preferences.measurementSystem;
    _authStateSubscription =
        _auth.authStateChanges().listen(_handleAuthStateChanged);
    _initializeFirebaseMessaging();
    _handleAuthStateChanged(_auth.currentUser);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authStateSubscription?.cancel();
    _fcmTokenRefreshSubscription?.cancel();
    _fcmForegroundSubscription?.cancel();
    _fcmOpenedSubscription?.cancel();
    _weekStripAnimationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _promoCodeController.dispose();
    _meUrlController.dispose();
    _promoCodesRedeemUrlController.dispose();
    _importsUrlController.dispose();
    _workoutsUrlController.dispose();
    _workoutLogsUrlController.dispose();
    _trainingPlansUrlController.dispose();
    _trainingPlansLatestUrlController.dispose();
    _planObjectiveController.dispose();
    _planDurationWeeksController.dispose();
    _planDaysPerWeekController.dispose();
    _planConstraintsController.dispose();
    _planEquipmentController.dispose();
    _planNotesController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshPendingTrainingPlanJobIfNeeded());
    }
  }

  Future<void> _initializeFirebaseMessaging() async {
    final FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();

    _fcmTokenRefreshSubscription =
        messaging.onTokenRefresh.listen((String token) {
      unawaited(_registerDeviceToken(token));
    });
    _fcmForegroundSubscription =
        FirebaseMessaging.onMessage.listen(_handleRemoteMessage);
    _fcmOpenedSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteMessage);

    final RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleRemoteMessage(initialMessage);
    }

    final String? token = await messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await _registerDeviceToken(token);
    }
  }

  Future<void> _registerCurrentDeviceToken() async {
    final String? token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      return;
    }
    await _registerDeviceToken(token);
  }

  Future<void> _registerDeviceToken(String token) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      return;
    }

    try {
      final String idToken = await _requireIdToken();
      await _performRequest(
        () => http.post(
          AppBackend.deviceTokens(),
          headers: <String, String>{
            HttpHeaders.authorizationHeader: 'Bearer $idToken',
            HttpHeaders.contentTypeHeader: 'application/json',
          },
          body: jsonEncode(<String, String>{
            'token': token,
            'platform': Platform.isAndroid ? 'android' : 'unknown',
          }),
        ),
        action: 'register push notifications',
      );
    } catch (_) {
      // Best effort only. The app should keep working without push registration.
    }
  }

  void _handleRemoteMessage(RemoteMessage message) {
    final String type = (message.data['type'] ?? '').toString().trim();
    final String jobID = (message.data['job_id'] ?? '').toString().trim();
    final String status = (message.data['status'] ?? '').toString().trim();
    if ((type != 'training_plan_ready' && type != 'training_plan_failed') ||
        jobID.isEmpty) {
      return;
    }

    unawaited(widget.preferences.setRemotePlanSignal(
      jobID: jobID,
      status: status.isEmpty ? type : status,
    ));
    unawaited(_refreshPendingTrainingPlanJobIfNeeded(force: true));
  }

  Future<void> _handleAuthStateChanged(User? user) async {
    if (!mounted) {
      return;
    }

    if (user == null) {
      await widget.preferences.setOnboardingCompleted(false);
      await widget.preferences.setLastSignedInUid('');
      setState(() {
        _loadingAppState = false;
        _showPlanBuilder = false;
        _workoutLogs = <_WorkoutLogItem>[];
        _backendUser = null;
        _selectedWeekday = null;
        _latestTrainingPlan = null;
        _pendingTrainingPlanJob = null;
        _weeklyCoachingPreview = null;
        _workoutSessionDraftsByKey = <String, _WorkoutSessionDraftSummary>{};
        _viewedWeekNumber = null;
        _activeDisplayedWeekNumber = null;
        _activeDisplayedWeekPlanID = null;
        _weekStripOffset = 0;
        _lastResumePromptedDraftKey = null;
        _resumePromptVisible = false;
      });
      return;
    }

    setState(() {
      _loadingAppState = true;
    });

    await _hydrateCachedStateForSignedInUser(user);
    await _hydrateLatestTrainingPlanForSignedInUser();
    await _registerCurrentDeviceToken();
    await _refreshPendingTrainingPlanJobIfNeeded();
    await widget.preferences.setLastSignedInUid(user.uid);

    if (!mounted) {
      return;
    }

    setState(() {
      _loadingAppState = false;
      _showPlanBuilder =
          _latestTrainingPlan == null && _pendingTrainingPlanJob == null;
    });
    _maybePromptToResumeWorkout();
  }

  Future<void> _hydrateLatestTrainingPlanForSignedInUser() async {
    try {
      final String token = await _requireIdToken();
      await _loadBackendUserProfile(token, announceStatus: false);
      final Uri uri = Uri.parse(_trainingPlansLatestUrlController.text.trim());
      final http.Response response = await _performRequest(
        () => http.get(
          uri,
          headers: <String, String>{
            HttpHeaders.authorizationHeader: 'Bearer $token',
          },
        ),
        action: 'restore your latest training block',
      );

      final String body = response.body;

      if (response.statusCode == HttpStatus.notFound) {
        setState(() {
          _latestTrainingPlan = null;
          _weeklyCoachingPreview = null;
          _viewedWeekNumber = null;
          _activeDisplayedWeekNumber = null;
          _activeDisplayedWeekPlanID = null;
        });
        return;
      }

      if (response.statusCode >= 400) {
        _setStatus(
          'Could not load your latest training block yet.',
        );
        return;
      }

      final _TrainingPlanResult? plan = _parseTrainingPlanFromResponse(body);
      if (plan == null) {
        return;
      }

      setState(() {
        _latestTrainingPlan = plan;
        _pendingTrainingPlanJob = null;
      });
      final User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        await widget.preferences.clearPendingTrainingPlanJobID(currentUser.uid);
        await widget.localCacheRepository.cacheTrainingPlan(
          planId: plan.planID,
          firebaseUid: currentUser.uid,
          payloadJson: body,
        );
      }
      await _loadWorkoutLogsForPlan(token, plan.planID, announceStatus: false);
      if (currentUser != null) {
        await _refreshCachedWorkoutSessionDraftsForPlan(
          firebaseUid: currentUser.uid,
          trainingPlanID: plan.planID,
        );
      }
      await _syncDisplayedWeekForCurrentPlan();
      await _maybeLoadWeeklyCoachingPreview(token, plan);
    } on _UiException {
      // Signed-in hydration should fail quietly and let the UI recover.
    } on _BackendConnectivityException {
      // Signed-in hydration should fail quietly and let the UI recover.
    } catch (_) {
      _setStatus('Could not restore your latest coaching state.');
    }
  }

  Future<void> _refreshPendingTrainingPlanJobIfNeeded(
      {bool force = false}) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      return;
    }

    final String pendingJobID =
        widget.preferences.getPendingTrainingPlanJobID(currentUser.uid);
    if (pendingJobID.isEmpty) {
      if (_pendingTrainingPlanJob != null && mounted) {
        setState(() {
          _pendingTrainingPlanJob = null;
        });
      }
      return;
    }

    final bool remoteSignalMatches =
        widget.preferences.remotePlanSignalJobID == pendingJobID;
    if (!force &&
        !remoteSignalMatches &&
        _pendingTrainingPlanJob != null &&
        _pendingTrainingPlanJob!.id == pendingJobID &&
        _pendingTrainingPlanJob!.isActive) {
      return;
    }

    try {
      final String token = await _requireIdToken();
      final http.Response response = await _performRequest(
        () => http.get(
          AppBackend.trainingPlanJob(pendingJobID),
          headers: <String, String>{
            HttpHeaders.authorizationHeader: 'Bearer $token',
          },
        ),
        action: 'check training plan status',
      );

      if (response.statusCode == HttpStatus.notFound) {
        await widget.preferences.clearPendingTrainingPlanJobID(currentUser.uid);
        await widget.preferences.clearRemotePlanSignal();
        if (!mounted) {
          return;
        }
        setState(() {
          _pendingTrainingPlanJob = null;
          _showPlanBuilder = _latestTrainingPlan == null;
        });
        return;
      }

      if (response.statusCode >= 400) {
        return;
      }

      final _TrainingPlanJob? job =
          _parseTrainingPlanJobFromResponse(response.body);
      if (job == null) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _pendingTrainingPlanJob = job;
      });

      if (job.status == _trainingPlanJobCompletedStatus) {
        await widget.preferences.clearPendingTrainingPlanJobID(currentUser.uid);
        await widget.preferences.clearRemotePlanSignal();
        await _hydrateLatestTrainingPlanForSignedInUser();
        if (mounted) {
          setState(() {
            _showPlanBuilder = _latestTrainingPlan == null;
          });
        }
        return;
      }

      if (job.status == _trainingPlanJobFailedStatus) {
        await widget.preferences.clearPendingTrainingPlanJobID(currentUser.uid);
        await widget.preferences.clearRemotePlanSignal();
        if (mounted) {
          setState(() {
            _showPlanBuilder = true;
          });
        }
        if (job.errorMessage.isNotEmpty) {
          _setStatus(job.errorMessage);
        } else {
          _setStatus('Training plan generation failed. Please try again.');
        }
        return;
      }

      if (remoteSignalMatches) {
        await widget.preferences.clearRemotePlanSignal();
      }
    } on _UiException {
      // Best effort refresh.
    } on _BackendConnectivityException {
      // Best effort refresh.
    }
  }

  Future<void> _hydrateCachedStateForSignedInUser(User user) async {
    final CachedPayloadSnapshot? cachedProfile =
        await widget.localCacheRepository.loadCachedUserProfile(user.uid);
    final CachedPayloadSnapshot? cachedPlan =
        await widget.localCacheRepository.loadLatestTrainingPlan(user.uid);

    _BackendUserProfile? backendUser;
    _TrainingPlanResult? trainingPlan;
    List<_WorkoutLogItem> workoutLogs = <_WorkoutLogItem>[];

    if (cachedProfile != null) {
      backendUser = _parseCachedBackendUserProfile(cachedProfile.payloadJson);
    }
    if (cachedPlan != null) {
      trainingPlan = _parseTrainingPlanFromResponse(cachedPlan.payloadJson);
    }
    if (trainingPlan != null) {
      final CachedPayloadSnapshot? cachedWorkoutLogs = await widget
          .localCacheRepository
          .loadWorkoutLogs(trainingPlan.planID);
      if (cachedWorkoutLogs != null) {
        workoutLogs =
            _parseWorkoutLogsFromResponse(cachedWorkoutLogs.payloadJson);
      }
      final List<_WorkoutLogItem> queuedWorkoutLogs =
          await _loadQueuedWorkoutLogs(
        firebaseUid: user.uid,
        trainingPlanID: trainingPlan.planID,
      );
      workoutLogs = _mergeQueuedWorkoutLogs(workoutLogs, queuedWorkoutLogs);
    }

    final Map<String, _WorkoutSessionDraftSummary> workoutSessionDraftsByKey =
        trainingPlan == null
            ? <String, _WorkoutSessionDraftSummary>{}
            : await _loadCachedWorkoutSessionDraftsForPlan(
                firebaseUid: user.uid,
                trainingPlanID: trainingPlan.planID,
              );
    final _WeeklyCoachingPreview? cachedWeeklyPreview = trainingPlan == null
        ? null
        : _loadCachedWeeklyCoachingPreview(
            firebaseUid: user.uid,
            plan: trainingPlan,
            workoutLogs: workoutLogs,
          );

    if (!mounted) {
      return;
    }

    setState(() {
      if (backendUser != null) {
        _backendUser = backendUser;
      }
      if (trainingPlan != null) {
        _latestTrainingPlan = trainingPlan;
      }
      if (workoutLogs.isNotEmpty) {
        _workoutLogs = workoutLogs;
      }
      _workoutSessionDraftsByKey = workoutSessionDraftsByKey;
      _weeklyCoachingPreview = cachedWeeklyPreview;
    });

    await _syncDisplayedWeekForCurrentPlan();
  }

  Widget _buildFullscreenScaffold({required Widget child}) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[_bgTop, _bgBottom],
          ),
        ),
        child: SafeArea(child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _auth.currentUser;
    final bool signedIn = user != null;
    final bool hasPlan = _latestTrainingPlan != null;

    if (_loadingAppState) {
      return _buildFullscreenScaffold(
        child: const _CenteredCoachState(
          eyebrow: 'Coach',
          title: 'Preparing your training space',
          body: 'Checking your account and loading the latest training block.',
          loading: true,
        ),
      );
    }

    if (!signedIn) {
      return _buildFullscreenScaffold(
        child: _AuthOnboardingScreen(
          emailController: _emailController,
          passwordController: _passwordController,
          promoCodeController: _promoCodeController,
          busy: _busy,
          status: _status,
          onCreateAccount: _signUp,
          onSignIn: _signIn,
        ),
      );
    }

    if (!hasPlan && _pendingTrainingPlanJob != null) {
      return _buildFullscreenScaffold(
        child: _CenteredCoachState(
          eyebrow: 'Coach',
          title: 'Your first block is being forged',
          body: _pendingTrainingPlanJob!.status == _trainingPlanJobFailedStatus
              ? (_pendingTrainingPlanJob!.errorMessage.isNotEmpty
                  ? _pendingTrainingPlanJob!.errorMessage
                  : 'The last plan request failed. Please try again.')
              : 'The request was sent. You can close the app and come back later; we will refresh as soon as the plan is ready.',
          loading: _pendingTrainingPlanJob!.isActive,
        ),
      );
    }

    if (!hasPlan || _showPlanBuilder) {
      return _buildFullscreenScaffold(
        child: _PlanOnboardingScreen(
          initialUsername: _backendUser?.displayName ?? user.displayName ?? '',
          initialTrainingExperience: _backendUser?.trainingExperience ??
              _trainingExperienceIntermediate,
          initialPrimaryGoal: _backendUser?.primaryGoal ?? _primaryGoalStrength,
          initialMeasurementSystem: _deviceMeasurementSystem,
          initialPreferredDays: _backendUser?.preferredDays ??
              const <String>[
                'Mon',
                'Tue',
                'Thu',
                'Fri',
              ],
          busy: _busy || _generatingTrainingPlan,
          generating: _generatingTrainingPlan,
          status: _status,
          allowSkip: hasPlan,
          onImportPastExercises:
              _busy ? null : _importPastExercisesFromEmptyState,
          onCancel: hasPlan
              ? () {
                  setState(() {
                    _showPlanBuilder = false;
                  });
                }
              : null,
          onSubmit: _submitCreateBlockForm,
        ),
      );
    }

    final _TrainingPlanResult? plan = _latestTrainingPlan;
    final List<_WorkoutLogItem> workoutLogsForPlan =
        _workoutLogsForPlan(plan?.planID);
    final int completedWorkouts = workoutLogsForPlan.length;
    final int currentWeekNumber = _currentWeekNumber(plan, workoutLogsForPlan);
    final int displayedWeekNumber =
        _displayedWeekNumber(plan, currentWeekNumber);
    final _UpcomingWorkoutData? upcomingWorkout =
        _upcomingWorkout(plan, workoutLogsForPlan, displayedWeekNumber);
    final _TrainingPlanWeek? currentWeek =
        _currentWeek(plan, displayedWeekNumber);
    final double blockProgress = _blockProgress(plan, completedWorkouts);
    final String athleteName = _athleteName(user, _backendUser);
    final _WeeklyTrainingStats weeklyStats = _weeklyTrainingStats(
      workoutLogsForPlan,
      currentWeek,
      displayedWeekNumber,
    );
    final List<_WeekdayWorkoutSlot> currentWeekSlots = _currentWeekSlots(
      currentWeek,
      workoutLogsForPlan
          .where(
              (_WorkoutLogItem item) => item.weekNumber == displayedWeekNumber)
          .toList(growable: false),
      _backendUser?.preferredDays ?? const <String>[],
      displayedWeekNumber == currentWeekNumber,
    );
    final List<_WeekdayWorkoutSlot>? previousWeekSlots = displayedWeekNumber > 1
        ? _weekSlotsForWeek(
            plan,
            workoutLogsForPlan,
            displayedWeekNumber - 1,
            _backendUser?.preferredDays ?? const <String>[],
            currentWeekNumber,
          )
        : null;
    final List<_WeekdayWorkoutSlot>? nextWeekSlots =
        plan != null && displayedWeekNumber < plan.durationWeeks
            ? _weekSlotsForWeek(
                plan,
                workoutLogsForPlan,
                displayedWeekNumber + 1,
                _backendUser?.preferredDays ?? const <String>[],
                currentWeekNumber,
              )
            : null;
    final _WeekdayWorkoutSlot? selectedWeekSlot =
        _selectedWeekSlot(currentWeekSlots);
    return Scaffold(
      bottomNavigationBar: _RootNavigationStrip(
        selectedTab: _selectedRootTab,
        onSelected: (_RootTab tab) {
          setState(() {
            _selectedRootTab = tab;
          });
        },
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              _bgTop,
              _bgBottom,
            ],
          ),
        ),
        child: SafeArea(
          child: IndexedStack(
            index: _selectedRootTab.index,
            children: <Widget>[
              _buildHomeTab(
                context: context,
                user: user,
                athleteName: athleteName,
                plan: plan,
                currentWeek: currentWeek,
                currentWeekNumber: currentWeekNumber,
                displayedWeekNumber: displayedWeekNumber,
                blockProgress: blockProgress,
                weeklyStats: weeklyStats,
                currentWeekSlots: currentWeekSlots,
                previousWeekSlots: previousWeekSlots,
                nextWeekSlots: nextWeekSlots,
                selectedWeekSlot: selectedWeekSlot,
                workoutLogsForPlan: workoutLogsForPlan,
                upcomingWorkout: upcomingWorkout,
                signedIn: signedIn,
                hasPlan: hasPlan,
              ),
              _buildProgramTab(
                athleteName: athleteName,
                plan: plan,
                currentWeek: currentWeek,
                currentWeekNumber: displayedWeekNumber,
                upcomingWorkout: upcomingWorkout,
                blockProgress: blockProgress,
                completedWorkouts: completedWorkouts,
              ),
              _buildHistoryTab(
                context: context,
                plan: plan,
                workoutLogsForPlan: workoutLogsForPlan,
              ),
              _buildMeTab(
                user: user,
                athleteName: athleteName,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeTab({
    required BuildContext context,
    required User user,
    required String athleteName,
    required _TrainingPlanResult? plan,
    required _TrainingPlanWeek? currentWeek,
    required int currentWeekNumber,
    required int displayedWeekNumber,
    required double blockProgress,
    required _WeeklyTrainingStats weeklyStats,
    required List<_WeekdayWorkoutSlot> currentWeekSlots,
    required List<_WeekdayWorkoutSlot>? previousWeekSlots,
    required List<_WeekdayWorkoutSlot>? nextWeekSlots,
    required _WeekdayWorkoutSlot? selectedWeekSlot,
    required List<_WorkoutLogItem> workoutLogsForPlan,
    required _UpcomingWorkoutData? upcomingWorkout,
    required bool signedIn,
    required bool hasPlan,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _WeeklyProgressStrip(
            currentWeekNumber: displayedWeekNumber,
            blockProgress: blockProgress,
            totalReps: weeklyStats.totalReps,
            targetReps: weeklyStats.targetReps,
            totalVolume: weeklyStats.totalVolume,
            targetVolume: weeklyStats.targetVolume,
            volumeLabel: weeklyStats.volumeLabel,
            volumeProgress: weeklyStats.volumeProgress,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) {
              _weekStripAnimationController.stop();
              _weekStripOffsetAnimation = null;
              _weekStripDragDistance = 0;
            },
            onHorizontalDragUpdate: (DragUpdateDetails details) {
              final double delta = details.primaryDelta ?? 0;
              _weekStripDragDistance += delta;
              setState(() {
                _weekStripOffset += delta;
              });
            },
            onHorizontalDragEnd: (DragEndDetails details) {
              final double velocity = details.primaryVelocity ?? 0;
              final double distance = _weekStripDragDistance;
              _weekStripDragDistance = 0;
              _handleWeekStripDragEnd(
                plan: plan,
                fallbackWeekNumber: currentWeekNumber,
                viewportWidth: MediaQuery.sizeOf(context).width - 40,
                velocity: velocity,
                distance: distance,
              );
            },
            onHorizontalDragCancel: () {
              _weekStripDragDistance = 0;
              _animateWeekStripBack();
            },
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double width = constraints.maxWidth;

                return ClipRect(
                  child: SizedBox(
                    height: 64,
                    child: Stack(
                      children: <Widget>[
                        if (previousWeekSlots != null)
                          Transform.translate(
                            offset: Offset(_weekStripOffset - width, 0),
                            child: _WeekdayWorkoutStrip(
                              slots: previousWeekSlots,
                              selectedWeekday: selectedWeekSlot?.weekdayLabel,
                              onTap: (String weekday) {
                                setState(() {
                                  _selectedWeekday = weekday;
                                });
                              },
                              onLongPress: (_WeekdayWorkoutSlot slot) =>
                                  _handleWeekdayLongPress(
                                slot,
                                displayedWeekNumber - 1,
                              ),
                            ),
                          ),
                        Transform.translate(
                          offset: Offset(_weekStripOffset, 0),
                          child: _WeekdayWorkoutStrip(
                            slots: currentWeekSlots,
                            selectedWeekday: selectedWeekSlot?.weekdayLabel,
                            onTap: (String weekday) {
                              setState(() {
                                _selectedWeekday = weekday;
                              });
                            },
                            onLongPress: (_WeekdayWorkoutSlot slot) =>
                                _handleWeekdayLongPress(
                              slot,
                              displayedWeekNumber,
                            ),
                          ),
                        ),
                        if (nextWeekSlots != null)
                          Transform.translate(
                            offset: Offset(_weekStripOffset + width, 0),
                            child: _WeekdayWorkoutStrip(
                              slots: nextWeekSlots,
                              selectedWeekday: selectedWeekSlot?.weekdayLabel,
                              onTap: (String weekday) {
                                setState(() {
                                  _selectedWeekday = weekday;
                                });
                              },
                              onLongPress: (_WeekdayWorkoutSlot slot) =>
                                  _handleWeekdayLongPress(
                                slot,
                                displayedWeekNumber + 1,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (plan != null &&
              selectedWeekSlot != null &&
              (selectedWeekSlot.loggedWorkout != null ||
                  selectedWeekSlot.draftSummary != null ||
                  selectedWeekSlot.workout != null ||
                  selectedWeekSlot.isCurrentDay)) ...<Widget>[
            const SizedBox(height: 12),
            _SelectedDayWorkoutCard(
              slot: selectedWeekSlot,
              weekNumber: displayedWeekNumber,
              currentWeekNumber: currentWeekNumber,
              upcomingWorkout: upcomingWorkout,
              onOpenLoggedWorkout: selectedWeekSlot.loggedWorkout == null
                  ? null
                  : () => _showWorkoutReviewScreen(
                        context,
                        plan,
                        selectedWeekSlot.loggedWorkout!,
                      ),
              onResumeDraft: selectedWeekSlot.draftSummary == null ||
                      selectedWeekSlot.workout == null
                  ? null
                  : () => _showWorkoutPreview(
                        context,
                        plan,
                        _upcomingWorkoutDataFromSlot(
                          selectedWeekSlot,
                          displayedWeekNumber,
                        ),
                      ),
              onPreviewWorkout: selectedWeekSlot.workout == null
                  ? null
                  : () => _showWorkoutPreview(
                        context,
                        plan,
                        _upcomingWorkoutDataFromSlot(
                          selectedWeekSlot,
                          displayedWeekNumber,
                        ),
                        existingLog: selectedWeekSlot.loggedWorkout,
                      ),
            ),
          ],
          if (plan != null &&
              _weeklyCoachingPreview != null &&
              displayedWeekNumber == currentWeekNumber) ...<Widget>[
            const SizedBox(height: 18),
            _WeeklyTransitionCard(
              currentWeekNumber: displayedWeekNumber,
              weeklyPreview: _weeklyCoachingPreview,
              lastWeekRecap: _lastWeekRecap(
                plan,
                workoutLogsForPlan,
                currentWeekNumber,
              ),
              whatChanged: _whatChangedThisWeek(
                plan,
                currentWeekNumber,
              ),
            ),
          ],
          if (_status != null) ...<Widget>[
            const SizedBox(height: 14),
            _CoachStatusBanner(message: _status!),
          ],
        ],
      ),
    );
  }

  Widget _buildProgramTab({
    required String athleteName,
    required _TrainingPlanResult? plan,
    required _TrainingPlanWeek? currentWeek,
    required int currentWeekNumber,
    required _UpcomingWorkoutData? upcomingWorkout,
    required double blockProgress,
    required int completedWorkouts,
  }) {
    if (plan == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Generate your first block to unlock the full program view.',
            style: TextStyle(color: _textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return _CoachingBookContent(
      athleteName: athleteName,
      plan: plan,
      currentWeek: currentWeek,
      currentWeekNumber: currentWeekNumber,
      weeklyPreview: _weeklyCoachingPreview,
      programLabel: _programLabel(plan, _backendUser),
      nextMilestoneTitle: _nextMilestoneTitle(plan, currentWeekNumber),
      nextMilestoneBody: _nextMilestoneBody(
        plan,
        currentWeekNumber,
        _weeklyCoachingPreview,
      ),
      blockProgress: blockProgress,
      completedWorkouts: completedWorkouts,
      initialSelectedWeekNumber: currentWeekNumber,
      topPadding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
    );
  }

  Widget _buildHistoryTab({
    required BuildContext context,
    required _TrainingPlanResult? plan,
    required List<_WorkoutLogItem> workoutLogsForPlan,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 16),
          const Text(
            'Previous Workouts',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            workoutLogsForPlan.isEmpty
                ? 'Your logged sessions will show up here.'
                : '${workoutLogsForPlan.length} sessions logged in this block.',
            style: const TextStyle(
              fontSize: 15,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          if (workoutLogsForPlan.isEmpty)
            const _Card(
              child: Text(
                'No workouts logged yet.',
                style: TextStyle(
                  fontSize: 15,
                  color: _textSecondary,
                ),
              ),
            )
          else
            _RecentWorkoutLogsCard(
              logs: workoutLogsForPlan.reversed.toList(growable: false),
              onOpenLog: plan == null
                  ? null
                  : (_WorkoutLogItem log) =>
                      _showWorkoutReviewScreen(context, plan, log),
            ),
        ],
      ),
    );
  }

  Widget _buildMeTab({
    required User user,
    required String athleteName,
  }) {
    final String displayName = _backendUser?.displayName.isNotEmpty == true
        ? _backendUser!.displayName
        : athleteName;
    final String email = _backendUser?.email.isNotEmpty == true
        ? _backendUser!.email
        : (user.email ?? 'Not available');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 16),
          const Text(
            'Profile',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('Account'),
                const SizedBox(height: 14),
                _StatusRow(label: 'Username', value: displayName),
                const SizedBox(height: 12),
                _StatusRow(label: 'Email', value: email),
                const SizedBox(height: 12),
                _StatusRow(
                  label: 'Measurement system',
                  value: _deviceMeasurementSystem,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('Coaching Profile'),
                const SizedBox(height: 14),
                _StatusRow(
                  label: 'Training experience',
                  value: _backendUser?.trainingExperience.isNotEmpty == true
                      ? _backendUser!.trainingExperience
                      : 'Not set',
                ),
                const SizedBox(height: 12),
                _StatusRow(
                  label: 'Primary goal',
                  value: _backendUser?.primaryGoal.isNotEmpty == true
                      ? _backendUser!.primaryGoal
                      : 'Not set',
                ),
                const SizedBox(height: 12),
                _StatusRow(
                  label: 'Preferred days',
                  value: _backendUser?.preferredDays.isNotEmpty == true
                      ? _backendUser!.preferredDays.join(', ')
                      : 'Not set',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('Access'),
                const SizedBox(height: 14),
                _StatusRow(
                  label: 'Promo code',
                  value: _backendUser?.redeemedPromoCode.isNotEmpty == true
                      ? _backendUser!.redeemedPromoCode
                      : 'None',
                ),
                const SizedBox(height: 12),
                _StatusRow(
                  label: 'AI access',
                  value: _backendUser?.aiAccessEnabled == true
                      ? 'Enabled'
                      : 'Disabled',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _athleteName(User? user, _BackendUserProfile? backendUser) {
    final String? backendName = backendUser?.displayName.trim();
    if (backendName != null && backendName.isNotEmpty) {
      return backendName;
    }

    final String? displayName = user?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    final String? email = user?.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }

    return 'athlete';
  }

  int _currentWeekNumber(
    _TrainingPlanResult? plan,
    List<_WorkoutLogItem> workoutLogs,
  ) {
    final int rawWeekNumber = _rawCurrentWeekNumber(plan, workoutLogs);
    if (plan == null || plan.durationWeeks <= 0) {
      return rawWeekNumber;
    }
    if (_activeDisplayedWeekPlanID == plan.planID &&
        _activeDisplayedWeekNumber != null) {
      return _activeDisplayedWeekNumber!.clamp(1, plan.durationWeeks);
    }

    return rawWeekNumber;
  }

  int _displayedWeekNumber(_TrainingPlanResult? plan, int fallbackWeekNumber) {
    if (plan == null || plan.durationWeeks <= 0) {
      return fallbackWeekNumber;
    }
    if (_viewedWeekNumber == null) {
      return fallbackWeekNumber.clamp(1, plan.durationWeeks);
    }

    return _viewedWeekNumber!.clamp(1, plan.durationWeeks);
  }

  void _shiftViewedWeek(
    _TrainingPlanResult? plan,
    int delta,
    int fallbackWeekNumber,
  ) {
    if (plan == null || plan.durationWeeks <= 0 || delta == 0) {
      return;
    }

    final int currentDisplayedWeek =
        _displayedWeekNumber(plan, fallbackWeekNumber);
    final int nextWeek =
        (currentDisplayedWeek + delta).clamp(1, plan.durationWeeks);
    if (nextWeek == currentDisplayedWeek) {
      return;
    }

    setState(() {
      _viewedWeekNumber = nextWeek;
      _selectedWeekday = null;
    });
  }

  void _animateWeekStripTo(
    double targetOffset, {
    VoidCallback? onCompleted,
  }) {
    _weekStripAnimationController.stop();
    _weekStripOffsetAnimation = Tween<double>(
      begin: _weekStripOffset,
      end: targetOffset,
    ).animate(
      CurvedAnimation(
        parent: _weekStripAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _weekStripAnimationController
      ..reset()
      ..forward().whenCompleteOrCancel(() {
        onCompleted?.call();
      });
  }

  void _animateWeekStripBack() {
    _animateWeekStripTo(0, onCompleted: () {
      if (!mounted) {
        return;
      }
      setState(() {
        _weekStripOffset = 0;
      });
    });
  }

  void _handleWeekStripDragEnd({
    required _TrainingPlanResult? plan,
    required int fallbackWeekNumber,
    required double viewportWidth,
    required double velocity,
    required double distance,
  }) {
    if (plan == null || plan.durationWeeks <= 0) {
      _animateWeekStripBack();
      return;
    }

    final int displayedWeek = _displayedWeekNumber(plan, fallbackWeekNumber);
    final bool canMovePrevious = displayedWeek > 1;
    final bool canMoveNext = displayedWeek < plan.durationWeeks;
    final double threshold = math.max(56, viewportWidth * 0.22);

    if ((velocity > 250 || distance > threshold) && canMovePrevious) {
      _animateWeekStripTo(viewportWidth, onCompleted: () {
        if (!mounted) {
          return;
        }
        _shiftViewedWeek(plan, -1, fallbackWeekNumber);
        setState(() {
          _weekStripOffset = 0;
        });
      });
      return;
    }

    if ((velocity < -250 || distance < -threshold) && canMoveNext) {
      _animateWeekStripTo(-viewportWidth, onCompleted: () {
        if (!mounted) {
          return;
        }
        _shiftViewedWeek(plan, 1, fallbackWeekNumber);
        setState(() {
          _weekStripOffset = 0;
        });
      });
      return;
    }

    _animateWeekStripBack();
  }

  int _rawCurrentWeekNumber(
    _TrainingPlanResult? plan,
    List<_WorkoutLogItem> workoutLogs,
  ) {
    if (plan == null || plan.durationWeeks <= 0) {
      return 1;
    }

    for (final _TrainingPlanWeek week in plan.weeks) {
      final int plannedCount = week.workouts.length;
      if (plannedCount == 0) {
        continue;
      }
      final int completedCount = workoutLogs
          .where((_WorkoutLogItem item) => item.weekNumber == week.weekNumber)
          .length;
      if (completedCount < plannedCount) {
        return week.weekNumber;
      }
    }

    return plan.weeks.isEmpty ? 1 : plan.weeks.last.weekNumber;
  }

  DateTime _startOfWeek(DateTime value) {
    return DateTime(value.year, value.month, value.day)
        .subtract(Duration(days: value.weekday - 1));
  }

  String _weekAnchorKey(DateTime value) {
    final DateTime start = _startOfWeek(value);
    final String month = start.month.toString().padLeft(2, '0');
    final String day = start.day.toString().padLeft(2, '0');
    return '${start.year}-$month-$day';
  }

  Future<void> _syncDisplayedWeekForCurrentPlan() async {
    final User? currentUser = _auth.currentUser;
    final _TrainingPlanResult? plan = _latestTrainingPlan;
    if (currentUser == null || plan == null || plan.durationWeeks <= 0) {
      if (!mounted) {
        return;
      }
      setState(() {
        _viewedWeekNumber = null;
        _activeDisplayedWeekNumber = null;
        _activeDisplayedWeekPlanID = null;
      });
      return;
    }

    final List<_WorkoutLogItem> workoutLogs = _workoutLogsForPlan(plan.planID);
    final int rawWeekNumber = _rawCurrentWeekNumber(plan, workoutLogs);
    final String currentAnchor = _weekAnchorKey(DateTime.now());
    final int? savedWeekNumber = widget.preferences.activePlanWeekNumber(
      firebaseUid: currentUser.uid,
      trainingPlanId: plan.planID,
    );
    final String savedAnchor = widget.preferences.getActivePlanWeekAnchor(
      firebaseUid: currentUser.uid,
      trainingPlanId: plan.planID,
    );

    int displayedWeekNumber = rawWeekNumber;
    if (savedWeekNumber != null &&
        savedWeekNumber >= 1 &&
        savedWeekNumber <= plan.durationWeeks) {
      if (savedAnchor == currentAnchor && rawWeekNumber > savedWeekNumber) {
        displayedWeekNumber = savedWeekNumber;
      } else {
        displayedWeekNumber = rawWeekNumber;
      }
    }

    await widget.preferences.setActivePlanWeekNumber(
      firebaseUid: currentUser.uid,
      trainingPlanId: plan.planID,
      value: displayedWeekNumber,
    );
    await widget.preferences.setActivePlanWeekAnchor(
      firebaseUid: currentUser.uid,
      trainingPlanId: plan.planID,
      value: currentAnchor,
    );

    if (!mounted) {
      return;
    }
    setState(() {
      if (_viewedWeekNumber == null ||
          _viewedWeekNumber! > plan.durationWeeks ||
          _viewedWeekNumber! <= 0) {
        _viewedWeekNumber = displayedWeekNumber;
      }
      _activeDisplayedWeekNumber = displayedWeekNumber;
      _activeDisplayedWeekPlanID = plan.planID;
    });
  }

  _TrainingPlanWeek? _currentWeek(_TrainingPlanResult? plan, int weekNumber) {
    if (plan == null) {
      return null;
    }

    for (final _TrainingPlanWeek week in plan.weeks) {
      if (week.weekNumber == weekNumber) {
        return week;
      }
    }

    return plan.weeks.isEmpty ? null : plan.weeks.first;
  }

  List<_WeekdayWorkoutSlot> _currentWeekSlots(
    _TrainingPlanWeek? currentWeek,
    List<_WorkoutLogItem> workoutLogs,
    List<String> preferredDays,
    bool isDisplayedCurrentWeek,
  ) {
    final List<String> orderedPreferredDays =
        _weekdayOptions.where(preferredDays.contains).toList(growable: false);
    final List<_TrainingPlanWorkout> weekWorkouts =
        currentWeek?.workouts.toList() ?? <_TrainingPlanWorkout>[];
    weekWorkouts.sort(
      (_TrainingPlanWorkout a, _TrainingPlanWorkout b) =>
          a.dayNumber.compareTo(b.dayNumber),
    );

    final Map<int, _WorkoutLogItem> logsByDayNumber = <int, _WorkoutLogItem>{
      for (final _WorkoutLogItem item in workoutLogs) item.dayNumber: item,
    };
    final bool useDirectWeekdayMapping = _usesDirectWeekdayMapping(
      weekWorkouts,
      orderedPreferredDays,
    );

    return List<_WeekdayWorkoutSlot>.generate(_weekdayOptions.length, (int i) {
      final String label = _weekdayOptions[i];
      final _TrainingPlanWorkout? workout = useDirectWeekdayMapping
          ? _workoutForWeekdayIndex(weekWorkouts, i + 1)
          : _legacyScheduledWorkoutForLabel(
              label,
              weekWorkouts,
              orderedPreferredDays,
            );

      return _WeekdayWorkoutSlot(
        weekdayLabel: label,
        weekdayIndex: i + 1,
        isCurrentDay: isDisplayedCurrentWeek && DateTime.now().weekday == i + 1,
        workout: workout,
        loggedWorkout:
            workout == null ? null : logsByDayNumber[workout.dayNumber],
        draftSummary: workout == null
            ? null
            : _workoutSessionDraftsByKey[_workoutSessionDraftKey(
                trainingPlanID: _latestTrainingPlan?.planID ?? 0,
                weekNumber: currentWeek?.weekNumber ?? 0,
                dayNumber: workout.dayNumber,
              )],
      );
    });
  }

  List<_WeekdayWorkoutSlot> _weekSlotsForWeek(
    _TrainingPlanResult? plan,
    List<_WorkoutLogItem> workoutLogs,
    int weekNumber,
    List<String> preferredDays,
    int actualCurrentWeekNumber,
  ) {
    final _TrainingPlanWeek? week = _currentWeek(plan, weekNumber);
    return _currentWeekSlots(
      week,
      workoutLogs
          .where((_WorkoutLogItem item) => item.weekNumber == weekNumber)
          .toList(growable: false),
      preferredDays,
      weekNumber == actualCurrentWeekNumber,
    );
  }

  String _currentWeekdayLabel() {
    final int weekday = DateTime.now().weekday;
    return _weekdayOptions[weekday.clamp(1, 7) - 1];
  }

  _WeekdayWorkoutSlot? _selectedWeekSlot(List<_WeekdayWorkoutSlot> slots) {
    if (slots.isEmpty) {
      return null;
    }

    if (_selectedWeekday != null && _selectedWeekday!.isNotEmpty) {
      for (final _WeekdayWorkoutSlot slot in slots) {
        if (slot.weekdayLabel == _selectedWeekday) {
          return slot;
        }
      }
    }

    for (final _WeekdayWorkoutSlot slot in slots) {
      if (slot.draftSummary != null && slot.isCurrentDay) {
        return slot;
      }
    }

    for (final _WeekdayWorkoutSlot slot in slots) {
      if (slot.draftSummary != null) {
        return slot;
      }
    }

    final String currentWeekday = _currentWeekdayLabel();
    for (final _WeekdayWorkoutSlot slot in slots) {
      if (slot.weekdayLabel == currentWeekday) {
        return slot;
      }
    }

    return slots.first;
  }

  _UpcomingWorkoutData _upcomingWorkoutDataFromSlot(
    _WeekdayWorkoutSlot slot,
    int weekNumber,
  ) {
    final _TrainingPlanWorkout workout = slot.workout!;
    return _UpcomingWorkoutData(
      relativeLabel: slot.isCurrentDay ? 'Today' : 'Scheduled',
      weekNumber: weekNumber,
      dayNumber: workout.dayNumber,
      title: workout.title,
      focus: workout.focus,
      plannedExercises: workout.exercises,
    );
  }

  _UpcomingWorkoutData? _upcomingWorkout(
    _TrainingPlanResult? plan,
    List<_WorkoutLogItem> workoutLogs,
    int currentWeekNumber,
  ) {
    if (plan == null || plan.weeks.isEmpty) {
      return null;
    }
    final Map<String, _WorkoutLogItem> logsByKey = <String, _WorkoutLogItem>{
      for (final _WorkoutLogItem item in workoutLogs)
        '${item.weekNumber}:${item.dayNumber}': item,
    };
    final int todayIndex = DateTime.now().weekday;

    for (final _TrainingPlanWeek week in plan.weeks) {
      if (week.weekNumber < currentWeekNumber) {
        continue;
      }

      final List<_TrainingPlanWorkout> sortedWorkouts = week.workouts.toList()
        ..sort(
          (_TrainingPlanWorkout a, _TrainingPlanWorkout b) =>
              a.dayNumber.compareTo(b.dayNumber),
        );
      for (final _TrainingPlanWorkout workout in sortedWorkouts) {
        if (logsByKey.containsKey('${week.weekNumber}:${workout.dayNumber}')) {
          continue;
        }
        final bool isThisWeek = week.weekNumber == currentWeekNumber;
        if (isThisWeek && workout.dayNumber < todayIndex) {
          continue;
        }

        return _UpcomingWorkoutData(
          relativeLabel: isThisWeek
              ? (workout.dayNumber == todayIndex ? 'Today' : 'Upcoming')
              : 'Upcoming',
          weekNumber: week.weekNumber,
          dayNumber: workout.dayNumber,
          title: workout.title,
          focus: workout.focus,
          plannedExercises: workout.exercises,
        );
      }
    }

    return null;
  }

  _ResumableWorkoutContext? _resumableWorkoutContext(
    _TrainingPlanResult? plan,
  ) {
    if (plan == null || _workoutSessionDraftsByKey.isEmpty) {
      return null;
    }

    final List<_WorkoutSessionDraftSummary> orderedDrafts =
        _workoutSessionDraftsByKey.values.toList()
          ..sort(
            (
              _WorkoutSessionDraftSummary a,
              _WorkoutSessionDraftSummary b,
            ) =>
                b.updatedAt.compareTo(a.updatedAt),
          );

    for (final _WorkoutSessionDraftSummary draft in orderedDrafts) {
      if (draft.trainingPlanID != plan.planID) {
        continue;
      }

      _WorkoutLogItem? existingLog;
      for (final _WorkoutLogItem item in _workoutLogs) {
        if (item.trainingPlanID == draft.trainingPlanID &&
            item.weekNumber == draft.weekNumber &&
            item.dayNumber == draft.dayNumber) {
          existingLog = item;
          break;
        }
      }
      if (existingLog != null) {
        continue;
      }

      final _TrainingPlanWorkout? workout =
          plan.findWorkout(draft.weekNumber, draft.dayNumber);
      if (workout == null) {
        continue;
      }

      return _ResumableWorkoutContext(
        draft: draft,
        workout: _UpcomingWorkoutData(
          relativeLabel: draft.weekNumber ==
                  _currentWeekNumber(plan, _workoutLogsForPlan(plan.planID))
              ? (draft.dayNumber == DateTime.now().weekday ? 'Today' : 'Saved')
              : 'Saved',
          weekNumber: draft.weekNumber,
          dayNumber: draft.dayNumber,
          title: workout.title,
          focus: workout.focus,
          plannedExercises: workout.exercises,
        ),
      );
    }

    return null;
  }

  Future<void> _maybePromptToResumeWorkout() async {
    if (!mounted || _resumePromptVisible) {
      return;
    }

    final _TrainingPlanResult? plan = _latestTrainingPlan;
    final _ResumableWorkoutContext? resumable = _resumableWorkoutContext(plan);
    if (plan == null || resumable == null) {
      return;
    }

    final String draftKey = _workoutSessionDraftKey(
      trainingPlanID: resumable.draft.trainingPlanID,
      weekNumber: resumable.draft.weekNumber,
      dayNumber: resumable.draft.dayNumber,
    );
    if (_lastResumePromptedDraftKey == draftKey) {
      return;
    }

    _resumePromptVisible = true;
    _lastResumePromptedDraftKey = draftKey;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _resumePromptVisible = false;
        return;
      }

      final bool? shouldResume = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: _surface,
            title: const Text(
              'Resume workout?',
              style: TextStyle(color: _textPrimary),
            ),
            content: Text(
              'You have an in-progress ${resumable.workout.title} session saved on this device. Do you want to jump back in?',
              style: const TextStyle(
                color: _textSecondary,
                height: 1.5,
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Later'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Resume'),
              ),
            ],
          );
        },
      );

      _resumePromptVisible = false;
      if (!mounted || shouldResume != true) {
        return;
      }

      setState(() {
        _selectedWeekday = _weekdayOptions[
            resumable.workout.dayNumber.clamp(1, _weekdayOptions.length) - 1];
        _viewedWeekNumber = resumable.workout.weekNumber;
      });
      await _showWorkoutPreview(
        context,
        plan,
        resumable.workout,
      );
    });
  }

  bool _usesDirectWeekdayMapping(
    List<_TrainingPlanWorkout> workouts,
    List<String> orderedPreferredDays,
  ) {
    if (workouts.isEmpty) {
      return false;
    }

    final List<int> dayNumbers = workouts
        .map((_TrainingPlanWorkout workout) => workout.dayNumber)
        .toList()
      ..sort();
    final bool validWeekdays =
        dayNumbers.every((int value) => value >= 1 && value <= 7);
    final bool uniqueDays = dayNumbers.toSet().length == dayNumbers.length;
    if (!validWeekdays || !uniqueDays) {
      return false;
    }

    final bool legacySequential =
        orderedPreferredDays.length == workouts.length &&
            List<int>.generate(dayNumbers.length, (int index) => index + 1)
                .every((int expected) => dayNumbers[expected - 1] == expected);
    return !legacySequential;
  }

  _TrainingPlanWorkout? _legacyScheduledWorkoutForLabel(
    String label,
    List<_TrainingPlanWorkout> weekWorkouts,
    List<String> orderedPreferredDays,
  ) {
    final List<String> scheduledDays = orderedPreferredDays.isNotEmpty
        ? orderedPreferredDays
        : _weekdayOptions.take(weekWorkouts.length).toList(growable: false);
    final int scheduleIndex = scheduledDays.indexOf(label);
    if (scheduleIndex < 0 || scheduleIndex >= weekWorkouts.length) {
      return null;
    }

    return weekWorkouts[scheduleIndex];
  }

  _TrainingPlanWorkout? _workoutForWeekdayIndex(
    List<_TrainingPlanWorkout> workouts,
    int weekdayIndex,
  ) {
    for (final _TrainingPlanWorkout workout in workouts) {
      if (workout.dayNumber == weekdayIndex) {
        return workout;
      }
    }

    return null;
  }

  double _blockProgress(_TrainingPlanResult? plan, int completedWorkouts) {
    if (plan == null || plan.totalPlannedWorkouts <= 0) {
      return 0;
    }

    return (completedWorkouts / plan.totalPlannedWorkouts).clamp(0, 1);
  }

  String _programLabel(
    _TrainingPlanResult? plan,
    _BackendUserProfile? backendUser,
  ) {
    final String primaryGoal = backendUser?.primaryGoal.trim() ?? '';
    if (primaryGoal == _primaryGoalStrength) {
      return 'Absolute Strength';
    }
    if (primaryGoal == _primaryGoalVolume) {
      return 'Muscle Volume';
    }
    if (primaryGoal == _primaryGoalLoseWeight) {
      return 'Lean Recomposition';
    }

    final String objective = plan?.objective.toLowerCase() ?? '';
    if (objective.contains('strength')) {
      return 'Absolute Strength';
    }
    if (objective.contains('hypertrophy') || objective.contains('volume')) {
      return 'Muscle Volume';
    }
    if (objective.contains('fat-loss') || objective.contains('weight')) {
      return 'Lean Recomposition';
    }

    return 'Coached Progression';
  }

  int _nextMilestoneWeekNumber(
    _TrainingPlanResult? plan,
    int currentWeekNumber,
  ) {
    final int totalWeeks = plan?.durationWeeks ?? 0;
    if (totalWeeks <= 0) {
      return currentWeekNumber;
    }

    return math.min(totalWeeks, math.max(1, currentWeekNumber + 1));
  }

  String _nextMilestoneTitle(
    _TrainingPlanResult? plan,
    int currentWeekNumber,
  ) {
    final int nextWeekNumber =
        _nextMilestoneWeekNumber(plan, currentWeekNumber);
    if (nextWeekNumber <= currentWeekNumber) {
      return 'Final review';
    }

    return 'Week $nextWeekNumber';
  }

  String _nextMilestoneBody(
    _TrainingPlanResult? plan,
    int currentWeekNumber,
    _WeeklyCoachingPreview? weeklyPreview,
  ) {
    final int nextWeekNumber =
        _nextMilestoneWeekNumber(plan, currentWeekNumber);
    if (nextWeekNumber <= currentWeekNumber) {
      return 'Finish this block well, review the outcome, and prepare the next coaching cycle.';
    }

    final _TrainingPlanWeek? nextWeek = _currentWeek(plan, nextWeekNumber);
    final List<String> parts = <String>[];
    if (nextWeek != null && nextWeek.theme.trim().isNotEmpty) {
      parts.add(nextWeek.theme.trim());
    }
    if (weeklyPreview != null &&
        weeklyPreview.previewWeek == nextWeekNumber &&
        weeklyPreview.feedback.trim().isNotEmpty) {
      parts.add(_firstSentence(weeklyPreview.feedback));
    } else if (weeklyPreview != null &&
        weeklyPreview.previewWeek == nextWeekNumber &&
        weeklyPreview.motivation.trim().isNotEmpty) {
      parts.add(_firstSentence(weeklyPreview.motivation));
    }
    if (parts.isEmpty) {
      return 'Next week begins. Keep the current momentum and carry it forward.';
    }

    return parts.join(' ');
  }

  String _lastWeekRecap(
    _TrainingPlanResult? plan,
    List<_WorkoutLogItem> workoutLogs,
    int currentWeekNumber,
  ) {
    if (plan == null || currentWeekNumber <= 1) {
      return 'This block is just getting started, so the first signal is simply to settle into the work and establish repeatable training quality.';
    }

    final int previousWeekNumber = currentWeekNumber - 1;
    final _TrainingPlanWeek? previousWeek =
        _currentWeek(plan, previousWeekNumber);
    final List<_WorkoutLogItem> previousWeekLogs = workoutLogs
        .where((_WorkoutLogItem item) => item.weekNumber == previousWeekNumber)
        .toList(growable: false);
    final int plannedSessions = previousWeek?.workouts.length ?? 0;
    final int completedSessions = previousWeekLogs.length;
    final int totalReps = previousWeekLogs.fold<int>(
        0, (int total, _WorkoutLogItem item) => total + item.totalReps.round());

    final List<String> parts = <String>[
      'Last week you completed $completedSessions of $plannedSessions scheduled sessions'
          '${previousWeek?.theme.trim().isNotEmpty == true ? ' during ${previousWeek!.theme.trim()}' : ''}.',
      if (totalReps > 0)
        'That gave the coach roughly $totalReps logged reps of fresh signal to work from.',
    ];
    return parts.join(' ');
  }

  String _whatChangedThisWeek(
    _TrainingPlanResult? plan,
    int currentWeekNumber,
  ) {
    if (plan == null || currentWeekNumber <= 1) {
      return 'This first week establishes the baseline: movement quality, honest logging, and enough structure for the coach to learn from.';
    }

    final _TrainingPlanWeek? previousWeek =
        _currentWeek(plan, currentWeekNumber - 1);
    final _TrainingPlanWeek? currentWeek =
        _currentWeek(plan, currentWeekNumber);
    if (currentWeek == null) {
      return 'This week continues the block with a fresh emphasis.';
    }

    final List<String> parts = <String>[];
    if (previousWeek != null &&
        previousWeek.theme.trim().isNotEmpty &&
        currentWeek.theme.trim().isNotEmpty &&
        previousWeek.theme.trim() != currentWeek.theme.trim()) {
      parts.add(
        'The phase shifts from ${previousWeek.theme.trim()} into ${currentWeek.theme.trim()}.',
      );
    } else if (currentWeek.theme.trim().isNotEmpty) {
      parts.add('The emphasis this week is ${currentWeek.theme.trim()}.');
    }

    final Set<String> previousTitles = <String>{
      for (final _TrainingPlanWorkout workout
          in previousWeek?.workouts ?? const <_TrainingPlanWorkout>[])
        workout.title.trim(),
    };
    final List<String> newTitles = currentWeek.workouts
        .map((_TrainingPlanWorkout workout) => workout.title.trim())
        .where((String title) =>
            title.isNotEmpty && !previousTitles.contains(title))
        .take(2)
        .toList(growable: false);
    if (newTitles.isNotEmpty) {
      parts.add('New stress arrives through ${newTitles.join(' and ')}.');
    }

    if (parts.isEmpty) {
      return 'The structure stays broadly familiar, but the coach is adjusting the stress and emphasis to keep the block moving forward.';
    }
    return parts.join(' ');
  }

  String _firstSentence(String text) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final RegExp sentenceBoundary = RegExp(r'(?<=[.!?])\s+');
    final List<String> parts = trimmed.split(sentenceBoundary);
    return parts.first.trim();
  }

  Future<void> _showWorkoutPreview(
    BuildContext context,
    _TrainingPlanResult plan,
    _UpcomingWorkoutData workout, {
    _WorkoutLogItem? existingLog,
  }) async {
    _WorkoutSessionDraftSnapshot? initialDraftSnapshot;
    final User? currentUser = _auth.currentUser;
    if (existingLog == null && currentUser != null) {
      final CachedPayloadSnapshot? cachedDraft =
          await widget.localCacheRepository.loadWorkoutSessionDraft(
        firebaseUid: currentUser.uid,
        trainingPlanId: plan.planID,
        weekNumber: workout.weekNumber,
        dayNumber: workout.dayNumber,
      );
      if (cachedDraft != null) {
        initialDraftSnapshot = _parseWorkoutSessionDraftSnapshot(
          cachedDraft.payloadJson,
        );
      }
    }

    final _WorkoutLogDraft? result =
        await Navigator.of(context).push<_WorkoutLogDraft>(
      MaterialPageRoute<_WorkoutLogDraft>(
        builder: (BuildContext context) {
          return _WorkoutSessionScreen(
            plan: plan,
            workout: workout,
            existingLog: existingLog,
            initialDraftSnapshot: initialDraftSnapshot,
            localCacheRepository: widget.localCacheRepository,
            firebaseUid: currentUser?.uid,
          );
        },
      ),
    );

    if (result == null) {
      final User? signedInUser = _auth.currentUser;
      if (signedInUser != null) {
        await _refreshCachedWorkoutSessionDraftsForPlan(
          firebaseUid: signedInUser.uid,
          trainingPlanID: plan.planID,
        );
      }
      return;
    }

    final _WorkoutLogItem? savedLog = await _saveWorkoutLog(result);
    if (!mounted || savedLog == null) {
      return;
    }

    await _showWorkoutReviewScreen(
        context, _latestTrainingPlan ?? plan, savedLog);
  }

  Future<void> _showWorkoutReviewScreen(
    BuildContext context,
    _TrainingPlanResult plan,
    _WorkoutLogItem savedLog,
  ) async {
    final _TrainingPlanWorkout? plannedWorkout =
        plan.findWorkout(savedLog.weekNumber, savedLog.dayNumber);
    final _WorkoutReviewDetails reviewDetails =
        _buildWorkoutReviewDetails(savedLog);

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return _WorkoutReviewScreen(
            plan: plan,
            savedLog: savedLog,
            plannedWorkout: plannedWorkout,
            reviewDetails: reviewDetails,
            onOpenCoachingBook: () => _showCoachingBookSheet(
              context,
              plan,
              _athleteName(_auth.currentUser, _backendUser),
              _currentWeek(plan, savedLog.weekNumber),
              savedLog.weekNumber,
              _weeklyCoachingPreview,
              initialSelectedWeekNumber: savedLog.weekNumber,
            ),
          );
        },
      ),
    );
  }

  Future<void> _showCoachingBookSheet(
      BuildContext context,
      _TrainingPlanResult plan,
      String athleteName,
      _TrainingPlanWeek? currentWeek,
      int currentWeekNumber,
      _WeeklyCoachingPreview? weeklyPreview,
      {int? initialSelectedWeekNumber}) async {
    final int completedWorkouts = _workoutLogs
        .where((_WorkoutLogItem item) => item.trainingPlanID == plan.planID)
        .length;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return _CoachingBookScreen(
            athleteName: athleteName,
            plan: plan,
            currentWeek: currentWeek,
            currentWeekNumber: currentWeekNumber,
            weeklyPreview: weeklyPreview,
            programLabel: _programLabel(plan, _backendUser),
            nextMilestoneTitle: _nextMilestoneTitle(plan, currentWeekNumber),
            nextMilestoneBody: _nextMilestoneBody(
              plan,
              currentWeekNumber,
              weeklyPreview,
            ),
            blockProgress: _blockProgress(plan, completedWorkouts),
            completedWorkouts: completedWorkouts,
            initialSelectedWeekNumber: initialSelectedWeekNumber,
          );
        },
      ),
    );
  }

  _WorkoutReviewDetails _buildWorkoutReviewDetails(_WorkoutLogItem savedLog) {
    final _ParsedSessionFeedback parsedFeedback =
        _parseStoredSessionFeedback(savedLog.sessionNotes);

    return _WorkoutReviewDetails(
      setCount: savedLog.setCount,
      completedSetCount: savedLog.completedSetCount,
      totalReps: savedLog.totalReps,
      estimatedVolume: savedLog.estimatedVolume,
      estimatedVolumeUnit: savedLog.estimatedVolumeUnit,
      parsedFeedback: parsedFeedback,
    );
  }

  _ParsedSessionFeedback _parseStoredSessionFeedback(String raw) {
    final RegExp prefixedPattern = RegExp(
      r'^Session feel:\s*(Easy|Good|Hard|Brutal)\.?(?:\s*Athlete note:\s*(.*))?$',
      caseSensitive: false,
      dotAll: true,
    );
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const _ParsedSessionFeedback(feelIndex: 1, note: '');
    }

    final Match? prefixedMatch = prefixedPattern.firstMatch(trimmed);
    if (prefixedMatch == null) {
      return _ParsedSessionFeedback(feelIndex: 1, note: trimmed);
    }

    final String feelLabel =
        _normalizeStoredFeelLabel(prefixedMatch.group(1) ?? 'Good');
    return _ParsedSessionFeedback(
      feelIndex: _storedSessionFeelLabels.indexOf(feelLabel),
      note: (prefixedMatch.group(2) ?? '').trim(),
    );
  }

  String _normalizeStoredFeelLabel(String raw) {
    final String lower = raw.trim().toLowerCase();
    for (final String label in _storedSessionFeelLabels) {
      if (label.toLowerCase() == lower) {
        return label;
      }
    }
    return 'Good';
  }

  bool _isTrackedLoadUnit(String unit) {
    const Set<String> loadUnits = <String>{
      'kg',
      'kilogram',
      'kilograms',
      'lb',
      'lbs',
      'pound',
      'pounds',
    };
    return loadUnits.contains(unit.trim().toLowerCase());
  }

  void _appendPlannedTrackedVolume(
    Map<String, double> target,
    _PlannedSet set,
  ) {
    double? value;
    String unit = '';

    if (_isTrackedLoadUnit(set.loadUnit) &&
        set.loadValue != null &&
        set.loadValue! > 0) {
      value = set.loadValue;
      unit = set.loadUnit.trim();
    } else if (_isTrackedLoadUnit(set.targetUnit) &&
        set.targetValue != null &&
        set.targetValue! > 0) {
      value = set.targetValue;
      unit = set.targetUnit.trim();
    }

    if (value == null || unit.isEmpty) {
      return;
    }

    final double multiplier = set.reps != null && set.reps! > 0 ? set.reps! : 1;
    target[unit] = (target[unit] ?? 0) + (multiplier * value);
  }

  void _appendLoggedTrackedVolumeFromDraftSetItem(
    Map<String, double> target,
    _WorkoutLogDraftSet set,
  ) {
    if (!set.completed) {
      return;
    }

    double? value;
    String unit = '';

    if (_isTrackedLoadUnit(set.loadUnit) &&
        set.loadValue != null &&
        set.loadValue! > 0) {
      value = set.loadValue;
      unit = set.loadUnit.trim();
    } else if (_isTrackedLoadUnit(set.unit) &&
        set.value != null &&
        set.value! > 0) {
      value = set.value;
      unit = set.unit.trim();
    }

    if (value == null || unit.isEmpty) {
      return;
    }

    final double multiplier = set.reps != null && set.reps! > 0 ? set.reps! : 1;
    target[unit] = (target[unit] ?? 0) + (multiplier * value);
  }

  Future<void> _signUp() async {
    await _runBusyAction(() async {
      await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final String promoCode = _promoCodeController.text.trim();
      if (promoCode.isNotEmpty) {
        final String token = await _requireIdToken();
        await _redeemPromoCode(token, promoCode);
      }
    });
  }

  Future<void> _signIn() async {
    await _runBusyAction(() async {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final String promoCode = _promoCodeController.text.trim();
      if (promoCode.isNotEmpty) {
        final String token = await _requireIdToken();
        await _redeemPromoCode(token, promoCode);
      }
    });
  }

  Future<void> _redeemPromoCode(String token, String promoCode) async {
    final Uri uri = Uri.parse(_promoCodesRedeemUrlController.text.trim());
    final http.Response response = await _performRequest(
      () => http.post(
        uri,
        headers: <String, String>{
          HttpHeaders.authorizationHeader: 'Bearer $token',
          HttpHeaders.contentTypeHeader: 'application/json',
        },
        body: jsonEncode(<String, String>{'code': promoCode}),
      ),
      action: 'redeem the promo code',
    );

    if (response.statusCode == HttpStatus.notFound) {
      throw const _UiException('Promo code not found.');
    }
    if (response.statusCode >= 400) {
      throw _UiException(_formatBackendFailure(
        action: 'redeem the promo code',
        response: response,
      ));
    }

    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      return;
    }
    final Object? userValue = decoded['user'];
    if (userValue is! Map) {
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _backendUser = _BackendUserProfile.fromJson(
        Map<String, dynamic>.from(userValue),
      );
    });
  }

  Future<void> _submitCreateBlockForm(_CreateBlockFormResult result) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      _setStatus('Sign in before building your training block.');
      return;
    }

    final String trimmedUsername = result.username.trim();
    if (trimmedUsername.isNotEmpty &&
        trimmedUsername != currentUser.displayName) {
      await currentUser.updateDisplayName(trimmedUsername);
    }

    setState(() {
      _backendUser = _BackendUserProfile(
        id: _backendUser?.id ?? '',
        firebaseUID: _backendUser?.firebaseUID ?? '',
        email: _backendUser?.email ?? currentUser.email ?? '',
        displayName: trimmedUsername,
        trainingExperience: result.trainingExperience,
        primaryGoal: result.primaryGoal,
        preferredDays: result.preferredDays,
        redeemedPromoCode: _backendUser?.redeemedPromoCode ?? '',
        aiAccessEnabled: _backendUser?.aiAccessEnabled ?? false,
      );
      _deviceMeasurementSystem = result.measurementSystem;
    });
    await widget.preferences.setMeasurementSystem(result.measurementSystem);
    await widget.preferences.setOnboardingCompleted(true);

    _planObjectiveController.text = _buildObjectiveFromProfile(result);
    _planDurationWeeksController.text = '${result.durationWeeks}';
    _planDaysPerWeekController.text = '${result.daysPerWeek}';
    _planConstraintsController.text = '';
    _planEquipmentController.text = '';
    _planNotesController.text = _buildPlanNotesFromProfile(result);

    final _TrainingPlanJob? pendingJob = await _generateTrainingPlan();
    if (!mounted) {
      return;
    }
    try {
      final String token = await _requireIdToken();
      await _loadBackendUserProfile(token, announceStatus: false);
    } on _UiException {
      // Let the generated plan drive the happy path even if profile refresh lags.
    }
    if (_latestTrainingPlan != null || pendingJob != null) {
      setState(() {
        _showPlanBuilder = false;
      });
    }
  }

  String _buildObjectiveFromProfile(_CreateBlockFormResult result) {
    final String durationPrefix = 'Build a ${result.durationWeeks}-week';
    switch (result.primaryGoal) {
      case _primaryGoalStrength:
        return '$durationPrefix strength block';
      case _primaryGoalVolume:
        return '$durationPrefix hypertrophy block';
      case _primaryGoalLoseWeight:
        return '$durationPrefix fat-loss block that preserves strength';
    }

    return '$durationPrefix training block';
  }

  String _buildPlanNotesFromProfile(_CreateBlockFormResult result) {
    final List<String> notes = <String>[
      'Athlete profile:',
      'Name: ${result.username}',
      'Training experience: ${result.trainingExperience}',
      'Primary goal: ${result.primaryGoal}',
      'Program duration: ${result.durationWeeks} weeks',
      'Measurement system: ${result.measurementSystem}',
      'Days per week: ${result.daysPerWeek}',
      'Preferred training days: ${result.preferredDays.join(', ')}',
    ];

    return notes.join('. ');
  }

  Future<void> _importPastExercisesFromEmptyState() async {
    await _runBusyAction(() async {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>['zip'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        _showToast('Past training import cancelled.');
        return;
      }

      setState(() {
        _selectedArchive = result.files.single;
      });

      await _uploadArchiveWithCurrentSelection(announceStatus: false);
      _showToast('Past exercises uploaded successfully.');
    });
  }

  Future<_TrainingPlanJob?> _generateTrainingPlan() async {
    setState(() {
      _generatingTrainingPlan = true;
    });

    _TrainingPlanJob? submittedJob;
    try {
      await _runBusyAction(() async {
        final String token = await _requireIdToken();
        final int durationWeeks = int.tryParse(
              _planDurationWeeksController.text.trim(),
            ) ??
            0;
        final int daysPerWeek =
            int.tryParse(_planDaysPerWeekController.text.trim()) ?? 0;

        final Uri uri = Uri.parse(_trainingPlansUrlController.text.trim());
        final http.Response response = await _performRequest(
          () => http.post(
            uri,
            headers: <String, String>{
              HttpHeaders.authorizationHeader: 'Bearer $token',
              HttpHeaders.contentTypeHeader: 'application/json',
            },
            body: jsonEncode(<String, Object>{
              'objective': _planObjectiveController.text.trim(),
              'duration_weeks': durationWeeks,
              'days_per_week': daysPerWeek,
              'measurement_system': _deviceMeasurementSystem,
              'constraints': _planConstraintsController.text.trim(),
              'equipment': _planEquipmentController.text.trim(),
              'notes': _planNotesController.text.trim(),
              'profile': <String, Object>{
                'display_name': _backendUser?.displayName.isNotEmpty == true
                    ? _backendUser!.displayName
                    : (_auth.currentUser?.displayName ?? ''),
                'training_experience': _backendUser?.trainingExperience ?? '',
                'primary_goal': _backendUser?.primaryGoal ?? '',
                'preferred_days':
                    _backendUser?.preferredDays ?? const <String>[],
              },
            }),
          ),
          action: 'generate the training plan',
        );

        final String body = response.body;

        if (response.statusCode == 429) {
          _setStatus(
            'Daily plan generation limit reached. Load your latest block or raise AI_DAILY_TRAINING_PLANS_LIMIT for local development.',
          );
          return;
        }

        if (response.statusCode != HttpStatus.accepted) {
          throw _UiException(_formatBackendFailure(
            action: 'queue the training plan request',
            response: response,
          ));
        }

        final _TrainingPlanJob? job = _parseTrainingPlanJobFromResponse(body);
        if (job == null) {
          _setStatus('Training plan queue response did not include job data.');
          return;
        }

        submittedJob = job;
        final User? currentUser = _auth.currentUser;
        if (currentUser != null) {
          await widget.preferences.setPendingTrainingPlanJobID(
            firebaseUid: currentUser.uid,
            jobID: job.id,
          );
        }

        setState(() {
          _pendingTrainingPlanJob = job;
          _latestTrainingPlan = null;
          _showPlanBuilder = false;
        });
        _setStatus(
          job.created
              ? 'Your coach is writing the block now.'
              : 'A training plan is already being generated.',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _generatingTrainingPlan = false;
        });
      }
    }

    return submittedJob;
  }

  Future<void> _handleWeekdayLongPress(
    _WeekdayWorkoutSlot slot,
    int currentWeekNumber,
  ) async {
    if (_latestTrainingPlan == null || _busy) {
      return;
    }
    if (slot.loggedWorkout != null ||
        slot.weekdayIndex < DateTime.now().weekday) {
      return;
    }

    if (!slot.hasWorkout || slot.workout == null) {
      final bool? shouldGenerate = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: _surface,
            title: const Text(
              'Generate extra workout?',
              style: TextStyle(color: _textPrimary),
            ),
            content: Text(
              'Generate a coach-planned workout for ${slot.weekdayLabel} in week $currentWeekNumber.',
              style: const TextStyle(color: _textSecondary, height: 1.5),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Generate'),
              ),
            ],
          );
        },
      );
      if (shouldGenerate == true) {
        await _generateWorkoutForDay(
          _latestTrainingPlan!.planID,
          currentWeekNumber,
          slot.weekdayIndex,
          selectedWeekday: slot.weekdayLabel,
        );
      }
      return;
    }

    final String? action = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _surface,
          title: const Text(
            'Adjust scheduled workout',
            style: TextStyle(color: _textPrimary),
          ),
          content: Text(
            'Choose what to do with ${slot.workout!.title} on ${slot.weekdayLabel}.',
            style: const TextStyle(color: _textSecondary, height: 1.5),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop('skip'),
              child: const Text('Skip'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop('move'),
              child: const Text('Move'),
            ),
          ],
        );
      },
    );

    if (action == 'skip') {
      await _skipWorkout(
        _latestTrainingPlan!.planID,
        currentWeekNumber,
        slot.workout!.dayNumber,
        selectedWeekday: slot.weekdayLabel,
      );
      return;
    }

    if (action == 'move') {
      final _WeekdayWorkoutSlot? targetSlot = await _pickMoveTargetDay(
        slot,
        currentWeekNumber,
      );
      if (targetSlot == null) {
        return;
      }
      await _moveWorkout(
        _latestTrainingPlan!.planID,
        currentWeekNumber,
        slot.workout!.dayNumber,
        targetSlot.weekdayIndex,
        selectedWeekday: targetSlot.weekdayLabel,
      );
    }
  }

  Future<_WeekdayWorkoutSlot?> _pickMoveTargetDay(
    _WeekdayWorkoutSlot sourceSlot,
    int currentWeekNumber,
  ) async {
    final _TrainingPlanWeek? currentWeek =
        _currentWeek(_latestTrainingPlan, currentWeekNumber);
    final List<_WeekdayWorkoutSlot> slots = _currentWeekSlots(
      currentWeek,
      _workoutLogsForPlan(_latestTrainingPlan?.planID)
          .where((_WorkoutLogItem item) => item.weekNumber == currentWeekNumber)
          .toList(growable: false),
      _backendUser?.preferredDays ?? const <String>[],
      true,
    );
    final List<_WeekdayWorkoutSlot> candidates = slots
        .where(
          (_WeekdayWorkoutSlot slot) =>
              slot.weekdayIndex >= DateTime.now().weekday &&
              slot.loggedWorkout == null &&
              !slot.hasWorkout &&
              slot.weekdayIndex != sourceSlot.weekdayIndex,
        )
        .toList(growable: false);
    if (candidates.isEmpty) {
      _showToast(
          'No empty current or future day is available for moving this workout.');
      return null;
    }

    return showDialog<_WeekdayWorkoutSlot>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _surface,
          title: const Text(
            'Move workout to',
            style: TextStyle(color: _textPrimary),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: candidates
                  .map(
                    (_WeekdayWorkoutSlot slot) => ActionChip(
                      backgroundColor: _surfaceRaised,
                      side: const BorderSide(color: _outline),
                      label: Text(
                        slot.weekdayLabel,
                        style: const TextStyle(color: _textPrimary),
                      ),
                      onPressed: () => Navigator.of(context).pop(slot),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _generateWorkoutForDay(
    int trainingPlanID,
    int weekNumber,
    int dayNumber, {
    String? selectedWeekday,
  }) async {
    await _mutateTrainingPlan(
      'generate-day',
      <String, Object>{
        'week_number': weekNumber,
        'day_number': dayNumber,
      },
      successMessage: 'Extra workout generated.',
      expectedStatusCodes: const <int>{HttpStatus.created},
      trainingPlanID: trainingPlanID,
      selectedWeekday: selectedWeekday,
    );
  }

  Future<void> _moveWorkout(
    int trainingPlanID,
    int weekNumber,
    int fromDayNumber,
    int toDayNumber, {
    String? selectedWeekday,
  }) async {
    await _mutateTrainingPlan(
      'move-workout',
      <String, Object>{
        'week_number': weekNumber,
        'from_day_number': fromDayNumber,
        'to_day_number': toDayNumber,
      },
      successMessage: 'Workout moved.',
      expectedStatusCodes: const <int>{HttpStatus.ok},
      trainingPlanID: trainingPlanID,
      selectedWeekday: selectedWeekday,
    );
  }

  Future<void> _skipWorkout(
    int trainingPlanID,
    int weekNumber,
    int dayNumber, {
    String? selectedWeekday,
  }) async {
    await _mutateTrainingPlan(
      'skip-workout',
      <String, Object>{
        'week_number': weekNumber,
        'day_number': dayNumber,
      },
      successMessage: 'Workout skipped.',
      expectedStatusCodes: const <int>{HttpStatus.ok},
      trainingPlanID: trainingPlanID,
      selectedWeekday: selectedWeekday,
    );
  }

  Future<void> _mutateTrainingPlan(
    String actionPath,
    Map<String, Object> payload, {
    required String successMessage,
    required Set<int> expectedStatusCodes,
    int? trainingPlanID,
    String? selectedWeekday,
  }) async {
    final int planID = trainingPlanID ?? _latestTrainingPlan?.planID ?? 0;
    if (planID <= 0) {
      return;
    }

    await _runBusyAction(() async {
      final String token = await _requireIdToken();
      final Uri uri = Uri.parse(
        '${_trainingPlansUrlController.text.trim()}/$planID/$actionPath',
      );
      final http.Response response = await _performRequest(
        () => http.post(
          uri,
          headers: <String, String>{
            HttpHeaders.authorizationHeader: 'Bearer $token',
            HttpHeaders.contentTypeHeader: 'application/json',
          },
          body: jsonEncode(payload),
        ),
        action: 'update the training plan',
      );

      final String body = response.body;

      if (!expectedStatusCodes.contains(response.statusCode)) {
        throw _UiException(_formatBackendFailure(
          action: 'update the training plan',
          response: response,
        ));
      }

      final _TrainingPlanResult? plan = _parseTrainingPlanFromResponse(body);
      if (plan == null) {
        _setStatus('Training plan update response did not include plan data.');
        return;
      }

      setState(() {
        _latestTrainingPlan = plan;
        if (selectedWeekday != null && selectedWeekday.isNotEmpty) {
          _selectedWeekday = selectedWeekday;
        }
      });
      final User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        await widget.localCacheRepository.cacheTrainingPlan(
          planId: plan.planID,
          firebaseUid: currentUser.uid,
          payloadJson: body,
        );
      }
      await _loadWorkoutLogsForPlan(token, plan.planID, announceStatus: false);
      if (currentUser != null) {
        await _refreshCachedWorkoutSessionDraftsForPlan(
          firebaseUid: currentUser.uid,
          trainingPlanID: plan.planID,
        );
      }
      await _syncDisplayedWeekForCurrentPlan();
      await _maybeLoadWeeklyCoachingPreview(token, plan);
      _setStatus(successMessage);
    });
  }

  Future<void> _uploadArchiveWithCurrentSelection({
    bool announceStatus = true,
  }) async {
    final PlatformFile? archive = _selectedArchive;
    if (archive == null) {
      throw const _UiException('Pick a TrainHeroic zip file first.');
    }

    final String token = await _requireIdToken();
    final Uri uri = Uri.parse(_importsUrlController.text.trim());
    final http.MultipartRequest request = http.MultipartRequest('POST', uri)
      ..headers[HttpHeaders.authorizationHeader] = 'Bearer $token'
      ..fields['import_type'] = 'trainheroic_csv';

    final List<int> archiveBytes = await _readArchiveBytes(archive);
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        archiveBytes,
        filename: archive.name,
      ),
    );

    final http.StreamedResponse response = await _performStreamedRequest(
      () => request.send(),
      action: 'import past training',
    );
    final String body = await response.stream.bytesToString();

    if (announceStatus) {
      _setStatus('Training import request completed.');
    }
    if (response.statusCode >= 400) {
      throw _UiException(_formatBackendFailure(
        action: 'import past training',
        statusCode: response.statusCode,
        responseBody: body,
      ));
    }
  }

  Future<_WorkoutLogItem?> _saveWorkoutLog(_WorkoutLogDraft draft) async {
    _WorkoutLogItem? result;
    await _runBusyAction(() async {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw const _UiException('You need to sign in first.');
      }

      final String token = await _requireIdToken();
      final Uri uri = Uri.parse(_workoutLogsUrlController.text.trim());
      try {
        final http.Response response = await _performRequest(
          () => http.post(
            uri,
            headers: <String, String>{
              HttpHeaders.authorizationHeader: 'Bearer $token',
              HttpHeaders.contentTypeHeader: 'application/json',
            },
            body: jsonEncode(draft.toJson()),
          ),
          action: 'save the workout log',
        );

        final String body = response.body;

        if (response.statusCode >= 400) {
          throw _UiException(_formatBackendFailure(
            action: 'save the workout log',
            response: response,
          ));
        }

        final _WorkoutLogItem? savedLog = _parseWorkoutLogFromResponse(body);
        if (savedLog == null) {
          _setStatus('Workout log response did not include log data.');
          return;
        }

        await widget.localCacheRepository.clearWorkoutLogSync(
          firebaseUid: currentUser.uid,
          entityKey: _workoutLogEntityKey(draft),
        );
        await widget.localCacheRepository.clearWorkoutSessionDraft(
          firebaseUid: currentUser.uid,
          trainingPlanId: draft.trainingPlanID,
          weekNumber: draft.weekNumber,
          dayNumber: draft.dayNumber,
        );
        _removeWorkoutSessionDraftFromState(
          trainingPlanID: draft.trainingPlanID,
          weekNumber: draft.weekNumber,
          dayNumber: draft.dayNumber,
        );

        final List<_WorkoutLogItem> updatedLogs = _upsertWorkoutLogItem(
          _workoutLogs,
          savedLog,
        );
        setState(() {
          _workoutLogs = updatedLogs;
        });
        await _syncDisplayedWeekForCurrentPlan();
        await _persistWorkoutLogSnapshot(
          firebaseUid: currentUser.uid,
          trainingPlanID: draft.trainingPlanID,
          logs: updatedLogs
              .where(
                (_WorkoutLogItem item) =>
                    item.trainingPlanID == draft.trainingPlanID,
              )
              .toList(growable: false),
        );
        if (_latestTrainingPlan != null) {
          await _maybeLoadWeeklyCoachingPreview(token, _latestTrainingPlan!);
        }
        result = savedLog;
        _setStatus('Workout log saved.');
      } on _BackendConnectivityException {
        await _queueWorkoutLogForSync(currentUser.uid, draft);
        await widget.localCacheRepository.clearWorkoutSessionDraft(
          firebaseUid: currentUser.uid,
          trainingPlanId: draft.trainingPlanID,
          weekNumber: draft.weekNumber,
          dayNumber: draft.dayNumber,
        );
        _removeWorkoutSessionDraftFromState(
          trainingPlanID: draft.trainingPlanID,
          weekNumber: draft.weekNumber,
          dayNumber: draft.dayNumber,
        );
        result = _workoutLogItemFromDraft(draft);
      }
    });

    return result;
  }

  Future<void> _loadWorkoutLogsForPlan(
    String token,
    int trainingPlanID, {
    bool announceStatus = true,
  }) async {
    final Uri baseUri = Uri.parse(_workoutLogsUrlController.text.trim());
    final Uri uri = baseUri.replace(
      queryParameters: <String, String>{
        'training_plan_id': '$trainingPlanID',
        'limit': '100',
      },
    );
    final http.Response response = await _performRequest(
      () => http.get(
        uri,
        headers: <String, String>{
          HttpHeaders.authorizationHeader: 'Bearer $token',
        },
      ),
      action: 'load workout logs',
    );

    final String body = response.body;

    if (response.statusCode >= 400) {
      throw _UiException(_formatBackendFailure(
        action: 'load workout logs',
        response: response,
      ));
    }

    final List<_WorkoutLogItem> logs = _parseWorkoutLogsFromResponse(body);
    final User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      await widget.localCacheRepository.cacheWorkoutLogs(
        trainingPlanId: trainingPlanID,
        firebaseUid: currentUser.uid,
        payloadJson: body,
      );
    }
    final List<_WorkoutLogItem> queuedWorkoutLogs = currentUser == null
        ? const <_WorkoutLogItem>[]
        : await _loadQueuedWorkoutLogs(
            firebaseUid: currentUser.uid,
            trainingPlanID: trainingPlanID,
          );
    setState(() {
      _workoutLogs = _mergeWorkoutLogsForPlan(
        _workoutLogs,
        trainingPlanID,
        _mergeQueuedWorkoutLogs(logs, queuedWorkoutLogs),
      );
    });
    if (currentUser != null) {
      await _refreshCachedWorkoutSessionDraftsForPlan(
        firebaseUid: currentUser.uid,
        trainingPlanID: trainingPlanID,
      );
    }
    await _syncDisplayedWeekForCurrentPlan();

    if (announceStatus) {
      _setStatus('Workout logs loaded.');
    }
  }

  Future<void> _maybeLoadWeeklyCoachingPreview(
      String token, _TrainingPlanResult plan,
      {bool force = false}) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      return;
    }

    final List<_WorkoutLogItem> workoutLogsForPlan = _workoutLogsForPlan(
      plan.planID,
    );
    final int currentWeekNumber = _currentWeekNumber(
      plan,
      workoutLogsForPlan,
    );
    final int nextWeekNumber =
        _nextMilestoneWeekNumber(plan, currentWeekNumber);
    if (nextWeekNumber <= currentWeekNumber) {
      if (_weeklyCoachingPreview != null && mounted) {
        setState(() {
          _weeklyCoachingPreview = null;
        });
      }
      await widget.preferences.clearWeeklyPreviewCache(
        firebaseUid: currentUser.uid,
        trainingPlanId: plan.planID,
      );
      return;
    }

    final String currentAnchor = _weekAnchorKey(DateTime.now());
    if (!force &&
        _weeklyCoachingPreview != null &&
        _weeklyCoachingPreview!.trainingPlanID == plan.planID &&
        _weeklyCoachingPreview!.currentWeek == currentWeekNumber &&
        widget.preferences.getWeeklyPreviewAnchor(
              firebaseUid: currentUser.uid,
              trainingPlanId: plan.planID,
            ) ==
            currentAnchor) {
      return;
    }

    final _WeeklyCoachingPreview? cachedPreview =
        _loadCachedWeeklyCoachingPreview(
      firebaseUid: currentUser.uid,
      plan: plan,
      workoutLogs: workoutLogsForPlan,
    );
    if (!force && cachedPreview != null) {
      if (mounted) {
        setState(() {
          _weeklyCoachingPreview = cachedPreview;
        });
      }
      return;
    }

    final Uri uri = Uri.parse(
      '${_trainingPlansUrlController.text.trim()}/${plan.planID}/weekly-preview',
    );
    final http.Response response = await _performRequest(
      () => http.post(
        uri,
        headers: <String, String>{
          HttpHeaders.authorizationHeader: 'Bearer $token',
          HttpHeaders.contentTypeHeader: 'application/json',
        },
        body: jsonEncode(<String, int>{
          'current_week': currentWeekNumber,
        }),
      ),
      action: 'generate the weekly briefing',
    );

    if (response.statusCode >= 400) {
      return;
    }

    final _WeeklyCoachingPreview? preview = _parseWeeklyCoachingPreview(
      response.body,
    );
    if (preview == null || !mounted) {
      return;
    }

    await widget.preferences.setWeeklyPreviewCache(
      firebaseUid: currentUser.uid,
      trainingPlanId: plan.planID,
      value: response.body,
    );
    await widget.preferences.setWeeklyPreviewAnchor(
      firebaseUid: currentUser.uid,
      trainingPlanId: plan.planID,
      value: currentAnchor,
    );

    setState(() {
      _weeklyCoachingPreview = preview;
    });
  }

  Future<String> _requireIdToken() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw const _UiException('You need to sign in first.');
    }

    final String? token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw const _UiException('Failed to fetch Firebase ID token.');
    }

    return token;
  }

  Future<List<int>> _readArchiveBytes(PlatformFile archive) async {
    if (archive.bytes != null) {
      return archive.bytes!;
    }

    final String? path = archive.path;
    if (path == null || path.isEmpty) {
      throw const _UiException(
          'Selected archive is missing a readable file path.');
    }

    return File(path).readAsBytes();
  }

  Future<void> _runBusyAction(
    Future<void> Function() action,
  ) async {
    setState(() {
      _busy = true;
      _status = null;
    });

    try {
      await action();
    } on FirebaseAuthException catch (error) {
      _setStatus(_friendlyFirebaseAuthError(error));
    } on _BackendConnectivityException catch (error) {
      _setStatus(error.message);
    } on _UiException catch (error) {
      _setStatus(error.message);
    } catch (error) {
      _setStatus('Something unexpected went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _setStatus(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _status = message;
    });
  }

  Future<http.Response> _performRequest(
    Future<http.Response> Function() request, {
    required String action,
  }) async {
    try {
      return await request().timeout(_backendRequestTimeout);
    } on SocketException {
      throw _BackendConnectivityException(
        'Could not $action because the backend is unreachable. Check your internet connection and try again.',
      );
    } on TimeoutException {
      throw _BackendConnectivityException(
        'Could not $action because the backend took too long to respond.',
      );
    } on http.ClientException {
      throw _BackendConnectivityException(
        'Could not $action because the app could not reach the backend cleanly.',
      );
    }
  }

  Future<http.StreamedResponse> _performStreamedRequest(
    Future<http.StreamedResponse> Function() request, {
    required String action,
  }) async {
    try {
      return await request().timeout(_backendRequestTimeout);
    } on SocketException {
      throw _BackendConnectivityException(
        'Could not $action because the backend is unreachable. Check your internet connection and try again.',
      );
    } on TimeoutException {
      throw _BackendConnectivityException(
        'Could not $action because the backend took too long to respond.',
      );
    } on http.ClientException {
      throw _BackendConnectivityException(
        'Could not $action because the app could not reach the backend cleanly.',
      );
    }
  }

  String _formatBackendFailure({
    required String action,
    http.Response? response,
    int? statusCode,
    String? responseBody,
  }) {
    final int code = statusCode ?? response?.statusCode ?? 0;
    final String body = responseBody ?? response?.body ?? '';
    final String? backendError = _extractBackendErrorMessage(body);

    switch (code) {
      case HttpStatus.badRequest:
        return backendError == null
            ? 'Could not $action because the request was invalid.'
            : 'Could not $action. $backendError';
      case HttpStatus.unauthorized:
        return 'Your sign-in session expired. Please sign in again and retry.';
      case HttpStatus.forbidden:
        return backendError == null
            ? 'You are not allowed to $action.'
            : 'Could not $action. $backendError';
      case HttpStatus.notFound:
        return backendError == null
            ? 'Could not $action because the requested resource was not found.'
            : 'Could not $action. $backendError';
      case HttpStatus.conflict:
        return backendError == null
            ? 'Could not $action because the backend rejected the current state.'
            : 'Could not $action. $backendError';
      case HttpStatus.tooManyRequests:
        return backendError == null
            ? 'Could not $action because the backend is rate-limiting requests right now.'
            : 'Could not $action. $backendError';
      default:
        if (code >= 500) {
          return backendError == null
              ? 'Could not $action because the backend hit an internal error.'
              : 'Could not $action. $backendError';
        }
        return backendError == null
            ? 'Could not $action (HTTP $code).'
            : 'Could not $action. $backendError';
    }
  }

  String? _extractBackendErrorMessage(String body) {
    final String trimmed = body.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    try {
      final Object? decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        final Object? error = decoded['error'];
        if (error is String && error.trim().isNotEmpty) {
          return error.trim();
        }
        final Object? message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } catch (_) {
      // Fall through to raw body handling.
    }

    if (trimmed.length <= 180) {
      return trimmed;
    }

    return null;
  }

  String _friendlyFirebaseAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'That email address does not look valid.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Choose a stronger password.';
      case 'too-many-requests':
        return 'Firebase is temporarily rate-limiting sign-in attempts. Try again shortly.';
      case 'network-request-failed':
        return 'Could not reach Firebase. Check your internet connection and try again.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  void _showToast(String message) {
    if (!mounted) {
      return;
    }

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  _TrainingPlanResult? _parseTrainingPlanFromResponse(String body) {
    final Object? decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    return _normalizeTrainingPlanForMeasurementSystem(
      _TrainingPlanResult.fromJson(decoded),
    );
  }

  _TrainingPlanJob? _parseTrainingPlanJobFromResponse(String body) {
    final Object? decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    return _TrainingPlanJob.fromJson(decoded);
  }

  _WeeklyCoachingPreview? _parseWeeklyCoachingPreview(String body) {
    final Object? decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    return _WeeklyCoachingPreview.fromJson(decoded);
  }

  _WorkoutSessionDraftSnapshot? _parseWorkoutSessionDraftSnapshot(String body) {
    final Object? decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    return _WorkoutSessionDraftSnapshot.fromJson(decoded);
  }

  _WeeklyCoachingPreview? _loadCachedWeeklyCoachingPreview({
    required String firebaseUid,
    required _TrainingPlanResult plan,
    required List<_WorkoutLogItem> workoutLogs,
  }) {
    final int currentWeekNumber = _currentWeekNumber(plan, workoutLogs);
    final String currentAnchor = _weekAnchorKey(DateTime.now());
    final String cachedAnchor = widget.preferences.getWeeklyPreviewAnchor(
      firebaseUid: firebaseUid,
      trainingPlanId: plan.planID,
    );
    if (cachedAnchor != currentAnchor) {
      return null;
    }

    final String cachedBody = widget.preferences.getWeeklyPreviewCache(
      firebaseUid: firebaseUid,
      trainingPlanId: plan.planID,
    );
    if (cachedBody.isEmpty) {
      return null;
    }

    final _WeeklyCoachingPreview? preview =
        _parseWeeklyCoachingPreview(cachedBody);
    if (preview == null) {
      return null;
    }
    if (preview.trainingPlanID != plan.planID ||
        preview.currentWeek != currentWeekNumber) {
      return null;
    }

    return preview;
  }

  List<_WorkoutLogItem> _parseWorkoutLogsFromResponse(String body) {
    final Object? decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      return <_WorkoutLogItem>[];
    }

    final Object? logsValue = decoded['workout_logs'];
    if (logsValue is! List<dynamic>) {
      return <_WorkoutLogItem>[];
    }

    return logsValue
        .whereType<Map<String, dynamic>>()
        .map(_WorkoutLogItem.fromJson)
        .map(_normalizeWorkoutLogForMeasurementSystem)
        .toList();
  }

  _WorkoutLogItem? _parseWorkoutLogFromResponse(String body) {
    final Object? decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    return _normalizeWorkoutLogForMeasurementSystem(
      _WorkoutLogItem.fromJson(decoded),
    );
  }

  _TrainingPlanResult _normalizeTrainingPlanForMeasurementSystem(
    _TrainingPlanResult plan,
  ) {
    return _TrainingPlanResult(
      planID: plan.planID,
      objective: plan.objective,
      durationWeeks: plan.durationWeeks,
      daysPerWeek: plan.daysPerWeek,
      summary: plan.summary,
      philosophy: plan.philosophy,
      progressionStrategy: plan.progressionStrategy,
      risks: plan.risks,
      successCriteria: plan.successCriteria,
      provider: plan.provider,
      model: plan.model,
      generated: plan.generated,
      dailyLimit: plan.dailyLimit,
      generatedToday: plan.generatedToday,
      remainingToday: plan.remainingToday,
      weeks: plan.weeks
          .map(_normalizeTrainingPlanWeekForMeasurementSystem)
          .toList(growable: false),
    );
  }

  _TrainingPlanWeek _normalizeTrainingPlanWeekForMeasurementSystem(
    _TrainingPlanWeek week,
  ) {
    return _TrainingPlanWeek(
      weekNumber: week.weekNumber,
      theme: week.theme,
      workouts: week.workouts
          .map(_normalizeTrainingPlanWorkoutForMeasurementSystem)
          .toList(growable: false),
    );
  }

  _TrainingPlanWorkout _normalizeTrainingPlanWorkoutForMeasurementSystem(
    _TrainingPlanWorkout workout,
  ) {
    return _TrainingPlanWorkout(
      dayNumber: workout.dayNumber,
      title: workout.title,
      focus: workout.focus,
      exercises: workout.exercises
          .map(_normalizePlannedExerciseForMeasurementSystem)
          .toList(growable: false),
    );
  }

  _PlannedExercise _normalizePlannedExerciseForMeasurementSystem(
    _PlannedExercise exercise,
  ) {
    return _PlannedExercise(
      title: exercise.title,
      notes: exercise.notes,
      sets: exercise.sets
          .map(_normalizePlannedSetForMeasurementSystem)
          .toList(growable: false),
    );
  }

  _PlannedSet _normalizePlannedSetForMeasurementSystem(_PlannedSet set) {
    final _NormalizedUnitValue targetValue = _normalizeUnitValue(
      value: set.targetValue,
      unit: set.targetUnit,
    );
    final _NormalizedUnitValue loadValue = _normalizeUnitValue(
      value: set.loadValue,
      unit: set.loadUnit,
    );
    return _PlannedSet(
      reps: set.reps,
      targetValue: targetValue.value,
      targetUnit: targetValue.unit,
      loadValue: loadValue.value,
      loadUnit: loadValue.unit,
    );
  }

  _WorkoutLogItem _normalizeWorkoutLogForMeasurementSystem(
      _WorkoutLogItem log) {
    final _NormalizedUnitValue estimatedVolume = _normalizeUnitValue(
      value: log.estimatedVolume,
      unit: log.estimatedVolumeUnit,
    );
    return _WorkoutLogItem(
      id: log.id,
      trainingPlanID: log.trainingPlanID,
      weekNumber: log.weekNumber,
      dayNumber: log.dayNumber,
      title: log.title,
      focus: log.focus,
      sessionNotes: log.sessionNotes,
      durationMinutes: log.durationMinutes,
      exerciseCount: log.exerciseCount,
      setCount: log.setCount,
      completedSetCount: log.completedSetCount,
      totalReps: log.totalReps,
      estimatedVolume: estimatedVolume.value,
      estimatedVolumeUnit: estimatedVolume.unit,
      exercises: log.exercises
          .map(_normalizeWorkoutLogExerciseForMeasurementSystem)
          .toList(growable: false),
      review: log.review,
    );
  }

  _WorkoutLogExerciseItem _normalizeWorkoutLogExerciseForMeasurementSystem(
    _WorkoutLogExerciseItem exercise,
  ) {
    return _WorkoutLogExerciseItem(
      sequenceNumber: exercise.sequenceNumber,
      title: exercise.title,
      notes: exercise.notes,
      sets: exercise.sets
          .map(_normalizeWorkoutLogSetForMeasurementSystem)
          .toList(growable: false),
    );
  }

  _WorkoutLogSetItem _normalizeWorkoutLogSetForMeasurementSystem(
    _WorkoutLogSetItem set,
  ) {
    final _NormalizedUnitValue primaryValue = _normalizeUnitValue(
      value: set.value,
      unit: set.unit,
    );
    final _NormalizedUnitValue loadValue = _normalizeUnitValue(
      value: set.loadValue,
      unit: set.loadUnit,
    );
    return _WorkoutLogSetItem(
      sequenceNumber: set.sequenceNumber,
      reps: set.reps,
      value: primaryValue.value,
      unit: primaryValue.unit,
      loadValue: loadValue.value,
      loadUnit: loadValue.unit,
      completed: set.completed,
    );
  }

  _NormalizedUnitValue _normalizeUnitValue({
    required double? value,
    required String unit,
  }) {
    final String trimmedUnit = unit.trim();
    if (trimmedUnit.isEmpty ||
        !_isTrackedLoadUnit(trimmedUnit) ||
        value == null) {
      return _NormalizedUnitValue(value: value, unit: trimmedUnit);
    }

    if (_deviceMeasurementSystem == _measurementSystemMetric) {
      if (_isImperialLoadUnit(trimmedUnit)) {
        return _NormalizedUnitValue(
          value: value * 0.45359237,
          unit: 'kg',
        );
      }
      return _NormalizedUnitValue(value: value, unit: 'kg');
    }

    if (_deviceMeasurementSystem == _measurementSystemImperial) {
      if (_isMetricLoadUnit(trimmedUnit)) {
        return _NormalizedUnitValue(
          value: value * 2.2046226218,
          unit: 'lb',
        );
      }
      return _NormalizedUnitValue(value: value, unit: 'lb');
    }

    return _NormalizedUnitValue(value: value, unit: trimmedUnit);
  }

  bool _isMetricLoadUnit(String unit) {
    const Set<String> metricUnits = <String>{
      'kg',
      'kilogram',
      'kilograms',
    };
    return metricUnits.contains(unit.trim().toLowerCase());
  }

  bool _isImperialLoadUnit(String unit) {
    const Set<String> imperialUnits = <String>{
      'lb',
      'lbs',
      'pound',
      'pounds',
    };
    return imperialUnits.contains(unit.trim().toLowerCase());
  }

  _BackendUserProfile? _parseBackendUserProfile(String body) {
    final Object? decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final Object? userValue = decoded['user'];
    if (userValue is! Map<String, dynamic>) {
      return null;
    }

    return _BackendUserProfile.fromJson(userValue);
  }

  _BackendUserProfile? _parseCachedBackendUserProfile(String body) {
    final Object? decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    if (decoded['user'] case final Map<String, dynamic> userValue) {
      return _BackendUserProfile.fromJson(userValue);
    }

    return _BackendUserProfile.fromJson(decoded);
  }

  Future<List<_WorkoutLogItem>> _loadQueuedWorkoutLogs({
    required String firebaseUid,
    required int trainingPlanID,
  }) async {
    final List<String> queuedPayloads =
        await widget.localCacheRepository.loadQueuedWorkoutLogs(
      firebaseUid: firebaseUid,
      trainingPlanId: trainingPlanID,
    );

    return queuedPayloads
        .map(_parseWorkoutLogFromResponse)
        .whereType<_WorkoutLogItem>()
        .toList(growable: false);
  }

  List<_WorkoutLogItem> _mergeQueuedWorkoutLogs(
    List<_WorkoutLogItem> backendLogs,
    List<_WorkoutLogItem> queuedLogs,
  ) {
    if (queuedLogs.isEmpty) {
      return backendLogs;
    }

    final Map<String, _WorkoutLogItem> merged = <String, _WorkoutLogItem>{
      for (final _WorkoutLogItem item in backendLogs)
        '${item.trainingPlanID}:${item.weekNumber}:${item.dayNumber}': item,
    };
    for (final _WorkoutLogItem item in queuedLogs) {
      merged['${item.trainingPlanID}:${item.weekNumber}:${item.dayNumber}'] =
          item;
    }

    return merged.values.toList(growable: false)
      ..sort((_WorkoutLogItem a, _WorkoutLogItem b) {
        final int weekComparison = a.weekNumber.compareTo(b.weekNumber);
        if (weekComparison != 0) {
          return weekComparison;
        }
        return a.dayNumber.compareTo(b.dayNumber);
      });
  }

  String _workoutLogEntityKey(_WorkoutLogDraft draft) {
    return '${draft.trainingPlanID}:${draft.weekNumber}:${draft.dayNumber}';
  }

  Future<void> _queueWorkoutLogForSync(
    String firebaseUid,
    _WorkoutLogDraft draft,
  ) async {
    final _WorkoutLogItem queuedLog = _workoutLogItemFromDraft(draft);
    await widget.localCacheRepository.enqueueWorkoutLogSync(
      firebaseUid: firebaseUid,
      trainingPlanId: draft.trainingPlanID,
      entityKey: _workoutLogEntityKey(draft),
      payloadJson: jsonEncode(draft.toJson()),
      localSnapshotJson: jsonEncode(_workoutLogToJson(queuedLog)),
    );

    final List<_WorkoutLogItem> updatedLogs = _upsertWorkoutLogItem(
      _workoutLogs,
      queuedLog,
    );
    setState(() {
      _workoutLogs = updatedLogs;
    });
    await _syncDisplayedWeekForCurrentPlan();
    await _persistWorkoutLogSnapshot(
      firebaseUid: firebaseUid,
      trainingPlanID: draft.trainingPlanID,
      logs: updatedLogs
          .where(
            (_WorkoutLogItem item) =>
                item.trainingPlanID == draft.trainingPlanID,
          )
          .toList(growable: false),
    );
    _showToast('Workout saved locally and queued for sync.');
  }

  Future<void> _persistWorkoutLogSnapshot({
    required String firebaseUid,
    required int trainingPlanID,
    required List<_WorkoutLogItem> logs,
  }) async {
    await widget.localCacheRepository.cacheWorkoutLogs(
      trainingPlanId: trainingPlanID,
      firebaseUid: firebaseUid,
      payloadJson: jsonEncode(<String, Object?>{
        'workout_logs': logs.map(_workoutLogToJson).toList(growable: false),
      }),
    );
  }

  Map<String, Object?> _workoutLogToJson(_WorkoutLogItem item) {
    return <String, Object?>{
      'id': item.id,
      'training_plan_id': item.trainingPlanID,
      'week_number': item.weekNumber,
      'day_number': item.dayNumber,
      'title': item.title,
      'focus': item.focus,
      'session_notes': item.sessionNotes,
      'duration_minutes': item.durationMinutes,
      'exercise_count': item.exerciseCount,
      'set_count': item.setCount,
      'completed_set_count': item.completedSetCount,
      'total_reps': item.totalReps,
      'estimated_volume': item.estimatedVolume,
      'estimated_volume_unit': item.estimatedVolumeUnit,
      'exercises': item.exercises.map(_workoutLogExerciseToJson).toList(),
      'review':
          item.review == null ? null : _workoutLogReviewToJson(item.review!),
    };
  }

  Map<String, Object?> _workoutLogExerciseToJson(_WorkoutLogExerciseItem item) {
    return <String, Object?>{
      'sequence_number': item.sequenceNumber,
      'title': item.title,
      'notes': item.notes,
      'sets': item.sets.map(_workoutLogSetToJson).toList(growable: false),
    };
  }

  Map<String, Object?> _workoutLogSetToJson(_WorkoutLogSetItem item) {
    return <String, Object?>{
      'sequence_number': item.sequenceNumber,
      'reps': item.reps,
      'value': item.value,
      'unit': item.unit,
      'load_value': item.loadValue,
      'load_unit': item.loadUnit,
      'completed': item.completed,
    };
  }

  Map<String, Object?> _workoutLogReviewToJson(_WorkoutLogReviewItem item) {
    return <String, Object?>{
      'provider': item.provider,
      'model': item.model,
      'prompt_version': item.promptVersion,
      'review': item.review,
      'generated': item.generated,
    };
  }

  _WorkoutLogItem _workoutLogItemFromDraft(_WorkoutLogDraft draft) {
    int setCount = 0;
    int completedSetCount = 0;
    double totalReps = 0;
    final Map<String, double> estimatedVolumeByUnit = <String, double>{};

    final List<_WorkoutLogExerciseItem> exercises = draft.exercises
        .asMap()
        .entries
        .map((MapEntry<int, _WorkoutLogDraftExercise> entry) {
      final int exerciseIndex = entry.key;
      final _WorkoutLogDraftExercise exercise = entry.value;
      final List<_WorkoutLogSetItem> sets = exercise.sets
          .asMap()
          .entries
          .map((MapEntry<int, _WorkoutLogDraftSet> setEntry) {
        final int setIndex = setEntry.key;
        final _WorkoutLogDraftSet set = setEntry.value;
        setCount++;
        if (set.completed) {
          completedSetCount++;
        }
        final double reps = set.reps ?? 0;
        if (set.completed) {
          totalReps += reps;
        }
        _appendLoggedTrackedVolumeFromDraftSetItem(estimatedVolumeByUnit, set);

        return _WorkoutLogSetItem(
          sequenceNumber: setIndex + 1,
          reps: set.reps,
          value: set.value,
          unit: set.unit,
          loadValue: set.loadValue,
          loadUnit: set.loadUnit,
          completed: set.completed,
        );
      }).toList(growable: false);

      return _WorkoutLogExerciseItem(
        sequenceNumber: exerciseIndex + 1,
        title: exercise.title,
        notes: exercise.notes,
        sets: sets,
      );
    }).toList(growable: false);

    double? estimatedVolume;
    String estimatedVolumeUnit = '';
    if (estimatedVolumeByUnit.isNotEmpty) {
      final List<MapEntry<String, double>> orderedEntries =
          estimatedVolumeByUnit.entries.toList()
            ..sort(
              (MapEntry<String, double> a, MapEntry<String, double> b) =>
                  b.value.compareTo(a.value),
            );
      estimatedVolumeUnit = orderedEntries.first.key;
      estimatedVolume = orderedEntries.first.value;
    }

    return _WorkoutLogItem(
      id: -(draft.trainingPlanID * 1000 +
          draft.weekNumber * 10 +
          draft.dayNumber),
      trainingPlanID: draft.trainingPlanID,
      weekNumber: draft.weekNumber,
      dayNumber: draft.dayNumber,
      title: draft.title,
      focus: draft.focus,
      sessionNotes: draft.sessionNotes,
      durationMinutes: draft.durationMinutes,
      exerciseCount: exercises.length,
      setCount: setCount,
      completedSetCount: completedSetCount,
      totalReps: totalReps,
      estimatedVolume: estimatedVolume,
      estimatedVolumeUnit: estimatedVolumeUnit,
      exercises: exercises,
      review: null,
    );
  }

  List<_WorkoutLogItem> _workoutLogsForPlan(int? trainingPlanID) {
    if (trainingPlanID == null) {
      return <_WorkoutLogItem>[];
    }

    return _workoutLogs
        .where((_WorkoutLogItem item) => item.trainingPlanID == trainingPlanID)
        .toList()
      ..sort((_WorkoutLogItem a, _WorkoutLogItem b) {
        final int weekComparison = a.weekNumber.compareTo(b.weekNumber);
        if (weekComparison != 0) {
          return weekComparison;
        }
        return a.dayNumber.compareTo(b.dayNumber);
      });
  }

  _WeeklyTrainingStats _weeklyTrainingStats(
    List<_WorkoutLogItem> workoutLogs,
    _TrainingPlanWeek? currentWeek,
    int currentWeekNumber,
  ) {
    double totalReps = 0;
    final Map<String, double> volumeByUnit = <String, double>{};

    for (final _WorkoutLogItem item in workoutLogs) {
      if (item.weekNumber != currentWeekNumber) {
        continue;
      }

      totalReps += item.totalReps;
      if (item.hasEstimatedVolume) {
        volumeByUnit[item.estimatedVolumeUnit] =
            (volumeByUnit[item.estimatedVolumeUnit] ?? 0) +
                item.estimatedVolume!;
      }
    }

    double targetReps = 0;
    final Map<String, double> targetVolumeByUnit = <String, double>{};
    double volumeProgress = 0;
    if (currentWeek != null) {
      final Map<int, _WorkoutLogItem> logsByDayNumber = <int, _WorkoutLogItem>{
        for (final _WorkoutLogItem log in workoutLogs)
          if (log.weekNumber == currentWeekNumber) log.dayNumber: log,
      };
      double measurableWorkoutProgress = 0;
      int measurableWorkoutCount = 0;

      for (final _TrainingPlanWorkout workout in currentWeek.workouts) {
        final Map<String, double> workoutTargetVolumeByUnit =
            <String, double>{};

        for (final _PlannedExercise exercise in workout.exercises) {
          for (final _PlannedSet set in exercise.sets) {
            if (set.reps != null) {
              targetReps += set.reps!;
            }
            _appendPlannedTrackedVolume(targetVolumeByUnit, set);
            _appendPlannedTrackedVolume(workoutTargetVolumeByUnit, set);
          }
        }

        if (workoutTargetVolumeByUnit.isEmpty) {
          continue;
        }

        final List<MapEntry<String, double>> workoutTargetEntries =
            workoutTargetVolumeByUnit.entries.toList()
              ..sort(
                (MapEntry<String, double> a, MapEntry<String, double> b) =>
                    b.value.compareTo(a.value),
              );
        final String primaryUnit = workoutTargetEntries.first.key;
        final double targetWorkoutVolume =
            workoutTargetVolumeByUnit[primaryUnit] ?? 0;
        if (targetWorkoutVolume <= 0) {
          continue;
        }

        final _WorkoutLogItem? workoutLog = logsByDayNumber[workout.dayNumber];
        final double actualWorkoutVolume = workoutLog != null &&
                workoutLog.hasEstimatedVolume &&
                workoutLog.estimatedVolumeUnit == primaryUnit
            ? workoutLog.estimatedVolume!
            : 0;

        measurableWorkoutProgress +=
            (actualWorkoutVolume / targetWorkoutVolume).clamp(0, 1).toDouble();
        measurableWorkoutCount++;
      }

      if (measurableWorkoutCount > 0) {
        volumeProgress = measurableWorkoutProgress / measurableWorkoutCount;
      }
    }

    String volumeLabel = '';
    int? totalVolume;
    int? targetVolume;
    if (volumeByUnit.isNotEmpty || targetVolumeByUnit.isNotEmpty) {
      final Map<String, double> combinedVolumeByUnit = <String, double>{
        ...targetVolumeByUnit,
      };
      volumeByUnit.forEach((String unit, double value) {
        combinedVolumeByUnit[unit] = (combinedVolumeByUnit[unit] ?? 0) + value;
      });

      final List<MapEntry<String, double>> sortedEntries =
          combinedVolumeByUnit.entries.toList()
            ..sort(
              (MapEntry<String, double> a, MapEntry<String, double> b) =>
                  b.value.compareTo(a.value),
            );
      final String primaryUnit = sortedEntries.first.key;
      volumeLabel = primaryUnit;
      if (volumeByUnit[primaryUnit] != null) {
        totalVolume = volumeByUnit[primaryUnit]!.round();
      }
      if (targetVolumeByUnit[primaryUnit] != null) {
        targetVolume = targetVolumeByUnit[primaryUnit]!.round();
      }
    }

    return _WeeklyTrainingStats(
      totalReps: totalReps.round(),
      targetReps: targetReps.round(),
      totalVolume: totalVolume,
      targetVolume: targetVolume,
      volumeLabel: volumeLabel,
      volumeProgress: volumeProgress,
    );
  }

  List<_WorkoutLogItem> _upsertWorkoutLogItem(
    List<_WorkoutLogItem> existing,
    _WorkoutLogItem saved,
  ) {
    final List<_WorkoutLogItem> next = existing
        .where(
          (_WorkoutLogItem item) =>
              !(item.trainingPlanID == saved.trainingPlanID &&
                  item.weekNumber == saved.weekNumber &&
                  item.dayNumber == saved.dayNumber),
        )
        .toList();
    next.add(saved);
    return next;
  }

  List<_WorkoutLogItem> _mergeWorkoutLogsForPlan(
    List<_WorkoutLogItem> existing,
    int trainingPlanID,
    List<_WorkoutLogItem> fetched,
  ) {
    final List<_WorkoutLogItem> next = existing
        .where((_WorkoutLogItem item) => item.trainingPlanID != trainingPlanID)
        .toList();
    next.addAll(fetched);
    return next;
  }

  String _workoutSessionDraftKey({
    required int trainingPlanID,
    required int weekNumber,
    required int dayNumber,
  }) {
    return '$trainingPlanID:$weekNumber:$dayNumber';
  }

  Future<Map<String, _WorkoutSessionDraftSummary>>
      _loadCachedWorkoutSessionDraftsForPlan({
    required String firebaseUid,
    required int trainingPlanID,
  }) async {
    final List<WorkoutSessionDraftCacheEntry> entries =
        await widget.localCacheRepository.loadWorkoutSessionDrafts(
      firebaseUid: firebaseUid,
      trainingPlanId: trainingPlanID,
    );

    final Map<String, _WorkoutSessionDraftSummary> draftsByKey =
        <String, _WorkoutSessionDraftSummary>{};
    for (final WorkoutSessionDraftCacheEntry entry in entries) {
      final _WorkoutSessionDraftSnapshot? snapshot =
          _parseWorkoutSessionDraftSnapshot(entry.payloadJson);
      if (snapshot == null) {
        continue;
      }

      final _WorkoutSessionDraftSummary summary = _summarizeWorkoutSessionDraft(
        snapshot,
        entry.updatedAt,
      );
      draftsByKey[_workoutSessionDraftKey(
        trainingPlanID: summary.trainingPlanID,
        weekNumber: summary.weekNumber,
        dayNumber: summary.dayNumber,
      )] = summary;
    }

    return draftsByKey;
  }

  Future<void> _refreshCachedWorkoutSessionDraftsForPlan({
    required String firebaseUid,
    required int trainingPlanID,
  }) async {
    final Map<String, _WorkoutSessionDraftSummary> draftsByKey =
        await _loadCachedWorkoutSessionDraftsForPlan(
      firebaseUid: firebaseUid,
      trainingPlanID: trainingPlanID,
    );
    if (!mounted) {
      return;
    }

    final Map<String, _WorkoutSessionDraftSummary> retainedDrafts =
        Map<String, _WorkoutSessionDraftSummary>.from(
      _workoutSessionDraftsByKey,
    )..removeWhere(
            (
              String _,
              _WorkoutSessionDraftSummary value,
            ) =>
                value.trainingPlanID == trainingPlanID,
          );

    setState(() {
      _workoutSessionDraftsByKey = <String, _WorkoutSessionDraftSummary>{
        ...retainedDrafts,
        ...draftsByKey,
      };
    });
  }

  void _removeWorkoutSessionDraftFromState({
    required int trainingPlanID,
    required int weekNumber,
    required int dayNumber,
  }) {
    final String key = _workoutSessionDraftKey(
      trainingPlanID: trainingPlanID,
      weekNumber: weekNumber,
      dayNumber: dayNumber,
    );
    if (!_workoutSessionDraftsByKey.containsKey(key)) {
      return;
    }

    setState(() {
      _workoutSessionDraftsByKey = <String, _WorkoutSessionDraftSummary>{
        ..._workoutSessionDraftsByKey,
      }..remove(key);
    });
  }

  _WorkoutSessionDraftSummary _summarizeWorkoutSessionDraft(
    _WorkoutSessionDraftSnapshot snapshot,
    DateTime updatedAt,
  ) {
    int setCount = 0;
    int completedSetCount = 0;
    double totalReps = 0;
    final Map<String, double> estimatedVolumeByUnit = <String, double>{};

    for (final _WorkoutLogDraftExercise exercise in snapshot.exercises) {
      for (final _WorkoutLogDraftSet set in exercise.sets) {
        setCount++;
        if (set.completed) {
          completedSetCount++;
          totalReps += set.reps ?? 0;
        }
        _appendLoggedTrackedVolumeFromDraftSetItem(estimatedVolumeByUnit, set);
      }
    }

    double? estimatedVolume;
    String estimatedVolumeUnit = '';
    if (estimatedVolumeByUnit.isNotEmpty) {
      final List<MapEntry<String, double>> orderedEntries =
          estimatedVolumeByUnit.entries.toList()
            ..sort(
              (MapEntry<String, double> a, MapEntry<String, double> b) =>
                  b.value.compareTo(a.value),
            );
      estimatedVolumeUnit = orderedEntries.first.key;
      estimatedVolume = orderedEntries.first.value;
    }

    return _WorkoutSessionDraftSummary(
      trainingPlanID: snapshot.trainingPlanID,
      weekNumber: snapshot.weekNumber,
      dayNumber: snapshot.dayNumber,
      title: snapshot.title,
      focus: snapshot.focus,
      durationMinutes: snapshot.durationMinutes,
      currentStep: snapshot.currentStep,
      sessionFeelIndex: snapshot.sessionFeelIndex,
      setCount: setCount,
      completedSetCount: completedSetCount,
      totalReps: totalReps,
      estimatedVolume: estimatedVolume,
      estimatedVolumeUnit: estimatedVolumeUnit,
      updatedAt: updatedAt,
    );
  }

  Future<void> _loadBackendUserProfile(
    String token, {
    bool announceStatus = true,
  }) async {
    final Uri uri = Uri.parse(_meUrlController.text.trim());
    final http.Response response = await _performRequest(
      () => http.get(
        uri,
        headers: <String, String>{
          HttpHeaders.authorizationHeader: 'Bearer $token',
        },
      ),
      action: 'load your profile',
    );

    final String body = response.body;

    if (response.statusCode >= 400) {
      throw _UiException(_formatBackendFailure(
        action: 'load your profile',
        response: response,
      ));
    }

    final _BackendUserProfile? profile = _parseBackendUserProfile(body);
    if (profile == null) {
      return;
    }

    await widget.localCacheRepository.cacheUserProfile(
      firebaseUid: profile.firebaseUID.isNotEmpty
          ? profile.firebaseUID
          : (_auth.currentUser?.uid ?? ''),
      payloadJson: body,
    );

    setState(() {
      _backendUser = profile;
    });

    if (announceStatus) {
      _setStatus('Backend identity check completed.');
    }
  }
}

class _CenteredCoachState extends StatelessWidget {
  const _CenteredCoachState({
    required this.eyebrow,
    required this.title,
    required this.body,
    this.loading = false,
  });

  final String eyebrow;
  final String title;
  final String body;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _outline),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  eyebrow,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.55,
                    color: _textSecondary,
                  ),
                ),
                if (loading) ...<Widget>[
                  const SizedBox(height: 18),
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthOnboardingScreen extends StatelessWidget {
  const _AuthOnboardingScreen({
    required this.emailController,
    required this.passwordController,
    required this.promoCodeController,
    required this.busy,
    required this.status,
    required this.onCreateAccount,
    required this.onSignIn,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController promoCodeController;
  final bool busy;
  final String? status;
  final Future<void> Function() onCreateAccount;
  final Future<void> Function() onSignIn;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _CoachPill(label: 'Coach'),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: _outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Create Your Account',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'The first thing your coach needs is a direct line to you. Create your account, then we will build your first training block.',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.55,
                        color: _textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: promoCodeController,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Promo Code',
                        helperText:
                            'Optional. Invited users can unlock paid AI features.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: <Widget>[
                        OutlinedButton(
                          onPressed: busy ? null : onSignIn,
                          child: const Text('Sign In'),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 176,
                          child: FilledButton(
                            onPressed: busy ? null : onCreateAccount,
                            child: const Text('Create Account'),
                          ),
                        ),
                      ],
                    ),
                    if (status != null) ...<Widget>[
                      const SizedBox(height: 16),
                      _CoachStatusBanner(message: status!),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoachPill extends StatelessWidget {
  const _CoachPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF12161C),
        border: Border.all(color: _outline),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _WeeklyProgressStrip extends StatelessWidget {
  const _WeeklyProgressStrip({
    required this.currentWeekNumber,
    required this.blockProgress,
    required this.totalReps,
    required this.targetReps,
    required this.totalVolume,
    required this.targetVolume,
    required this.volumeLabel,
    required this.volumeProgress,
  });

  final int currentWeekNumber;
  final double blockProgress;
  final int totalReps;
  final int targetReps;
  final int? totalVolume;
  final int? targetVolume;
  final String volumeLabel;
  final double volumeProgress;

  @override
  Widget build(BuildContext context) {
    final int progressPercent = (blockProgress.clamp(0, 1) * 100).round();
    final int normalizedTargetReps =
        math.max(0, math.max(targetReps, totalReps));
    final int normalizedTargetVolume =
        math.max(0, math.max(targetVolume ?? 0, totalVolume ?? 0));
    final double repsProgress = normalizedTargetReps == 0
        ? 0
        : (totalReps / normalizedTargetReps).clamp(0, 1).toDouble();
    final double fallbackVolumeProgress = normalizedTargetVolume == 0
        ? 0
        : ((totalVolume ?? 0) / normalizedTargetVolume).clamp(0, 1).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _outline),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: _WeeklyStripMetric(
              label: 'Week $currentWeekNumber',
              value: '$progressPercent%',
              compact: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: _WeeklyStripMetric(
              label: 'Reps',
              value: '$totalReps',
              accent: const Color(0xFFFF4D7D),
              progress: repsProgress,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: _WeeklyStripMetric(
              label: 'Volume',
              value:
                  '${totalVolume ?? 0}${volumeLabel.isEmpty ? '' : ' $volumeLabel'}',
              accent: _accentBlue,
              progress:
                  volumeProgress > 0 ? volumeProgress : fallbackVolumeProgress,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyStripMetric extends StatelessWidget {
  const _WeeklyStripMetric({
    required this.label,
    required this.value,
    this.accent,
    this.progress,
    this.compact = false,
  });

  final String label;
  final String value;
  final Color? accent;
  final double? progress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Color metricAccent = accent ?? _textMuted;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 10,
        vertical: compact ? 10 : 8,
      ),
      decoration: BoxDecoration(
        color: _surfaceRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _outlineSoft),
      ),
      child: Row(
        children: <Widget>[
          if (progress != null) ...<Widget>[
            _MiniProgressRing(
              progress: progress!,
              color: metricAccent,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 10 : 11,
                    fontWeight: FontWeight.w700,
                    color: metricAccent,
                  ),
                ),
                SizedBox(height: compact ? 3 : 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 14 : 15,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
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

class _WeekdayWorkoutStrip extends StatelessWidget {
  const _WeekdayWorkoutStrip({
    required this.slots,
    required this.selectedWeekday,
    required this.onTap,
    required this.onLongPress,
  });

  final List<_WeekdayWorkoutSlot> slots;
  final String? selectedWeekday;
  final ValueChanged<String> onTap;
  final ValueChanged<_WeekdayWorkoutSlot> onLongPress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _outline),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: slots.map((_WeekdayWorkoutSlot slot) {
          final bool isSelected = slot.weekdayLabel == selectedWeekday;
          return GestureDetector(
            onTap: () => onTap(slot.weekdayLabel),
            onLongPress: () => onLongPress(slot),
            child: _WeekdayCircle(
              slot: slot,
              isCurrentDay: slot.isCurrentDay,
              isSelected: isSelected,
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _WeekdayCircle extends StatelessWidget {
  const _WeekdayCircle({
    required this.slot,
    required this.isCurrentDay,
    required this.isSelected,
  });

  final _WeekdayWorkoutSlot slot;
  final bool isCurrentDay;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final Color fillColor = slot.loggedWorkout != null
        ? _accentGreen
        : slot.draftSummary != null
            ? const Color(0xFFFFB454)
            : slot.hasWorkout
                ? _accentBlue
                : _surfaceRaised;
    final Color borderColor = isCurrentDay
        ? const Color(0xFFFFD166)
        : isSelected
            ? _textPrimary
            : _outlineSoft;
    final Color textColor =
        slot.hasWorkout || slot.loggedWorkout != null ? _bgTop : _textMuted;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: fillColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: isSelected || isCurrentDay ? 2.4 : 1.2,
        ),
        boxShadow: isSelected
            ? <BoxShadow>[
                BoxShadow(
                  color: borderColor.withValues(alpha: 0.18),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : const <BoxShadow>[],
      ),
      alignment: Alignment.center,
      child: Text(
        slot.weekdayLabel.substring(0, 1),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }
}

class _SelectedDayWorkoutCard extends StatelessWidget {
  const _SelectedDayWorkoutCard({
    required this.slot,
    required this.weekNumber,
    required this.currentWeekNumber,
    required this.upcomingWorkout,
    this.onOpenLoggedWorkout,
    this.onResumeDraft,
    this.onPreviewWorkout,
  });

  final _WeekdayWorkoutSlot slot;
  final int weekNumber;
  final int currentWeekNumber;
  final _UpcomingWorkoutData? upcomingWorkout;
  final VoidCallback? onOpenLoggedWorkout;
  final VoidCallback? onResumeDraft;
  final VoidCallback? onPreviewWorkout;

  @override
  Widget build(BuildContext context) {
    String eyebrow = slot.isCurrentDay ? 'Today' : 'Selected Day';
    String title = slot.weekdayLabel;
    String body =
        'No training scheduled for this day. Long press on the strip if you want to generate one.';
    String? contextLine;
    final List<Widget> pills = <Widget>[];
    Widget? primaryAction;
    Widget? secondaryAction;
    Color accentColor = _textMuted;
    IconData accentIcon = Icons.event_available_rounded;
    String statusBadge = slot.isCurrentDay ? 'Rest Day' : 'Selected';

    if (slot.loggedWorkout != null) {
      final _WorkoutLogItem log = slot.loggedWorkout!;
      eyebrow = slot.isCurrentDay ? 'Today Logged' : 'Past Session';
      title = log.title;
      accentColor = _accentGreen;
      accentIcon = Icons.check_circle_rounded;
      statusBadge = 'Completed';
      body = log.focus.isNotEmpty
          ? log.focus
          : 'This session has already been logged.';
      contextLine =
          'Week $weekNumber · ${slot.weekdayLabel}${log.durationMinutes != null ? ' · ${log.durationMinutes} min session' : ''}';
      pills.add(
        _DetailPill(
          label: '${log.completedSetCount}/${log.setCount} sets complete',
        ),
      );
      pills.add(_DetailPill(label: '${log.totalReps.round()} reps'));
      if (log.hasEstimatedVolume) {
        pills.add(
          _DetailPill(
            label:
                '${_formatVolumeValue(log.estimatedVolume!)} ${log.estimatedVolumeUnit}',
          ),
        );
      }
      if (log.durationMinutes != null) {
        pills.add(_DetailPill(label: '${log.durationMinutes} min'));
      }
      primaryAction = OutlinedButton(
        onPressed: onOpenLoggedWorkout,
        style: OutlinedButton.styleFrom(
          backgroundColor: _surfaceRaised,
          foregroundColor: _textPrimary,
          side: BorderSide(
            color: _accentGreen.withValues(alpha: 0.38),
          ),
        ),
        child: const Text('Open Review'),
      );
    } else if (slot.draftSummary != null) {
      final _WorkoutSessionDraftSummary draft = slot.draftSummary!;
      eyebrow = slot.isCurrentDay ? 'Resume Session' : 'In Progress';
      title = draft.title;
      accentColor = const Color(0xFFFFB454);
      accentIcon = Icons.play_circle_fill_rounded;
      statusBadge = 'In Progress';
      body = draft.focus.isNotEmpty
          ? draft.focus
          : 'You have a saved session draft ready to continue.';
      final int remainingSets = math.max(
        0,
        draft.setCount - draft.completedSetCount,
      );
      contextLine =
          'Week $weekNumber · ${slot.weekdayLabel} · Saved ${_draftUpdatedLabel(draft.updatedAt)}${remainingSets > 0 ? ' · $remainingSets sets left' : ''}';
      pills.add(
        _DetailPill(
          label: '${draft.completedSetCount}/${draft.setCount} sets complete',
        ),
      );
      pills.add(_DetailPill(label: _draftStepLabel(draft.currentStep)));
      if (draft.totalReps > 0) {
        pills.add(_DetailPill(label: '${draft.totalReps.round()} reps'));
      }
      if (draft.hasEstimatedVolume) {
        pills.add(
          _DetailPill(
            label:
                '${_formatVolumeValue(draft.estimatedVolume!)} ${draft.estimatedVolumeUnit}',
          ),
        );
      }
      primaryAction = FilledButton(
        onPressed: onResumeDraft,
        child: const Text('Resume Workout'),
      );
    } else if (slot.workout != null) {
      final _TrainingPlanWorkout workout = slot.workout!;
      eyebrow = slot.isCurrentDay ? 'Train Today' : 'Upcoming Session';
      title = workout.title;
      accentColor = slot.isCurrentDay ? const Color(0xFFFFD166) : _accentBlue;
      accentIcon = slot.isCurrentDay
          ? Icons.fitness_center_rounded
          : Icons.schedule_rounded;
      statusBadge = slot.isCurrentDay ? 'Ready' : 'Upcoming';
      body = workout.focus.isNotEmpty
          ? workout.focus
          : 'Your coach has a session ready for this day.';
      contextLine = slot.isCurrentDay
          ? 'Today\'s objective · ${workout.exercises.length} exercises planned'
          : 'Week $weekNumber · ${slot.weekdayLabel} · ${workout.exercises.length} exercises planned';
      for (final _PlannedExercise exercise in workout.exercises.take(3)) {
        pills.add(_DetailPill(label: exercise.title));
      }
      primaryAction = FilledButton(
        onPressed: onPreviewWorkout,
        child: Text(slot.isCurrentDay ? 'Start Workout' : 'Preview Workout'),
      );
    } else if (slot.isCurrentDay && upcomingWorkout != null) {
      eyebrow = 'Next Session';
      title = upcomingWorkout!.title;
      accentColor = _accentBlue;
      accentIcon = Icons.schedule_rounded;
      statusBadge = 'Upcoming';
      body = upcomingWorkout!.focus.isNotEmpty
          ? upcomingWorkout!.focus
          : 'No session is scheduled for today, but the next one is already queued up.';
      contextLine =
          '${_nextSessionLabel(upcomingWorkout!)} · ${upcomingWorkout!.plannedExercises.length} exercises planned';
      pills.add(_DetailPill(label: 'Week ${upcomingWorkout!.weekNumber}'));
      pills.add(_DetailPill(label: upcomingWorkout!.relativeLabel));
      secondaryAction = Text(
        'Current week: $currentWeekNumber',
        style: const TextStyle(
          fontSize: 13,
          color: _textMuted,
        ),
      );
    } else {
      contextLine = slot.isCurrentDay
          ? 'Use today to recover, walk, and be ready for the next lift.'
          : 'Week $weekNumber · ${slot.weekdayLabel}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withValues(alpha: 0.32)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            accentColor.withValues(alpha: 0.08),
            _surface,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Icon(
                  accentIcon,
                  color: accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      eyebrow,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Text(
                        statusBadge,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            contextLine,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: accentColor.withValues(alpha: 0.92),
            ),
          ),
          if (pills.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: pills,
            ),
          ],
          if (primaryAction != null || secondaryAction != null) ...<Widget>[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                if (primaryAction != null) primaryAction,
                if (primaryAction != null && secondaryAction != null)
                  const SizedBox(width: 12),
                if (secondaryAction != null)
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: secondaryAction,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _draftStepLabel(int currentStep) {
    if (currentStep <= 0) {
      return 'At briefing';
    }
    return 'Step ${currentStep + 1}';
  }

  String _draftUpdatedLabel(DateTime updatedAt) {
    final Duration age = DateTime.now().difference(updatedAt.toLocal());
    if (age.inMinutes <= 1) {
      return 'just now';
    }
    if (age.inHours < 1) {
      return '${age.inMinutes} min ago';
    }
    if (age.inDays < 1) {
      return '${age.inHours} h ago';
    }
    return '${age.inDays} d ago';
  }

  String _nextSessionLabel(_UpcomingWorkoutData workout) {
    if (workout.relativeLabel == 'Today') {
      return 'Today';
    }

    final int today = DateTime.now().weekday;
    if (workout.weekNumber == currentWeekNumber &&
        workout.dayNumber == today + 1) {
      return 'Tomorrow';
    }
    if (workout.weekNumber == currentWeekNumber) {
      return 'Later this week';
    }
    if (workout.weekNumber == currentWeekNumber + 1) {
      return 'Next week';
    }
    return 'Week ${workout.weekNumber}';
  }
}

class _RootNavigationStrip extends StatelessWidget {
  const _RootNavigationStrip({
    required this.selectedTab,
    required this.onSelected,
  });

  final _RootTab selectedTab;
  final ValueChanged<_RootTab> onSelected;

  @override
  Widget build(BuildContext context) {
    const List<(_RootTab, IconData, String)> items =
        <(_RootTab, IconData, String)>[
      (_RootTab.home, Icons.home_rounded, 'Home'),
      (_RootTab.program, Icons.menu_book_rounded, 'Program'),
      (_RootTab.history, Icons.history_rounded, 'History'),
      (_RootTab.me, Icons.person_rounded, 'Me'),
    ];

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _outline),
        ),
        child: Row(
          children: items.map(((_RootTab, IconData, String) item) {
            final _RootTab tab = item.$1;
            final bool isSelected = tab == selectedTab;
            final Color color = isSelected ? _accentGreen : _textMuted;

            return Expanded(
              child: InkWell(
                onTap: () => onSelected(tab),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(item.$2, size: 20, color: color),
                      const SizedBox(height: 4),
                      Text(
                        item.$3,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(growable: false),
        ),
      ),
    );
  }
}

class _DetailPill extends StatelessWidget {
  const _DetailPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _surfaceRaised,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _outlineSoft),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _textPrimary,
        ),
      ),
    );
  }
}

class _MiniProgressRing extends StatelessWidget {
  const _MiniProgressRing({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(
        painter: _MiniProgressRingPainter(
          progress: progress,
          color: color,
        ),
      ),
    );
  }
}

class _MiniProgressRingPainter extends CustomPainter {
  const _MiniProgressRingPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const double strokeWidth = 3;
    final Rect rect = Offset.zero & size;
    final Rect arcRect = rect.deflate(strokeWidth / 2);
    final Paint trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final Paint valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      math.pi * 2,
      false,
      trackPaint,
    );
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0, 1),
      false,
      valuePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _WeeklyTransitionCard extends StatelessWidget {
  const _WeeklyTransitionCard({
    required this.currentWeekNumber,
    required this.weeklyPreview,
    required this.lastWeekRecap,
    required this.whatChanged,
  });

  final int currentWeekNumber;
  final _WeeklyCoachingPreview? weeklyPreview;
  final String lastWeekRecap;
  final String whatChanged;

  @override
  Widget build(BuildContext context) {
    final String feedback = weeklyPreview?.feedback.trim() ?? '';
    final String motivation = weeklyPreview?.motivation.trim() ?? '';
    final bool hasGeneratedBriefing =
        feedback.isNotEmpty || motivation.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Weekly Briefing',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _textMuted,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Week $currentWeekNumber',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('Carry Forward'),
                const SizedBox(height: 12),
                Text(
                  lastWeekRecap,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.55,
                    color: _textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('This Week'),
                const SizedBox(height: 12),
                Text(
                  hasGeneratedBriefing
                      ? feedback
                      : 'Your coach is preparing this week\'s note. Stay anchored in the plan and keep the work crisp until it lands.',
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.55,
                    color: _textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('What Changed'),
                const SizedBox(height: 12),
                Text(
                  whatChanged,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.55,
                    color: _textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (motivation.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _surfaceRaised,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _outlineSoft),
              ),
              child: Text(
                motivation,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.55,
                  color: _accentGreen.withValues(alpha: 0.95),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CoachingBookScreen extends StatelessWidget {
  const _CoachingBookScreen({
    required this.athleteName,
    required this.plan,
    required this.currentWeek,
    required this.currentWeekNumber,
    required this.weeklyPreview,
    required this.programLabel,
    required this.nextMilestoneTitle,
    required this.nextMilestoneBody,
    required this.blockProgress,
    required this.completedWorkouts,
    this.initialSelectedWeekNumber,
  });

  final String athleteName;
  final _TrainingPlanResult plan;
  final _TrainingPlanWeek? currentWeek;
  final int currentWeekNumber;
  final _WeeklyCoachingPreview? weeklyPreview;
  final String programLabel;
  final String nextMilestoneTitle;
  final String nextMilestoneBody;
  final double blockProgress;
  final int completedWorkouts;
  final int? initialSelectedWeekNumber;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgTop,
      appBar: AppBar(
        backgroundColor: _bgTop,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Coaching Book',
          style: TextStyle(color: _textPrimary),
        ),
      ),
      body: SafeArea(
        child: _CoachingBookContent(
          athleteName: athleteName,
          plan: plan,
          currentWeek: currentWeek,
          currentWeekNumber: currentWeekNumber,
          weeklyPreview: weeklyPreview,
          programLabel: programLabel,
          nextMilestoneTitle: nextMilestoneTitle,
          nextMilestoneBody: nextMilestoneBody,
          blockProgress: blockProgress,
          completedWorkouts: completedWorkouts,
          initialSelectedWeekNumber: initialSelectedWeekNumber,
          topPadding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        ),
      ),
    );
  }
}

class _CoachingBookContent extends StatefulWidget {
  const _CoachingBookContent({
    required this.athleteName,
    required this.plan,
    required this.currentWeek,
    required this.currentWeekNumber,
    required this.weeklyPreview,
    required this.programLabel,
    required this.nextMilestoneTitle,
    required this.nextMilestoneBody,
    required this.blockProgress,
    required this.completedWorkouts,
    required this.topPadding,
    this.initialSelectedWeekNumber,
  });

  final String athleteName;
  final _TrainingPlanResult plan;
  final _TrainingPlanWeek? currentWeek;
  final int currentWeekNumber;
  final _WeeklyCoachingPreview? weeklyPreview;
  final String programLabel;
  final String nextMilestoneTitle;
  final String nextMilestoneBody;
  final double blockProgress;
  final int completedWorkouts;
  final int? initialSelectedWeekNumber;
  final EdgeInsets topPadding;

  @override
  State<_CoachingBookContent> createState() => _CoachingBookContentState();
}

class _CoachingBookContentState extends State<_CoachingBookContent> {
  late int _selectedWeekNumber;

  @override
  void initState() {
    super.initState();
    _selectedWeekNumber =
        widget.initialSelectedWeekNumber ?? widget.currentWeekNumber;
  }

  @override
  void didUpdateWidget(covariant _CoachingBookContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final int maxWeek = math.max(widget.plan.durationWeeks, 1);
    if (_selectedWeekNumber > maxWeek) {
      _selectedWeekNumber = maxWeek;
    }
  }

  @override
  Widget build(BuildContext context) {
    final int nextWeekNumber = _coachingBookNextMilestoneWeekNumber(
      widget.plan,
      widget.currentWeekNumber,
    );
    final _TrainingPlanWeek? nextWeek =
        _coachingBookWeek(widget.plan, nextWeekNumber);
    final _TrainingPlanWeek? selectedWeek =
        _coachingBookWeek(widget.plan, _selectedWeekNumber);
    final bool selectedWeekIsCurrent =
        selectedWeek?.weekNumber == widget.currentWeekNumber;
    final int progressPercent =
        (widget.blockProgress.clamp(0, 1) * 100).round();
    final String currentTheme = widget.currentWeek?.theme.trim() ?? '';
    final String overviewLabel = currentTheme.isNotEmpty
        ? currentTheme
        : 'Current focus is set by the active week in your block.';

    return SingleChildScrollView(
      padding: widget.topPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 16),
          const Text(
            'Coaching Book',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${widget.plan.durationWeeks} weeks • ${widget.programLabel} • written for ${widget.athleteName}',
            style: const TextStyle(
              fontSize: 15,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('Block Overview'),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _StatusRow(
                        label: 'Current position',
                        value:
                            'Week ${widget.currentWeekNumber} of ${widget.plan.durationWeeks}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatusRow(
                        label: 'Completed',
                        value:
                            '${widget.completedWorkouts}/${widget.plan.totalPlannedWorkouts} workouts',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  overviewLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: _textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: widget.blockProgress.clamp(0, 1),
                    minHeight: 10,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      _accentGreen,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '$progressPercent% of the block completed',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('Program Objective'),
                const SizedBox(height: 12),
                Text(
                  widget.plan.objective,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    color: _textPrimary,
                  ),
                ),
                if (widget.plan.summary.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    widget.plan.summary.trim(),
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('Why This Block Exists'),
                const SizedBox(height: 12),
                Text(
                  _coachingBookBlockExplanation(widget.plan),
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: _textSecondary,
                  ),
                ),
                if (widget.plan.progressionStrategy
                    .trim()
                    .isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  const Text(
                    'Progression',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.plan.progressionStrategy.trim(),
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (selectedWeek != null) ...<Widget>[
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _SectionTitle('Week Timeline'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.plan.weeks
                        .map(
                          (_TrainingPlanWeek week) => InkWell(
                            onTap: () {
                              setState(() {
                                _selectedWeekNumber = week.weekNumber;
                              });
                            },
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: week.weekNumber == _selectedWeekNumber
                                    ? _accentGreen.withValues(alpha: 0.18)
                                    : _surfaceRaised,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: week.weekNumber == _selectedWeekNumber
                                      ? _accentGreen
                                      : _outlineSoft,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    '${week.weekNumber}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color:
                                          week.weekNumber == _selectedWeekNumber
                                              ? _accentGreen
                                              : _textPrimary,
                                    ),
                                  ),
                                  if (week.weekNumber ==
                                      widget.currentWeekNumber) ...<Widget>[
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFFD166),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Week ${selectedWeek.weekNumber}${selectedWeek.weekNumber == widget.currentWeekNumber ? ' · active in the block' : ''}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: selectedWeek.weekNumber == widget.currentWeekNumber
                          ? _accentGreen
                          : _textPrimary,
                    ),
                  ),
                  if (selectedWeek.theme.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      selectedWeek.theme.trim(),
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'Why This Week Matters',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _coachingBookWeekExplanation(
                      selectedWeek,
                      selectedWeekIsCurrent: selectedWeekIsCurrent,
                      weeklyPreview: widget.weeklyPreview,
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: _textSecondary,
                    ),
                  ),
                  if (selectedWeek.workouts.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 16),
                    const _SectionTitle('Planned Workouts'),
                    const SizedBox(height: 12),
                    for (int index = 0;
                        index < selectedWeek.workouts.length;
                        index++) ...<Widget>[
                      _CoachingBookWorkoutRow(
                        workout: selectedWeek.workouts[index],
                      ),
                      if (index != selectedWeek.workouts.length - 1)
                        const SizedBox(height: 12),
                    ],
                  ] else ...<Widget>[
                    const SizedBox(height: 16),
                    const Text(
                      'No workouts are scheduled for this week yet.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: _textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('Next Milestone'),
                const SizedBox(height: 12),
                Text(
                  widget.nextMilestoneTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
                if (nextWeek != null &&
                    nextWeek.theme.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    nextWeek.theme.trim(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _accentBlue,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  widget.nextMilestoneBody,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: _textSecondary,
                  ),
                ),
                if (widget.weeklyPreview != null &&
                    widget.weeklyPreview!.previewWeek == nextWeekNumber &&
                    widget.weeklyPreview!.previewTheme
                        .trim()
                        .isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  const Text(
                    'Preview theme',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.weeklyPreview!.previewTheme.trim(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _accentBlue,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('Coach\'s Lens'),
                if (widget.plan.philosophy.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    widget.plan.philosophy.trim(),
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: _textSecondary,
                    ),
                  ),
                ],
                if (widget.plan.progressionStrategy
                    .trim()
                    .isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  const Text(
                    'Progression strategy',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.plan.progressionStrategy.trim(),
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: _textSecondary,
                    ),
                  ),
                ],
                if (widget.plan.successCriteria.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  const Text(
                    'What success looks like',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.plan.successCriteria.trim(),
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (widget.plan.risks.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _SectionTitle('Risks & Watchouts'),
                  const SizedBox(height: 12),
                  Text(
                    widget.plan.risks.trim(),
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  _TrainingPlanWeek? _coachingBookWeek(
      _TrainingPlanResult plan, int weekNumber) {
    for (final _TrainingPlanWeek week in plan.weeks) {
      if (week.weekNumber == weekNumber) {
        return week;
      }
    }
    return null;
  }

  int _coachingBookNextMilestoneWeekNumber(
    _TrainingPlanResult plan,
    int currentWeekNumber,
  ) {
    if (currentWeekNumber >= plan.durationWeeks) {
      return plan.durationWeeks;
    }

    final int nextWeek = currentWeekNumber + 1;
    return nextWeek.clamp(1, plan.durationWeeks);
  }

  String _coachingBookBlockExplanation(_TrainingPlanResult plan) {
    final List<String> parts = <String>[];
    if (plan.summary.trim().isNotEmpty) {
      parts.add(plan.summary.trim());
    }
    if (plan.philosophy.trim().isNotEmpty) {
      parts.add(_coachingBookFirstSentence(plan.philosophy));
    }
    if (parts.isEmpty) {
      return 'This block is written to build steady progress, keep the signal clear, and prepare stronger work later in the cycle.';
    }
    return parts.join(' ');
  }

  String _coachingBookWeekExplanation(
    _TrainingPlanWeek week, {
    required bool selectedWeekIsCurrent,
    required _WeeklyCoachingPreview? weeklyPreview,
  }) {
    final List<String> parts = <String>[];
    if (week.theme.trim().isNotEmpty) {
      parts.add(week.theme.trim());
    }
    if (selectedWeekIsCurrent &&
        weeklyPreview != null &&
        weeklyPreview.currentWeek == week.weekNumber &&
        weeklyPreview.feedback.trim().isNotEmpty) {
      parts.add(weeklyPreview.feedback.trim());
    } else if (weeklyPreview != null &&
        weeklyPreview.previewWeek == week.weekNumber &&
        weeklyPreview.previewTheme.trim().isNotEmpty) {
      parts.add(weeklyPreview.previewTheme.trim());
    } else if (week.workouts.isNotEmpty) {
      final List<String> workoutNames = week.workouts
          .take(3)
          .map((_TrainingPlanWorkout workout) => workout.title)
          .toList(growable: false);
      parts.add(
        'This week is organized around ${workoutNames.join(', ')} to move the block forward without losing quality.',
      );
    }
    if (parts.isEmpty) {
      return 'This week continues the broader block objective with steady, repeatable work.';
    }
    return parts.join(' ');
  }

  String _coachingBookFirstSentence(String text) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final RegExp sentenceBoundary = RegExp(r'(?<=[.!?])\s+');
    final List<String> parts = trimmed.split(sentenceBoundary);
    return parts.first.trim();
  }
}

class _CoachingBookWorkoutRow extends StatelessWidget {
  const _CoachingBookWorkoutRow({
    required this.workout,
  });

  final _TrainingPlanWorkout workout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Day ${workout.dayNumber}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: _textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            workout.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          if (workout.focus.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              workout.focus.trim(),
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: _textSecondary,
              ),
            ),
          ],
          if (workout.exercises.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: workout.exercises
                  .map(
                    (_PlannedExercise exercise) =>
                        _DetailPill(label: exercise.title),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _CoachStatusBanner extends StatelessWidget {
  const _CoachStatusBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _surfaceRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _outline),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 14,
          height: 1.4,
          color: _textSecondary,
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.eyebrow,
    required this.title,
    this.body = '',
  });

  final String eyebrow;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            eyebrow,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          if (body.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: _textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _outline),
        ),
        child: child,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: _textPrimary,
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _textMuted,
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(
          value,
          style: const TextStyle(
            fontSize: 15,
            color: _textPrimary,
          ),
        ),
      ],
    );
  }
}

class _TrainingPlanResult {
  const _TrainingPlanResult({
    required this.planID,
    required this.objective,
    required this.durationWeeks,
    required this.daysPerWeek,
    required this.summary,
    required this.philosophy,
    required this.progressionStrategy,
    required this.risks,
    required this.successCriteria,
    required this.provider,
    required this.model,
    required this.generated,
    required this.dailyLimit,
    required this.generatedToday,
    required this.remainingToday,
    required this.weeks,
  });

  factory _TrainingPlanResult.fromJson(Map<String, dynamic> json) {
    final Object? weeksValue = json['weeks'];
    final List<_TrainingPlanWeek> weeks = weeksValue is List<dynamic>
        ? weeksValue
            .whereType<Map<String, dynamic>>()
            .map(_TrainingPlanWeek.fromJson)
            .toList()
        : <_TrainingPlanWeek>[];

    return _TrainingPlanResult(
      planID: (json['id'] as num?)?.toInt() ?? 0,
      objective: (json['objective'] as String?) ?? 'Training plan',
      durationWeeks: (json['duration_weeks'] as num?)?.toInt() ?? 0,
      daysPerWeek: (json['days_per_week'] as num?)?.toInt() ?? 0,
      summary: (json['summary'] as String?) ?? '',
      philosophy: (json['philosophy'] as String?) ?? '',
      progressionStrategy: (json['progression_strategy'] as String?) ?? '',
      risks: (json['risks'] as String?) ?? '',
      successCriteria: (json['success_criteria'] as String?) ?? '',
      provider: (json['provider'] as String?) ?? 'unknown',
      model: (json['model'] as String?) ?? 'unknown',
      generated: json['generated'] as bool? ?? false,
      dailyLimit: (json['daily_limit'] as num?)?.toInt() ?? 0,
      generatedToday: (json['generated_today'] as num?)?.toInt() ?? 0,
      remainingToday: (json['remaining_today'] as num?)?.toInt() ?? 0,
      weeks: weeks,
    );
  }

  final int planID;
  final String objective;
  final int durationWeeks;
  final int daysPerWeek;
  final String summary;
  final String philosophy;
  final String progressionStrategy;
  final String risks;
  final String successCriteria;
  final String provider;
  final String model;
  final bool generated;
  final int dailyLimit;
  final int generatedToday;
  final int remainingToday;
  final List<_TrainingPlanWeek> weeks;

  int get totalPlannedWorkouts {
    int total = 0;
    for (final _TrainingPlanWeek week in weeks) {
      total += week.workouts.length;
    }
    return total;
  }

  String get usageLabel {
    if (dailyLimit <= 0) {
      return 'quota not configured';
    }

    return '$generatedToday/$dailyLimit generated today, $remainingToday left';
  }

  _TrainingPlanWorkout? findWorkout(int weekNumber, int dayNumber) {
    for (final _TrainingPlanWeek week in weeks) {
      if (week.weekNumber != weekNumber) {
        continue;
      }

      for (final _TrainingPlanWorkout workout in week.workouts) {
        if (workout.dayNumber == dayNumber) {
          return workout;
        }
      }
    }

    return null;
  }
}

class _TrainingPlanJob {
  const _TrainingPlanJob({
    required this.id,
    required this.created,
    required this.status,
    required this.objective,
    required this.durationWeeks,
    required this.daysPerWeek,
    required this.measurementSystem,
    required this.errorMessage,
    required this.trainingPlanID,
  });

  factory _TrainingPlanJob.fromJson(Map<String, dynamic> json) {
    return _TrainingPlanJob(
      id: (json['id'] as String?) ?? '',
      created: json['created'] as bool? ?? false,
      status: (json['status'] as String?) ?? '',
      objective: (json['objective'] as String?) ?? '',
      durationWeeks: (json['duration_weeks'] as num?)?.toInt() ?? 0,
      daysPerWeek: (json['days_per_week'] as num?)?.toInt() ?? 0,
      measurementSystem: (json['measurement_system'] as String?) ?? '',
      errorMessage: (json['error_message'] as String?) ?? '',
      trainingPlanID: (json['training_plan_id'] as num?)?.toInt(),
    );
  }

  final String id;
  final bool created;
  final String status;
  final String objective;
  final int durationWeeks;
  final int daysPerWeek;
  final String measurementSystem;
  final String errorMessage;
  final int? trainingPlanID;

  bool get isActive =>
      status == _trainingPlanJobQueuedStatus ||
      status == _trainingPlanJobRunningStatus;
}

class _WeeklyCoachingPreview {
  const _WeeklyCoachingPreview({
    required this.trainingPlanID,
    required this.currentWeek,
    required this.previewWeek,
    required this.previewTheme,
    required this.provider,
    required this.model,
    required this.promptVersion,
    required this.feedback,
    required this.motivation,
  });

  factory _WeeklyCoachingPreview.fromJson(Map<String, dynamic> json) {
    return _WeeklyCoachingPreview(
      trainingPlanID: (json['training_plan_id'] as num?)?.toInt() ?? 0,
      currentWeek: (json['current_week'] as num?)?.toInt() ?? 0,
      previewWeek: (json['preview_week'] as num?)?.toInt() ?? 0,
      previewTheme: (json['preview_theme'] as String?) ?? '',
      provider: (json['provider'] as String?) ?? '',
      model: (json['model'] as String?) ?? '',
      promptVersion: (json['prompt_version'] as String?) ?? '',
      feedback: (json['feedback'] as String?) ?? '',
      motivation: (json['motivation'] as String?) ?? '',
    );
  }

  final int trainingPlanID;
  final int currentWeek;
  final int previewWeek;
  final String previewTheme;
  final String provider;
  final String model;
  final String promptVersion;
  final String feedback;
  final String motivation;
}

class _TrainingPlanWeek {
  const _TrainingPlanWeek({
    required this.weekNumber,
    required this.theme,
    required this.workouts,
  });

  factory _TrainingPlanWeek.fromJson(Map<String, dynamic> json) {
    final Object? workoutsValue = json['workouts'];
    final List<_TrainingPlanWorkout> workouts = workoutsValue is List<dynamic>
        ? workoutsValue
            .whereType<Map<String, dynamic>>()
            .map(_TrainingPlanWorkout.fromJson)
            .toList()
        : <_TrainingPlanWorkout>[];

    return _TrainingPlanWeek(
      weekNumber: (json['week_number'] as num?)?.toInt() ?? 0,
      theme: (json['theme'] as String?) ?? '',
      workouts: workouts,
    );
  }

  final int weekNumber;
  final String theme;
  final List<_TrainingPlanWorkout> workouts;
}

class _TrainingPlanWorkout {
  const _TrainingPlanWorkout({
    required this.dayNumber,
    required this.title,
    required this.focus,
    required this.exercises,
  });

  factory _TrainingPlanWorkout.fromJson(Map<String, dynamic> json) {
    final Object? exercisesValue = json['exercises'];
    final List<_PlannedExercise> exercises = exercisesValue is List<dynamic>
        ? exercisesValue
            .map<_PlannedExercise?>((dynamic item) {
              if (item is Map<String, dynamic>) {
                return _PlannedExercise.fromJson(item);
              }
              if (item is String) {
                return _PlannedExercise(
                    title: item, notes: '', sets: const <_PlannedSet>[]);
              }
              return null;
            })
            .whereType<_PlannedExercise>()
            .toList()
        : <_PlannedExercise>[];

    return _TrainingPlanWorkout(
      dayNumber: (json['day_number'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String?) ?? 'Workout',
      focus: (json['focus'] as String?) ?? '',
      exercises: exercises,
    );
  }

  final int dayNumber;
  final String title;
  final String focus;
  final List<_PlannedExercise> exercises;

  List<String> get exerciseTitles =>
      exercises.map((_PlannedExercise exercise) => exercise.title).toList();
}

class _PlannedExercise {
  const _PlannedExercise({
    required this.title,
    required this.notes,
    required this.sets,
  });

  factory _PlannedExercise.fromJson(Map<String, dynamic> json) {
    final Object? setsValue = json['sets'];
    final List<_PlannedSet> sets = setsValue is List<dynamic>
        ? setsValue
            .whereType<Map<String, dynamic>>()
            .map(_PlannedSet.fromJson)
            .toList()
        : <_PlannedSet>[];

    return _PlannedExercise(
      title: (json['title'] as String?) ?? 'Exercise',
      notes: (json['notes'] as String?) ?? '',
      sets: sets,
    );
  }

  final String title;
  final String notes;
  final List<_PlannedSet> sets;
}

class _PlannedSet {
  const _PlannedSet({
    required this.reps,
    required this.targetValue,
    required this.targetUnit,
    required this.loadValue,
    required this.loadUnit,
  });

  factory _PlannedSet.fromJson(Map<String, dynamic> json) {
    return _PlannedSet(
      reps: (json['reps'] as num?)?.toDouble(),
      targetValue: (json['target_value'] as num?)?.toDouble(),
      targetUnit: (json['target_unit'] as String?) ?? '',
      loadValue: (json['load_value'] as num?)?.toDouble(),
      loadUnit: (json['load_unit'] as String?) ?? '',
    );
  }

  final double? reps;
  final double? targetValue;
  final String targetUnit;
  final double? loadValue;
  final String loadUnit;
}

class _UpcomingWorkoutData {
  const _UpcomingWorkoutData({
    required this.relativeLabel,
    required this.weekNumber,
    required this.dayNumber,
    required this.title,
    required this.focus,
    required this.plannedExercises,
  });

  final String relativeLabel;
  final int weekNumber;
  final int dayNumber;
  final String title;
  final String focus;
  final List<_PlannedExercise> plannedExercises;

  List<String> get exercises => plannedExercises
      .map((_PlannedExercise exercise) => exercise.title)
      .toList();
}

class _ResumableWorkoutContext {
  const _ResumableWorkoutContext({
    required this.draft,
    required this.workout,
  });

  final _WorkoutSessionDraftSummary draft;
  final _UpcomingWorkoutData workout;
}

class _WeekdayWorkoutSlot {
  const _WeekdayWorkoutSlot({
    required this.weekdayLabel,
    required this.weekdayIndex,
    required this.isCurrentDay,
    required this.workout,
    required this.loggedWorkout,
    required this.draftSummary,
  });

  final String weekdayLabel;
  final int weekdayIndex;
  final bool isCurrentDay;
  final _TrainingPlanWorkout? workout;
  final _WorkoutLogItem? loggedWorkout;
  final _WorkoutSessionDraftSummary? draftSummary;

  bool get hasWorkout => workout != null;
  bool get hasDraft => draftSummary != null;
}

class _PlannedExerciseExplanationResponse {
  const _PlannedExerciseExplanationResponse({
    required this.exerciseTitle,
    required this.reason,
    required this.support,
    required this.execution,
    required this.movementPattern,
  });

  factory _PlannedExerciseExplanationResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return _PlannedExerciseExplanationResponse(
      exerciseTitle: (json['exercise_title'] as String?) ?? '',
      reason: (json['reason'] as String?) ?? '',
      support: (json['support'] as String?) ?? '',
      execution: (json['execution'] as String?) ?? '',
      movementPattern: (json['movement_pattern'] as String?) ?? '',
    );
  }

  final String exerciseTitle;
  final String reason;
  final String support;
  final String execution;
  final String movementPattern;
}

class _RecentWorkoutLogsCard extends StatelessWidget {
  const _RecentWorkoutLogsCard({
    required this.logs,
    this.onOpenLog,
  });

  final List<_WorkoutLogItem> logs;
  final ValueChanged<_WorkoutLogItem>? onOpenLog;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _SectionTitle('Recent Sessions'),
          const SizedBox(height: 14),
          for (final _WorkoutLogItem log in logs) ...<Widget>[
            InkWell(
              onTap: onOpenLog == null ? null : () => onOpenLog!(log),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _surfaceRaised,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _outline),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${log.dayNumber}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Week ${log.weekNumber} · ${log.title}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            log.hasEstimatedVolume
                                ? '${log.completedSetCount}/${log.setCount} sets completed · ${_formatVolumeValue(log.estimatedVolume!)} ${log.estimatedVolumeUnit} volume'
                                : '${log.completedSetCount}/${log.setCount} sets completed',
                            style: const TextStyle(
                              fontSize: 14,
                              color: _textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onOpenLog != null)
                      const Padding(
                        padding: EdgeInsets.only(left: 12, top: 10),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: _textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (log != logs.last) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _WorkoutReviewScreen extends StatelessWidget {
  const _WorkoutReviewScreen({
    required this.plan,
    required this.savedLog,
    required this.plannedWorkout,
    required this.reviewDetails,
    required this.onOpenCoachingBook,
  });

  final _TrainingPlanResult plan;
  final _WorkoutLogItem savedLog;
  final _TrainingPlanWorkout? plannedWorkout;
  final _WorkoutReviewDetails reviewDetails;
  final VoidCallback onOpenCoachingBook;

  @override
  Widget build(BuildContext context) {
    final String reviewText = savedLog.review?.review.trim().isNotEmpty == true
        ? savedLog.review!.review.trim()
        : 'The session was saved, but a coach review was not generated for this one.';

    return Scaffold(
      backgroundColor: _bgBottom,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _textPrimary,
        title: const Text('Session Review'),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[_bgTop, _bgBottom],
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _CoachPill(label: 'Post-Workout Review'),
                const SizedBox(height: 16),
                Text(
                  savedLog.title,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Week ${savedLog.weekNumber} · Day ${savedLog.dayNumber} · ${plan.objective}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: _textSecondary,
                  ),
                ),
                if (savedLog.focus.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  Text(
                    savedLog.focus.trim(),
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: _textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _MetricCard(
                        eyebrow: 'Sets',
                        title:
                            '${reviewDetails.completedSetCount}/${reviewDetails.setCount}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        eyebrow: 'Reps',
                        title: '${reviewDetails.totalReps.round()}',
                      ),
                    ),
                  ],
                ),
                if (reviewDetails.hasEstimatedVolume ||
                    savedLog.durationMinutes != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      if (reviewDetails.hasEstimatedVolume)
                        Expanded(
                          child: _MetricCard(
                            eyebrow: 'Volume',
                            title:
                                '${_formatVolumeValue(reviewDetails.estimatedVolume!)} ${reviewDetails.estimatedVolumeUnit}',
                          ),
                        ),
                      if (reviewDetails.hasEstimatedVolume &&
                          savedLog.durationMinutes != null)
                        const SizedBox(width: 12),
                      if (savedLog.durationMinutes != null)
                        Expanded(
                          child: _MetricCard(
                            eyebrow: 'Duration',
                            title: '${savedLog.durationMinutes} min',
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const _SectionTitle('Intensity'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _surfaceRaised,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: _outline),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              _intensityIcon(reviewDetails.feelLabel),
                              size: 16,
                              color: _textPrimary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              reviewDetails.feelLabel,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (reviewDetails
                          .parsedFeedback.note.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 12),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: _textSecondary,
                            ),
                            children: <InlineSpan>[
                              const TextSpan(
                                text: 'Athlete note: ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _textPrimary,
                                ),
                              ),
                              TextSpan(
                                text: reviewDetails.parsedFeedback.note,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const _SectionTitle('Coach Review'),
                      const SizedBox(height: 12),
                      Text(
                        reviewText,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          color: _textSecondary,
                        ),
                      ),
                      if (savedLog.review != null &&
                          savedLog.review!.provider
                              .trim()
                              .isNotEmpty) ...<Widget>[
                        const SizedBox(height: 12),
                        Text(
                          '${savedLog.review!.provider} · ${savedLog.review!.model} · ${savedLog.review!.promptVersion}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: onOpenCoachingBook,
                    icon: const Icon(Icons.menu_book_rounded),
                    label: const Text('Open Coaching Book'),
                  ),
                ),
                if (plannedWorkout != null &&
                    plannedWorkout!.exercises.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const _SectionTitle('Session Layout'),
                        const SizedBox(height: 12),
                        for (int index = 0;
                            index < plannedWorkout!.exercises.length;
                            index++) ...<Widget>[
                          Text(
                            '${index + 1}. ${plannedWorkout!.exercises[index].title}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _exerciseReviewSummary(
                              plannedWorkout!.exercises[index],
                              index < savedLog.exercises.length
                                  ? savedLog.exercises[index]
                                  : null,
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: _textSecondary,
                            ),
                          ),
                          if (plannedWorkout!.exercises[index].notes
                              .trim()
                              .isNotEmpty) ...<Widget>[
                            const SizedBox(height: 4),
                            Text(
                              plannedWorkout!.exercises[index].notes.trim(),
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: _textMuted,
                              ),
                            ),
                          ],
                          if (index != plannedWorkout!.exercises.length - 1)
                            const SizedBox(height: 14),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _intensityIcon(String feelLabel) {
    switch (feelLabel.trim().toLowerCase()) {
      case 'easy':
        return Icons.sentiment_satisfied_alt_rounded;
      case 'good':
        return Icons.check_circle_rounded;
      case 'hard':
        return Icons.fitness_center_rounded;
      case 'brutal':
        return Icons.local_fire_department_rounded;
      default:
        return Icons.bolt_rounded;
    }
  }

  String _exerciseReviewSummary(
    _PlannedExercise plannedExercise,
    _WorkoutLogExerciseItem? actualExercise,
  ) {
    final int plannedSetCount = plannedExercise.sets.length;
    final int completedSetCount = actualExercise == null
        ? 0
        : actualExercise.sets
            .where((_WorkoutLogSetItem set) => set.completed)
            .length;
    final double totalReps = actualExercise == null
        ? 0
        : actualExercise.sets.fold<double>(
            0,
            (double total, _WorkoutLogSetItem set) =>
                total + (set.completed ? (set.reps ?? 0) : 0),
          );
    final List<String> parts = <String>[
      '$completedSetCount/$plannedSetCount sets completed',
      if (totalReps > 0) '${totalReps.toStringAsFixed(0)} reps logged',
    ];
    return parts.join(' · ');
  }
}

class _WorkoutSessionScreen extends StatefulWidget {
  const _WorkoutSessionScreen({
    required this.plan,
    required this.workout,
    required this.localCacheRepository,
    required this.firebaseUid,
    this.existingLog,
    this.initialDraftSnapshot,
  });

  final _TrainingPlanResult plan;
  final _UpcomingWorkoutData workout;
  final DriftLocalCacheRepository localCacheRepository;
  final String? firebaseUid;
  final _WorkoutLogItem? existingLog;
  final _WorkoutSessionDraftSnapshot? initialDraftSnapshot;

  @override
  State<_WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<_WorkoutSessionScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const List<String> _sessionFeelLabels = <String>[
    'Easy',
    'Good',
    'Hard',
    'Brutal',
  ];

  late final TextEditingController _durationController;
  late final TextEditingController _sessionNotesController;
  late final List<_WorkoutLogExerciseDraftState> _exercises;
  late final List<_WorkoutExerciseScreenGroup> _exerciseGroups;
  late DateTime _startedAt;
  Timer? _elapsedTicker;
  Timer? _draftPersistDebounce;
  Duration _elapsed = Duration.zero;
  bool _hasManualDurationOverride = false;
  int _currentStep = 0;
  int _sessionFeelIndex = 1;
  double _stepDragDistance = 0;
  double _stepOffset = 0;
  late final AnimationController _stepAnimationController;
  Animation<double>? _stepOffsetAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _stepAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        if (!mounted || _stepOffsetAnimation == null) {
          return;
        }
        setState(() {
          _stepOffset = _stepOffsetAnimation!.value;
        });
      });
    final _WorkoutSessionDraftSnapshot? initialDraftSnapshot =
        widget.initialDraftSnapshot;
    final String initialSessionNotes = initialDraftSnapshot?.sessionNotes ??
        widget.existingLog?.sessionNotes ??
        '';
    final _ParsedSessionFeedback initialFeedback =
        _parseSessionFeedback(initialSessionNotes);
    final int? initialDurationMinutes = initialDraftSnapshot?.durationMinutes ??
        widget.existingLog?.durationMinutes;
    _durationController = TextEditingController(
      text: initialDurationMinutes?.toString() ?? '0',
    );
    _sessionNotesController = TextEditingController(
      text: initialFeedback.note,
    );
    _hasManualDurationOverride = widget.existingLog != null;
    _sessionFeelIndex =
        initialDraftSnapshot?.sessionFeelIndex ?? initialFeedback.feelIndex;
    _currentStep = initialDraftSnapshot?.currentStep ?? 0;
    _exercises = _buildInitialExercises();
    _exerciseGroups = _buildExerciseGroups(_exercises);
    final int initialMinutes = initialDurationMinutes ?? 0;
    _startedAt = DateTime.now().subtract(Duration(minutes: initialMinutes));
    _elapsed = DateTime.now().difference(_startedAt);
    _elapsedTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _elapsed = DateTime.now().difference(_startedAt);
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _elapsedTicker?.cancel();
    _draftPersistDebounce?.cancel();
    _stepAnimationController.dispose();
    _durationController.dispose();
    _sessionNotesController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _persistDraftImmediately();
    }
  }

  int get _totalSteps => 3 + _exerciseGroups.length;

  List<_WorkoutLogExerciseDraftState> _buildInitialExercises() {
    final _WorkoutSessionDraftSnapshot? initialDraftSnapshot =
        widget.initialDraftSnapshot;
    if (initialDraftSnapshot != null &&
        initialDraftSnapshot.exercises.isNotEmpty) {
      return initialDraftSnapshot.exercises
          .map(
            (_WorkoutLogDraftExercise exercise) =>
                _WorkoutLogExerciseDraftState(
              title: exercise.title,
              notes: exercise.notes,
              sets: exercise.sets
                  .map(
                    (_WorkoutLogDraftSet set) => _WorkoutLogSetDraftState(
                      reps: set.reps == null ? '' : _formatRepsValue(set.reps!),
                      value: set.value == null
                          ? ''
                          : _formatWorkoutFieldNumber(set.value!),
                      unit: set.unit,
                      loadValue: set.loadValue == null
                          ? ''
                          : _formatWorkoutFieldNumber(set.loadValue!),
                      loadUnit: set.loadUnit,
                      completed: set.completed,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList();
    }

    final _WorkoutLogItem? existingLog = widget.existingLog;
    if (existingLog != null && existingLog.exercises.isNotEmpty) {
      return existingLog.exercises
          .map(
            (_WorkoutLogExerciseItem exercise) => _WorkoutLogExerciseDraftState(
              title: exercise.title,
              notes: exercise.notes,
              sets: exercise.sets
                  .map(
                    (_WorkoutLogSetItem set) => _WorkoutLogSetDraftState(
                      reps: set.reps == null ? '' : _formatRepsValue(set.reps!),
                      value: set.value == null
                          ? ''
                          : _formatWorkoutFieldNumber(set.value!),
                      unit: set.unit,
                      loadValue: set.loadValue == null
                          ? ''
                          : _formatWorkoutFieldNumber(set.loadValue!),
                      loadUnit: set.loadUnit,
                      completed: set.completed,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList();
    }

    return widget.workout.plannedExercises
        .map(
          (_PlannedExercise exercise) => _WorkoutLogExerciseDraftState(
            title: exercise.title,
            notes: exercise.notes,
            sets: exercise.sets.isEmpty
                ? List<_WorkoutLogSetDraftState>.generate(
                    3,
                    (_) => const _WorkoutLogSetDraftState(
                      reps: '',
                      value: '',
                      unit: '',
                      loadValue: '',
                      loadUnit: '',
                      completed: false,
                    ),
                  )
                : exercise.sets
                    .map(
                      (_PlannedSet set) => _WorkoutLogSetDraftState(
                        reps:
                            set.reps == null ? '' : _formatRepsValue(set.reps!),
                        value: set.targetValue == null
                            ? ''
                            : _formatWorkoutFieldNumber(set.targetValue!),
                        unit: set.targetUnit,
                        loadValue: set.loadValue == null
                            ? ''
                            : _formatWorkoutFieldNumber(set.loadValue!),
                        loadUnit: set.loadUnit,
                        completed: false,
                      ),
                    )
                    .toList(),
          ),
        )
        .toList();
  }

  List<_WorkoutExerciseScreenGroup> _buildExerciseGroups(
    List<_WorkoutLogExerciseDraftState> exercises,
  ) {
    final List<_WorkoutExerciseScreenGroup> groups =
        <_WorkoutExerciseScreenGroup>[];
    int index = 0;
    while (index < exercises.length) {
      final _WorkoutLogExerciseDraftState exercise = exercises[index];
      final String? supersetTag = _supersetTag(exercise.title);
      if (supersetTag == null) {
        groups.add(
          _WorkoutExerciseScreenGroup(
            title: exercise.title,
            indices: <int>[index],
            isSuperset: false,
          ),
        );
        index++;
        continue;
      }

      final List<int> indices = <int>[index];
      int next = index + 1;
      while (next < exercises.length &&
          _supersetTag(exercises[next].title) == supersetTag) {
        indices.add(next);
        next++;
      }

      groups.add(
        _WorkoutExerciseScreenGroup(
          title: 'Superset $supersetTag',
          indices: indices,
          isSuperset: indices.length > 1,
        ),
      );
      index = next;
    }

    return groups;
  }

  String? _supersetTag(String title) {
    final RegExp prefixPattern = RegExp(r'^([A-Z])\d+\b');
    final Match? prefixMatch = prefixPattern.firstMatch(title.trim());
    if (prefixMatch != null) {
      return prefixMatch.group(1);
    }

    final String lower = title.toLowerCase();
    if (lower.contains('superset')) {
      return lower;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgTop,
      appBar: AppBar(
        backgroundColor: _bgTop,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.workout.title,
          style: const TextStyle(color: _textPrimary),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _WorkoutSessionProgress(
                step: _currentStep + 1,
                totalSteps: _totalSteps,
              ),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) {
                  _stepAnimationController.stop();
                  _stepOffsetAnimation = null;
                  _stepDragDistance = 0;
                },
                onHorizontalDragUpdate: (DragUpdateDetails details) {
                  final double delta = details.primaryDelta ?? 0;
                  _stepDragDistance += delta;
                  setState(() {
                    _stepOffset += delta;
                  });
                },
                onHorizontalDragEnd: (DragEndDetails details) {
                  final double velocity = details.primaryVelocity ?? 0;
                  final double distance = _stepDragDistance;
                  _stepDragDistance = 0;
                  _handleStepDragEnd(
                    viewportWidth: MediaQuery.sizeOf(context).width - 40,
                    velocity: velocity,
                    distance: distance,
                  );
                },
                onHorizontalDragCancel: () {
                  _stepDragDistance = 0;
                  _animateStepBack();
                },
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double viewportWidth = constraints.maxWidth;
                    final int? adjacentStep = _adjacentStepIndex();
                    return ClipRect(
                      child: Stack(
                        children: <Widget>[
                          if (adjacentStep != null)
                            Transform.translate(
                              offset: Offset(
                                _stepOffset > 0
                                    ? _stepOffset - viewportWidth
                                    : _stepOffset + viewportWidth,
                                0,
                              ),
                              child: KeyedSubtree(
                                key: ValueKey<int>(adjacentStep),
                                child: _buildStepBodyFor(adjacentStep),
                              ),
                            ),
                          Transform.translate(
                            offset: Offset(_stepOffset, 0),
                            child: KeyedSubtree(
                              key: ValueKey<int>(_currentStep),
                              child: _buildStepBodyFor(_currentStep),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Text(
                'Swipe left or right to move between coaching steps.',
                style: TextStyle(
                  fontSize: 13,
                  color: _textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int? _adjacentStepIndex() {
    if (_stepOffset > 0 && _currentStep > 0) {
      return _currentStep - 1;
    }
    if (_stepOffset < 0 && _currentStep < _totalSteps - 1) {
      return _currentStep + 1;
    }
    return null;
  }

  Widget _buildStepBodyFor(int stepIndex) {
    if (stepIndex == 0) {
      return _buildCoachInstructionsStep();
    }
    if (stepIndex <= _exerciseGroups.length) {
      return _buildExerciseStep(_exerciseGroups[stepIndex - 1]);
    }
    if (stepIndex == _exerciseGroups.length + 1) {
      return _buildWrapUpStep();
    }
    return _buildSummaryStep();
  }

  Widget _buildCoachInstructionsStep() {
    return SingleChildScrollView(
      key: const ValueKey<String>('coach_instructions'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _CoachPill(label: 'Coach Instructions'),
          const SizedBox(height: 16),
          Text(
            'Week ${widget.workout.weekNumber} of ${widget.plan.durationWeeks}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.workout.title,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            widget.workout.focus,
            style: const TextStyle(
              fontSize: 18,
              height: 1.55,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('Today\'s Flow'),
                const SizedBox(height: 14),
                for (final _WorkoutExerciseScreenGroup group in _exerciseGroups)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _surfaceRaised,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _outline),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${_exerciseGroups.indexOf(group) + 1}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            group.isSuperset
                                ? '${group.title}: ${group.indices.map((int index) => _exercises[index].title).join(' + ')}'
                                : _exercises[group.indices.first].title,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: _textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseStep(_WorkoutExerciseScreenGroup group) {
    return SingleChildScrollView(
      key: ValueKey<String>('exercise_${group.title}'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _CoachPill(label: group.isSuperset ? 'Superset' : 'Exercise'),
          const SizedBox(height: 16),
          Text(
            group.title,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (group.isSuperset)
            const Text(
              'These movements are meant to live together. Complete them as a paired sequence before moving on.',
              style:
                  TextStyle(fontSize: 16, height: 1.5, color: _textSecondary),
            )
          else
            Text(
              _exerciseGuidance(_exercises[group.indices.first].title),
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                color: _textSecondary,
              ),
            ),
          const SizedBox(height: 18),
          for (final int index in group.indices) ...<Widget>[
            _buildExerciseEditor(index),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildWrapUpStep() {
    return SingleChildScrollView(
      key: const ValueKey<String>('wrap_up'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _CoachPill(label: 'Wrap Up'),
          const SizedBox(height: 16),
          const Text(
            'Finish The Session',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Confirm how long this actually took and leave feedback while it is still fresh.',
            style: TextStyle(
              fontSize: 16,
              height: 1.55,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('Elapsed Time'),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    IconButton.filledTonal(
                      onPressed: () => _adjustElapsedMinutes(-5),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: _editElapsedMinutes,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: _surfaceRaised,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: _outlineSoft),
                          ),
                          child: Column(
                            children: <Widget>[
                              Text(
                                _formatElapsedMinutesOnly(_elapsed.inMinutes),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: _textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Tap to type a minute count',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      onPressed: () => _adjustElapsedMinutes(5),
                      icon: const Icon(Icons.keyboard_arrow_up_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('How did it feel?'),
                const SizedBox(height: 12),
                _SessionFeelSelector(
                  labels: _sessionFeelLabels,
                  selectedIndex: _sessionFeelIndex,
                  onChanged: (int index) {
                    setState(() {
                      _sessionFeelIndex = index;
                    });
                    _scheduleDraftPersist();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('Athlete note'),
                const SizedBox(height: 12),
                TextField(
                  controller: _sessionNotesController,
                  minLines: 4,
                  maxLines: 6,
                  onChanged: (_) => _scheduleDraftPersist(),
                  decoration: const InputDecoration(
                    hintText:
                        'Optional training context: energy, pain, technique, confidence, recovery.',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _finishSession,
              child: const Text('Finish & Save'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStep() {
    final _WorkoutSummary summary = _buildSummary();
    return SingleChildScrollView(
      key: const ValueKey<String>('summary'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _CoachPill(label: 'Session Review'),
          const SizedBox(height: 16),
          const Text(
            'Training Summary',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricCard(
                  eyebrow: 'Duration',
                  title: '${summary.durationMinutes} min',
                  body: 'Adjusted session time before saving.',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  eyebrow: 'Sets',
                  title: '${summary.completedSets}/${summary.totalSets}',
                  body: 'Completed sets ready to send to your coach.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricCard(
                  eyebrow: 'Reps',
                  title: '${summary.totalReps.round()}',
                  body: 'Total reps logged across completed sets.',
                ),
              ),
              if (summary.hasEstimatedVolume) ...<Widget>[
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    eyebrow: 'Volume',
                    title:
                        '${_formatVolumeValue(summary.estimatedVolume!)} ${summary.estimatedVolumeUnit}',
                    body:
                        'Estimated only from completed sets that include a tracked load unit.',
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('Coach Handoff'),
                const SizedBox(height: 12),
                Text(
                  _sessionSummaryNarrative(summary),
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: _textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Finish and save to generate the backend coach review for this session.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: _textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseEditor(int exerciseIndex) {
    final _WorkoutLogExerciseDraftState exercise = _exercises[exerciseIndex];
    final bool allSetsCompleted = exercise.sets.isNotEmpty &&
        exercise.sets.every((_WorkoutLogSetDraftState set) => set.completed);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _showExerciseExplanation(exerciseIndex),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      exercise.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _showExerciseExplanation(exerciseIndex),
                icon: const Icon(Icons.help_outline_rounded),
                color: _textMuted,
                visualDensity: VisualDensity.compact,
                tooltip: 'Why is this here?',
              ),
            ],
          ),
          if (exercise.notes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              exercise.notes,
              style: const TextStyle(
                fontSize: 13,
                color: _textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              const SizedBox(width: 36),
              const Spacer(),
              Checkbox(
                value: allSetsCompleted,
                activeColor: _accentGreen,
                checkColor: _bgTop,
                visualDensity: VisualDensity.compact,
                onChanged: (bool? value) {
                  final bool nextValue = value ?? false;
                  setState(() {
                    exercise.sets = exercise.sets
                        .map(
                          (_WorkoutLogSetDraftState set) =>
                              set.copyWith(completed: nextValue),
                        )
                        .toList();
                  });
                  _scheduleDraftPersist();
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (int setIndex = 0; setIndex < exercise.sets.length; setIndex++)
            Builder(
              builder: (BuildContext context) {
                final _WorkoutLogSetDraftState set = exercise.sets[setIndex];
                final bool showValueField = _showsNumericValueField(set.unit);
                final bool showLoadField =
                    _showsNumericValueField(set.loadUnit);
                final bool showRepsField = !showValueField ||
                    !_isStandalonePrimaryMeasurementUnit(set.unit) ||
                    set.reps.isNotEmpty;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 36,
                        child: Text(
                          'S${setIndex + 1}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _textMuted,
                          ),
                        ),
                      ),
                      if (showRepsField)
                        Expanded(
                          child: _WorkoutNumericInput(
                            label: 'Reps',
                            value: set.reps,
                            onTap: () => _editWorkoutField(
                              exerciseIndex: exerciseIndex,
                              setIndex: setIndex,
                              fieldKind: _WorkoutFieldKind.reps,
                              label: 'Reps',
                              initialValue: set.reps,
                            ),
                          ),
                        ),
                      if (showRepsField && showValueField)
                        const SizedBox(width: 8),
                      if (showValueField)
                        Expanded(
                          child: _WorkoutNumericInput(
                            label: set.unit,
                            value: set.value,
                            onTap: () => _editWorkoutField(
                              exerciseIndex: exerciseIndex,
                              setIndex: setIndex,
                              fieldKind: _WorkoutFieldKind.value,
                              label: set.unit,
                              initialValue: set.value,
                              allowFillRemaining: _isTrackedLoadUnit(
                                      set.unit) ||
                                  _isStandalonePrimaryMeasurementUnit(set.unit),
                            ),
                          ),
                        ),
                      if (showRepsField || showValueField)
                        const SizedBox(width: 8),
                      if (showLoadField)
                        Expanded(
                          child: _WorkoutNumericInput(
                            label: set.loadUnit,
                            value: set.loadValue,
                            onTap: () => _editWorkoutField(
                              exerciseIndex: exerciseIndex,
                              setIndex: setIndex,
                              fieldKind: _WorkoutFieldKind.loadValue,
                              label: set.loadUnit,
                              initialValue: set.loadValue,
                              allowFillRemaining: true,
                            ),
                          ),
                        ),
                      if (showLoadField) const SizedBox(width: 8),
                      Checkbox(
                        value: set.completed,
                        visualDensity: VisualDensity.compact,
                        onChanged: (bool? value) {
                          setState(() {
                            exercise.sets[setIndex] =
                                exercise.sets[setIndex].copyWith(
                              completed: value ?? false,
                            );
                          });
                          _scheduleDraftPersist();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const SizedBox(width: 8),
              _WorkoutSetCountButton(
                icon: Icons.remove_rounded,
                onTap: exercise.sets.length > 1
                    ? () {
                        setState(() {
                          exercise.sets.removeLast();
                        });
                        _scheduleDraftPersist();
                      }
                    : null,
              ),
              const Text(
                'Sets',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _textMuted,
                ),
              ),
              const SizedBox(width: 6),
              _WorkoutSetCountButton(
                icon: Icons.add_rounded,
                onTap: () {
                  final String nextUnit =
                      exercise.sets.isEmpty ? '' : exercise.sets.last.unit;
                  setState(() {
                    exercise.sets = <_WorkoutLogSetDraftState>[
                      ...exercise.sets,
                      _WorkoutLogSetDraftState(
                        reps: '',
                        value: '',
                        unit: nextUnit,
                        loadValue: '',
                        loadUnit: exercise.sets.isEmpty
                            ? ''
                            : exercise.sets.last.loadUnit,
                        completed: false,
                      ),
                    ];
                  });
                  _scheduleDraftPersist();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _animateStepTo(double target, {VoidCallback? onCompleted}) {
    _stepAnimationController.stop();
    final double start = _stepOffset;
    _stepOffsetAnimation = Tween<double>(
      begin: start,
      end: target,
    ).animate(
      CurvedAnimation(
        parent: _stepAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
    _stepAnimationController
      ..reset()
      ..forward().whenCompleteOrCancel(() {
        onCompleted?.call();
      });
  }

  void _animateStepBack() {
    _animateStepTo(0, onCompleted: () {
      if (!mounted) {
        return;
      }
      setState(() {
        _stepOffset = 0;
      });
    });
  }

  void _handleStepDragEnd({
    required double viewportWidth,
    required double velocity,
    required double distance,
  }) {
    final bool canMovePrevious = _currentStep > 0;
    final bool canMoveNext = _currentStep < _totalSteps - 1;
    final double threshold = math.max(56, viewportWidth * 0.22);

    if ((velocity > 250 || distance > threshold) && canMovePrevious) {
      _animateStepTo(viewportWidth, onCompleted: () {
        if (!mounted) {
          return;
        }
        setState(() {
          _currentStep--;
          _stepOffset = 0;
        });
        _scheduleDraftPersist();
      });
      return;
    }

    if ((velocity < -250 || distance < -threshold) && canMoveNext) {
      _animateStepTo(-viewportWidth, onCompleted: () {
        if (!mounted) {
          return;
        }
        setState(() {
          _currentStep++;
          _stepOffset = 0;
        });
        _scheduleDraftPersist();
      });
      return;
    }

    _animateStepBack();
  }

  Future<void> _editWorkoutField({
    required int exerciseIndex,
    required int setIndex,
    required _WorkoutFieldKind fieldKind,
    required String label,
    required String initialValue,
    bool allowFillRemaining = false,
  }) async {
    final _WorkoutFieldEditResult? result =
        await showModalBottomSheet<_WorkoutFieldEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _WorkoutFieldKeyboardSheet(
          title: _exercises[exerciseIndex].title,
          label: label,
          initialValue: initialValue,
          allowFillRemaining: allowFillRemaining,
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      final List<_WorkoutLogSetDraftState> updatedSets =
          List<_WorkoutLogSetDraftState>.from(_exercises[exerciseIndex].sets);
      final int endIndex =
          result.fillRemaining ? updatedSets.length - 1 : setIndex;
      for (int index = setIndex; index <= endIndex; index++) {
        final _WorkoutLogSetDraftState current = updatedSets[index];
        switch (fieldKind) {
          case _WorkoutFieldKind.reps:
            updatedSets[index] = current.copyWith(reps: result.value);
            break;
          case _WorkoutFieldKind.value:
            updatedSets[index] = current.copyWith(value: result.value);
            break;
          case _WorkoutFieldKind.loadValue:
            updatedSets[index] = current.copyWith(loadValue: result.value);
            break;
        }
      }
      _exercises[exerciseIndex].sets = updatedSets;
    });
    _scheduleDraftPersist();
  }

  void _finishSession() {
    final String sanitizedNote =
        _sanitizeAthleteNote(_sessionNotesController.text.trim());
    if (sanitizedNote != _sessionNotesController.text.trim()) {
      _sessionNotesController.value = TextEditingValue(
        text: sanitizedNote,
        selection: TextSelection.collapsed(offset: sanitizedNote.length),
      );
    }

    final _WorkoutLogDraft draft = _buildDraft();
    _draftPersistDebounce?.cancel();
    Navigator.of(context).pop(draft);
  }

  String _exerciseGuidance(String title) {
    final String lower = title.toLowerCase();
    if (lower.contains('squat')) {
      return 'Own your brace, descend with control, and do not chase ugly reps.';
    }
    if (lower.contains('deadlift') || lower.contains('hinge')) {
      return 'Keep your hinge crisp and stop when position starts to leak.';
    }
    if (lower.contains('press')) {
      return 'Move the bar with intent, but leave room for the rest of the session.';
    }
    if (lower.contains('row') || lower.contains('pulldown')) {
      return 'Treat this as quality upper-back work, not momentum work.';
    }
    return 'Move well, log honestly, and keep this exercise connected to the purpose of the day.';
  }

  Future<void> _showExerciseExplanation(int exerciseIndex) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return FutureBuilder<_PlannedExerciseExplanationResponse>(
          future: _loadPlannedExerciseExplanation(exerciseIndex),
          builder: (
            BuildContext context,
            AsyncSnapshot<_PlannedExerciseExplanationResponse> snapshot,
          ) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _ExerciseExplanationLoadingSheet();
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return _ExerciseExplanationErrorSheet(
                message: snapshot.error is _UiException
                    ? (snapshot.error as _UiException).message
                    : 'Could not load the coach explanation for this exercise.',
              );
            }

            final _PlannedExerciseExplanationResponse explanation =
                snapshot.data!;
            return _ExerciseExplanationSheet(
              title: explanation.exerciseTitle,
              reason: explanation.reason,
              support: explanation.support,
              execution: explanation.execution,
              movementPattern: explanation.movementPattern,
            );
          },
        );
      },
    );
  }

  Future<_PlannedExerciseExplanationResponse> _loadPlannedExerciseExplanation(
    int exerciseIndex,
  ) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const _UiException('Sign in again to load coach explanations.');
    }

    final String? token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw const _UiException(
          'Could not verify your session for the coach explanation.');
    }

    final Uri uri = _buildPlannedExerciseExplanationUri(widget.plan.planID);
    final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: <String, String>{
              HttpHeaders.authorizationHeader: 'Bearer $token',
              HttpHeaders.contentTypeHeader: 'application/json',
            },
            body: jsonEncode(<String, int>{
              'week_number': widget.workout.weekNumber,
              'day_number': widget.workout.dayNumber,
              'exercise_index': exerciseIndex,
            }),
          )
          .timeout(_backendRequestTimeout);
    } on SocketException {
      throw const _UiException(
        'Could not reach the backend for this explanation. Check your connection and try again.',
      );
    } on TimeoutException {
      throw const _UiException(
        'The coach explanation took too long to load. Please try again.',
      );
    } on http.ClientException {
      throw const _UiException(
        'The app could not load the coach explanation right now.',
      );
    }

    if (response.statusCode >= 400) {
      throw _UiException(
        _extractBackendErrorMessage(response.body) ??
            'Could not load the coach explanation for this exercise.',
      );
    }

    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const _UiException(
        'The backend returned an invalid exercise explanation.',
      );
    }

    return _PlannedExerciseExplanationResponse.fromJson(decoded);
  }

  Uri _buildPlannedExerciseExplanationUri(int trainingPlanID) {
    final Uri baseUri = AppBackend.trainingPlans();
    final String normalizedPath = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;

    return baseUri.replace(
      path: '$normalizedPath/$trainingPlanID/exercise-explanation',
    );
  }

  String? _extractBackendErrorMessage(String body) {
    final String trimmed = body.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    try {
      final Object? decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        final Object? error = decoded['error'];
        if (error is String && error.trim().isNotEmpty) {
          return error.trim();
        }
      }
    } catch (_) {
      // Ignore parsing failure and fall through.
    }

    return trimmed.length <= 180 ? trimmed : null;
  }

  bool _showsNumericValueField(String unit) {
    const Set<String> numericUnits = <String>{
      'kg',
      'lb',
      'sec',
      's',
      'min',
      'm',
      'meter',
      'meters',
    };

    return numericUnits.contains(unit.trim().toLowerCase());
  }

  bool _isDurationUnit(String unit) {
    const Set<String> durationUnits = <String>{'sec', 's', 'min'};
    return durationUnits.contains(unit.trim().toLowerCase());
  }

  bool _isDistanceUnit(String unit) {
    const Set<String> distanceUnits = <String>{'m', 'meter', 'meters'};
    return distanceUnits.contains(unit.trim().toLowerCase());
  }

  bool _isTrackedLoadUnit(String unit) {
    const Set<String> loadUnits = <String>{
      'kg',
      'kilogram',
      'kilograms',
      'lb',
      'lbs',
      'pound',
      'pounds',
    };
    return loadUnits.contains(unit.trim().toLowerCase());
  }

  bool _isStandalonePrimaryMeasurementUnit(String unit) {
    return _isDurationUnit(unit) || _isDistanceUnit(unit);
  }

  void _appendLoggedTrackedVolumeFromDraft(
    Map<String, double> target,
    _WorkoutLogSetDraftState set,
  ) {
    if (!set.completed) {
      return;
    }

    double? value;
    String unit = '';

    final double? parsedLoadValue = double.tryParse(set.loadValue.trim());
    final double? parsedPrimaryValue = double.tryParse(set.value.trim());

    if (_isTrackedLoadUnit(set.loadUnit) &&
        parsedLoadValue != null &&
        parsedLoadValue > 0) {
      value = parsedLoadValue;
      unit = set.loadUnit.trim();
    } else if (_isTrackedLoadUnit(set.unit) &&
        parsedPrimaryValue != null &&
        parsedPrimaryValue > 0) {
      value = parsedPrimaryValue;
      unit = set.unit.trim();
    }

    if (value == null || unit.isEmpty) {
      return;
    }

    final double reps = double.tryParse(set.reps.trim()) ?? 0;
    final double multiplier = reps > 0 ? reps : 1;
    target[unit] = (target[unit] ?? 0) + (multiplier * value);
  }

  String _formatElapsedMinutesOnly(int minutes) {
    final int safeMinutes = math.max(0, minutes);
    return safeMinutes == 1 ? '1 minute' : '$safeMinutes minutes';
  }

  void _adjustElapsedMinutes(int deltaMinutes) {
    _syncElapsedMinutes(_elapsed.inMinutes + deltaMinutes);
  }

  int get _effectiveDurationMinutes {
    if (_hasManualDurationOverride) {
      return int.tryParse(_durationController.text.trim()) ??
          _elapsed.inMinutes;
    }
    return _elapsed.inMinutes;
  }

  void _syncElapsedMinutes(int minutes) {
    final int safeMinutes = math.max(0, minutes);
    setState(() {
      _hasManualDurationOverride = true;
      _startedAt = DateTime.now().subtract(Duration(minutes: safeMinutes));
      _elapsed = Duration(minutes: safeMinutes);
      _durationController.text = '$safeMinutes';
    });
    _scheduleDraftPersist();
  }

  Future<void> _editElapsedMinutes() async {
    final int? minutes = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return _IntegerInputDialog(
          title: 'Adjust elapsed time',
          labelText: 'Minutes',
          initialValue: _elapsed.inMinutes,
          confirmLabel: 'Apply',
        );
      },
    );

    if (minutes == null) {
      return;
    }
    _syncElapsedMinutes(minutes);
  }

  _ParsedSessionFeedback _parseSessionFeedback(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const _ParsedSessionFeedback(feelIndex: 1, note: '');
    }

    final RegExp prefixedPattern = RegExp(
      r'^Session feel:\s*(Easy|Good|Hard|Brutal)\.?(?:\s*Athlete note:\s*(.*))?$',
      caseSensitive: false,
      dotAll: true,
    );
    final Match? prefixedMatch = prefixedPattern.firstMatch(trimmed);
    if (prefixedMatch == null) {
      return _ParsedSessionFeedback(
        feelIndex: 1,
        note: trimmed,
      );
    }

    final String feelLabel =
        _normalizeFeelLabel(prefixedMatch.group(1) ?? 'Good');
    final String note = (prefixedMatch.group(2) ?? '').trim();

    return _ParsedSessionFeedback(
      feelIndex: _sessionFeelLabels.indexOf(feelLabel),
      note: note,
    );
  }

  String _normalizeFeelLabel(String raw) {
    final String lower = raw.trim().toLowerCase();
    for (final String label in _sessionFeelLabels) {
      if (label.toLowerCase() == lower) {
        return label;
      }
    }
    return 'Good';
  }

  String _sanitizeAthleteNote(String raw) {
    String sanitized = raw
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (sanitized.isEmpty) {
      return '';
    }

    if (sanitized.length > 280) {
      sanitized = sanitized.substring(0, 280).trim();
    }

    final String lower = sanitized.toLowerCase();
    const List<String> suspiciousFragments = <String>[
      'write me',
      'python script',
      'javascript',
      'shell script',
      'sql query',
      'ignore previous',
      'system prompt',
      'print(',
      'import os',
      'curl ',
      'bash ',
    ];
    const List<String> trainingFragments = <String>[
      'felt',
      'back',
      'knee',
      'hip',
      'elbow',
      'shoulder',
      'fatigue',
      'tired',
      'pain',
      'energy',
      'technique',
      'form',
      'squat',
      'bench',
      'deadlift',
      'press',
      'row',
      'recovery',
      'sleep',
      'easy',
      'hard',
      'heavy',
    ];

    final bool looksSuspicious = suspiciousFragments.any(lower.contains);
    final bool looksTrainingRelated = trainingFragments.any(lower.contains);
    if (looksSuspicious && !looksTrainingRelated) {
      return '';
    }

    return sanitized;
  }

  String _composeSessionNotes() {
    final String feel = _sessionFeelLabels[_sessionFeelIndex];
    final String sanitizedNote =
        _sanitizeAthleteNote(_sessionNotesController.text.trim());
    if (sanitizedNote.isEmpty) {
      return 'Session feel: $feel.';
    }
    return 'Session feel: $feel. Athlete note: $sanitizedNote';
  }

  _WorkoutSummary _buildSummary() {
    int totalSets = 0;
    int completedSets = 0;
    double totalReps = 0;
    final Map<String, double> estimatedVolumeByUnit = <String, double>{};

    for (final _WorkoutLogExerciseDraftState exercise in _exercises) {
      for (final _WorkoutLogSetDraftState set in exercise.sets) {
        totalSets++;
        if (set.completed) {
          completedSets++;
        }

        final double? reps = double.tryParse(set.reps.trim());
        if (set.completed && reps != null) {
          totalReps += reps;
        }
        _appendLoggedTrackedVolumeFromDraft(estimatedVolumeByUnit, set);
      }
    }

    double? estimatedVolume;
    String estimatedVolumeUnit = '';
    if (estimatedVolumeByUnit.length == 1) {
      estimatedVolumeUnit = estimatedVolumeByUnit.keys.first;
      estimatedVolume = estimatedVolumeByUnit[estimatedVolumeUnit];
    }

    return _WorkoutSummary(
      durationMinutes: _effectiveDurationMinutes,
      totalSets: totalSets,
      completedSets: completedSets,
      totalReps: totalReps,
      estimatedVolume: estimatedVolume,
      estimatedVolumeUnit: estimatedVolumeUnit,
      athleteFeedback: _composeSessionNotes(),
    );
  }

  String _sessionSummaryNarrative(_WorkoutSummary summary) {
    final List<String> sentences = <String>[
      'You logged ${summary.completedSets} completed sets out of ${summary.totalSets} total and recorded ${summary.totalReps.round()} reps for the session.',
      if (summary.hasEstimatedVolume)
        'Completed tracked volume landed around ${_formatVolumeValue(summary.estimatedVolume!)} ${summary.estimatedVolumeUnit}.',
      if (summary.athleteFeedback.isNotEmpty)
        'Your athlete note is ready to be folded into the coach review after save.',
    ];

    return sentences.join(' ');
  }

  _WorkoutLogDraft _buildDraft() {
    return _WorkoutLogDraft(
      trainingPlanID: widget.plan.planID,
      weekNumber: widget.workout.weekNumber,
      dayNumber: widget.workout.dayNumber,
      title: widget.workout.title,
      focus: widget.workout.focus,
      sessionNotes: _composeSessionNotes(),
      durationMinutes: _effectiveDurationMinutes,
      exercises: _exercises.map((_WorkoutLogExerciseDraftState exercise) {
        return _WorkoutLogDraftExercise(
          title: exercise.title,
          notes: exercise.notes,
          sets: exercise.sets.map((_WorkoutLogSetDraftState set) {
            return _WorkoutLogDraftSet(
              reps: double.tryParse(set.reps.trim()),
              value: double.tryParse(set.value.trim()),
              unit: set.unit,
              loadValue: double.tryParse(set.loadValue.trim()),
              loadUnit: set.loadUnit,
              completed: set.completed,
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  _WorkoutSessionDraftSnapshot _buildDraftSnapshot() {
    return _WorkoutSessionDraftSnapshot(
      trainingPlanID: widget.plan.planID,
      weekNumber: widget.workout.weekNumber,
      dayNumber: widget.workout.dayNumber,
      title: widget.workout.title,
      focus: widget.workout.focus,
      sessionNotes: _composeSessionNotes(),
      durationMinutes: _effectiveDurationMinutes,
      currentStep: _currentStep,
      sessionFeelIndex: _sessionFeelIndex,
      exercises: _exercises.map((_WorkoutLogExerciseDraftState exercise) {
        return _WorkoutLogDraftExercise(
          title: exercise.title,
          notes: exercise.notes,
          sets: exercise.sets.map((_WorkoutLogSetDraftState set) {
            return _WorkoutLogDraftSet(
              reps: double.tryParse(set.reps.trim()),
              value: double.tryParse(set.value.trim()),
              unit: set.unit,
              loadValue: double.tryParse(set.loadValue.trim()),
              loadUnit: set.loadUnit,
              completed: set.completed,
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  void _scheduleDraftPersist() {
    _draftPersistDebounce?.cancel();
    _draftPersistDebounce =
        Timer(const Duration(milliseconds: 350), _persistDraftImmediately);
  }

  Future<void> _persistDraftImmediately() async {
    final String? firebaseUid = widget.firebaseUid;
    if (firebaseUid == null || firebaseUid.isEmpty) {
      return;
    }

    final _WorkoutSessionDraftSnapshot snapshot = _buildDraftSnapshot();
    if (!_hasPersistableDraftProgress(snapshot)) {
      await widget.localCacheRepository.clearWorkoutSessionDraft(
        firebaseUid: firebaseUid,
        trainingPlanId: snapshot.trainingPlanID,
        weekNumber: snapshot.weekNumber,
        dayNumber: snapshot.dayNumber,
      );
      return;
    }

    await widget.localCacheRepository.saveWorkoutSessionDraft(
      firebaseUid: firebaseUid,
      trainingPlanId: snapshot.trainingPlanID,
      weekNumber: snapshot.weekNumber,
      dayNumber: snapshot.dayNumber,
      payloadJson: jsonEncode(snapshot.toJson()),
    );
  }

  bool _hasPersistableDraftProgress(_WorkoutSessionDraftSnapshot snapshot) {
    for (final _WorkoutLogDraftExercise exercise in snapshot.exercises) {
      for (final _WorkoutLogDraftSet set in exercise.sets) {
        if (set.completed) {
          return true;
        }
      }
    }
    return false;
  }
}

class _WorkoutSessionProgress extends StatelessWidget {
  const _WorkoutSessionProgress({
    required this.step,
    required this.totalSteps,
  });

  final int step;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final double progress = totalSteps <= 0 ? 0 : step / totalSteps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Step $step of $totalSteps',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _textMuted,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 8,
            backgroundColor: _surfaceRaised,
            valueColor: const AlwaysStoppedAnimation<Color>(_accentGreen),
          ),
        ),
      ],
    );
  }
}

class _SessionFeelSelector extends StatelessWidget {
  const _SessionFeelSelector({
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final int safeIndex = selectedIndex.clamp(0, labels.length - 1);
    final String selectedLabel = labels[safeIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: _surfaceRaised,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _outline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                _sessionFeelIcon(selectedLabel),
                size: 18,
                color: _textPrimary,
              ),
              const SizedBox(width: 8),
              Text(
                selectedLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _accentGreen,
            inactiveTrackColor: _surfaceRaised,
            thumbColor: _textPrimary,
            overlayColor: _accentGreen.withValues(alpha: 0.16),
            trackHeight: 8,
          ),
          child: Slider(
            value: safeIndex.toDouble(),
            min: 0,
            max: (labels.length - 1).toDouble(),
            divisions: labels.length - 1,
            onChanged: (double value) => onChanged(value.round()),
          ),
        ),
        Row(
          children: labels
              .asMap()
              .entries
              .map(
                (MapEntry<int, String> entry) => Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(entry.key),
                    child: Text(
                      entry.value,
                      textAlign: entry.key == 0
                          ? TextAlign.left
                          : entry.key == labels.length - 1
                              ? TextAlign.right
                              : TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: entry.key == safeIndex
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color:
                            entry.key == safeIndex ? _textPrimary : _textMuted,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  IconData _sessionFeelIcon(String feelLabel) {
    switch (feelLabel.trim().toLowerCase()) {
      case 'easy':
        return Icons.sentiment_satisfied_alt_rounded;
      case 'good':
        return Icons.check_circle_rounded;
      case 'hard':
        return Icons.fitness_center_rounded;
      case 'brutal':
        return Icons.local_fire_department_rounded;
      default:
        return Icons.bolt_rounded;
    }
  }
}

class _WorkoutExerciseScreenGroup {
  const _WorkoutExerciseScreenGroup({
    required this.title,
    required this.indices,
    required this.isSuperset,
  });

  final String title;
  final List<int> indices;
  final bool isSuperset;
}

class _WorkoutSummary {
  const _WorkoutSummary({
    required this.durationMinutes,
    required this.totalSets,
    required this.completedSets,
    required this.totalReps,
    required this.estimatedVolume,
    required this.estimatedVolumeUnit,
    required this.athleteFeedback,
  });

  final int durationMinutes;
  final int totalSets;
  final int completedSets;
  final double totalReps;
  final double? estimatedVolume;
  final String estimatedVolumeUnit;
  final String athleteFeedback;

  bool get hasEstimatedVolume =>
      estimatedVolume != null &&
      estimatedVolume! > 0 &&
      estimatedVolumeUnit.isNotEmpty;
}

class _WeeklyTrainingStats {
  const _WeeklyTrainingStats({
    required this.totalReps,
    required this.targetReps,
    required this.totalVolume,
    required this.targetVolume,
    required this.volumeLabel,
    required this.volumeProgress,
  });

  final int totalReps;
  final int targetReps;
  final int? totalVolume;
  final int? targetVolume;
  final String volumeLabel;
  final double volumeProgress;
}

class _ParsedSessionFeedback {
  const _ParsedSessionFeedback({
    required this.feelIndex,
    required this.note,
  });

  final int feelIndex;
  final String note;
}

class _NormalizedUnitValue {
  const _NormalizedUnitValue({
    required this.value,
    required this.unit,
  });

  final double? value;
  final String unit;
}

class _WorkoutLogExerciseDraftState {
  _WorkoutLogExerciseDraftState({
    required this.title,
    required this.notes,
    required this.sets,
  });

  final String title;
  final String notes;
  List<_WorkoutLogSetDraftState> sets;
}

class _WorkoutLogSetDraftState {
  const _WorkoutLogSetDraftState({
    required this.reps,
    required this.value,
    required this.unit,
    required this.loadValue,
    required this.loadUnit,
    required this.completed,
  });

  final String reps;
  final String value;
  final String unit;
  final String loadValue;
  final String loadUnit;
  final bool completed;

  _WorkoutLogSetDraftState copyWith({
    String? reps,
    String? value,
    String? unit,
    String? loadValue,
    String? loadUnit,
    bool? completed,
  }) {
    return _WorkoutLogSetDraftState(
      reps: reps ?? this.reps,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      loadValue: loadValue ?? this.loadValue,
      loadUnit: loadUnit ?? this.loadUnit,
      completed: completed ?? this.completed,
    );
  }
}

class _WorkoutLogItem {
  const _WorkoutLogItem({
    required this.id,
    required this.trainingPlanID,
    required this.weekNumber,
    required this.dayNumber,
    required this.title,
    required this.focus,
    required this.sessionNotes,
    required this.durationMinutes,
    required this.exerciseCount,
    required this.setCount,
    required this.completedSetCount,
    required this.totalReps,
    required this.estimatedVolume,
    required this.estimatedVolumeUnit,
    required this.exercises,
    required this.review,
  });

  factory _WorkoutLogItem.fromJson(Map<String, dynamic> json) {
    final Object? exercisesValue = json['exercises'];
    final List<_WorkoutLogExerciseItem> exercises =
        exercisesValue is List<dynamic>
            ? exercisesValue
                .whereType<Map<String, dynamic>>()
                .map(_WorkoutLogExerciseItem.fromJson)
                .toList()
            : <_WorkoutLogExerciseItem>[];
    final Object? reviewValue = json['review'];

    return _WorkoutLogItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      trainingPlanID: (json['training_plan_id'] as num?)?.toInt() ?? 0,
      weekNumber: (json['week_number'] as num?)?.toInt() ?? 0,
      dayNumber: (json['day_number'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String?) ?? 'Workout',
      focus: (json['focus'] as String?) ?? '',
      sessionNotes: (json['session_notes'] as String?) ?? '',
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      exerciseCount: (json['exercise_count'] as num?)?.toInt() ?? 0,
      setCount: (json['set_count'] as num?)?.toInt() ?? 0,
      completedSetCount: (json['completed_set_count'] as num?)?.toInt() ?? 0,
      totalReps: (json['total_reps'] as num?)?.toDouble() ?? 0,
      estimatedVolume: (json['estimated_volume'] as num?)?.toDouble(),
      estimatedVolumeUnit: (json['estimated_volume_unit'] as String?) ?? '',
      exercises: exercises,
      review: reviewValue is Map<String, dynamic>
          ? _WorkoutLogReviewItem.fromJson(reviewValue)
          : null,
    );
  }

  final int id;
  final int trainingPlanID;
  final int weekNumber;
  final int dayNumber;
  final String title;
  final String focus;
  final String sessionNotes;
  final int? durationMinutes;
  final int exerciseCount;
  final int setCount;
  final int completedSetCount;
  final double totalReps;
  final double? estimatedVolume;
  final String estimatedVolumeUnit;
  final List<_WorkoutLogExerciseItem> exercises;
  final _WorkoutLogReviewItem? review;

  bool get hasEstimatedVolume =>
      estimatedVolume != null &&
      estimatedVolume! > 0 &&
      estimatedVolumeUnit.isNotEmpty;
}

class _WorkoutLogReviewItem {
  const _WorkoutLogReviewItem({
    required this.provider,
    required this.model,
    required this.promptVersion,
    required this.review,
    required this.generated,
  });

  factory _WorkoutLogReviewItem.fromJson(Map<String, dynamic> json) {
    return _WorkoutLogReviewItem(
      provider: (json['provider'] as String?) ?? '',
      model: (json['model'] as String?) ?? '',
      promptVersion: (json['prompt_version'] as String?) ?? '',
      review: (json['review'] as String?) ?? '',
      generated: json['generated'] as bool? ?? false,
    );
  }

  final String provider;
  final String model;
  final String promptVersion;
  final String review;
  final bool generated;
}

class _WorkoutSessionDraftSummary {
  const _WorkoutSessionDraftSummary({
    required this.trainingPlanID,
    required this.weekNumber,
    required this.dayNumber,
    required this.title,
    required this.focus,
    required this.durationMinutes,
    required this.currentStep,
    required this.sessionFeelIndex,
    required this.setCount,
    required this.completedSetCount,
    required this.totalReps,
    required this.estimatedVolume,
    required this.estimatedVolumeUnit,
    required this.updatedAt,
  });

  final int trainingPlanID;
  final int weekNumber;
  final int dayNumber;
  final String title;
  final String focus;
  final int? durationMinutes;
  final int currentStep;
  final int sessionFeelIndex;
  final int setCount;
  final int completedSetCount;
  final double totalReps;
  final double? estimatedVolume;
  final String estimatedVolumeUnit;
  final DateTime updatedAt;

  bool get hasEstimatedVolume =>
      estimatedVolume != null &&
      estimatedVolume! > 0 &&
      estimatedVolumeUnit.isNotEmpty;
}

class _BackendUserProfile {
  const _BackendUserProfile({
    required this.id,
    required this.firebaseUID,
    required this.email,
    required this.displayName,
    required this.trainingExperience,
    required this.primaryGoal,
    required this.preferredDays,
    required this.redeemedPromoCode,
    required this.aiAccessEnabled,
  });

  factory _BackendUserProfile.fromJson(Map<String, dynamic> json) {
    final Object? preferredDaysValue = json['preferred_days'];
    return _BackendUserProfile(
      id: (json['id'] as String?) ?? '',
      firebaseUID: (json['firebase_uid'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      displayName: (json['display_name'] as String?) ?? '',
      trainingExperience: (json['training_experience'] as String?) ?? '',
      primaryGoal: (json['primary_goal'] as String?) ?? '',
      preferredDays: preferredDaysValue is List<dynamic>
          ? preferredDaysValue.whereType<String>().toList(growable: false)
          : const <String>[],
      redeemedPromoCode: (json['redeemed_promo_code'] as String?) ?? '',
      aiAccessEnabled: json['ai_access_enabled'] as bool? ?? false,
    );
  }

  final String id;
  final String firebaseUID;
  final String email;
  final String displayName;
  final String trainingExperience;
  final String primaryGoal;
  final List<String> preferredDays;
  final String redeemedPromoCode;
  final bool aiAccessEnabled;
}

class _WorkoutReviewDetails {
  const _WorkoutReviewDetails({
    required this.setCount,
    required this.completedSetCount,
    required this.totalReps,
    required this.estimatedVolume,
    required this.estimatedVolumeUnit,
    required this.parsedFeedback,
  });

  final int setCount;
  final int completedSetCount;
  final double totalReps;
  final double? estimatedVolume;
  final String estimatedVolumeUnit;
  final _ParsedSessionFeedback parsedFeedback;

  bool get hasEstimatedVolume =>
      estimatedVolume != null &&
      estimatedVolume! > 0 &&
      estimatedVolumeUnit.isNotEmpty;

  String get feelLabel {
    final int safeIndex =
        parsedFeedback.feelIndex.clamp(0, _storedSessionFeelLabels.length - 1);
    return _storedSessionFeelLabels[safeIndex];
  }
}

class _WorkoutLogExerciseItem {
  const _WorkoutLogExerciseItem({
    required this.sequenceNumber,
    required this.title,
    required this.notes,
    required this.sets,
  });

  factory _WorkoutLogExerciseItem.fromJson(Map<String, dynamic> json) {
    final Object? setsValue = json['sets'];
    final List<_WorkoutLogSetItem> sets = setsValue is List<dynamic>
        ? setsValue
            .whereType<Map<String, dynamic>>()
            .map(_WorkoutLogSetItem.fromJson)
            .toList()
        : <_WorkoutLogSetItem>[];

    return _WorkoutLogExerciseItem(
      sequenceNumber: (json['sequence_number'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String?) ?? 'Exercise',
      notes: (json['notes'] as String?) ?? '',
      sets: sets,
    );
  }

  final int sequenceNumber;
  final String title;
  final String notes;
  final List<_WorkoutLogSetItem> sets;
}

class _WorkoutLogSetItem {
  const _WorkoutLogSetItem({
    required this.sequenceNumber,
    required this.reps,
    required this.value,
    required this.unit,
    required this.loadValue,
    required this.loadUnit,
    required this.completed,
  });

  factory _WorkoutLogSetItem.fromJson(Map<String, dynamic> json) {
    final double? loadValue = (json['load_value'] as num?)?.toDouble();
    final String loadUnit = (json['load_unit'] as String?) ?? '';
    return _WorkoutLogSetItem(
      sequenceNumber: (json['sequence_number'] as num?)?.toInt() ?? 0,
      reps: (json['reps'] as num?)?.toDouble(),
      value: (json['value'] as num?)?.toDouble(),
      unit: (json['unit'] as String?) ?? '',
      loadValue: loadValue,
      loadUnit: loadUnit,
      completed: json['completed'] as bool? ?? false,
    );
  }

  final int sequenceNumber;
  final double? reps;
  final double? value;
  final String unit;
  final double? loadValue;
  final String loadUnit;
  final bool completed;
}

class _WorkoutLogDraft {
  const _WorkoutLogDraft({
    required this.trainingPlanID,
    required this.weekNumber,
    required this.dayNumber,
    required this.title,
    required this.focus,
    required this.sessionNotes,
    required this.durationMinutes,
    required this.exercises,
  });

  final int trainingPlanID;
  final int weekNumber;
  final int dayNumber;
  final String title;
  final String focus;
  final String sessionNotes;
  final int? durationMinutes;
  final List<_WorkoutLogDraftExercise> exercises;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'training_plan_id': trainingPlanID,
      'week_number': weekNumber,
      'day_number': dayNumber,
      'title': title,
      'focus': focus,
      'session_notes': sessionNotes,
      'duration_minutes': durationMinutes,
      'performed_at': DateTime.now().toUtc().toIso8601String(),
      'exercises': exercises.map((_WorkoutLogDraftExercise exercise) {
        return <String, Object?>{
          'title': exercise.title,
          'notes': exercise.notes,
          'sets': exercise.sets.map((_WorkoutLogDraftSet set) {
            return <String, Object?>{
              'reps': set.reps,
              'value': set.value,
              'unit': set.unit,
              'load_value': set.loadValue,
              'load_unit': set.loadUnit,
              'completed': set.completed,
            };
          }).toList(),
        };
      }).toList(),
    };
  }
}

class _WorkoutSessionDraftSnapshot {
  const _WorkoutSessionDraftSnapshot({
    required this.trainingPlanID,
    required this.weekNumber,
    required this.dayNumber,
    required this.title,
    required this.focus,
    required this.sessionNotes,
    required this.durationMinutes,
    required this.currentStep,
    required this.sessionFeelIndex,
    required this.exercises,
  });

  factory _WorkoutSessionDraftSnapshot.fromJson(Map<String, dynamic> json) {
    final Object? exercisesValue = json['exercises'];
    final List<_WorkoutLogDraftExercise> exercises = exercisesValue is List
        ? exercisesValue
            .whereType<Map<String, dynamic>>()
            .map((_WorkoutLogDraftExercise.fromJson))
            .toList(growable: false)
        : const <_WorkoutLogDraftExercise>[];

    return _WorkoutSessionDraftSnapshot(
      trainingPlanID: (json['training_plan_id'] as num?)?.toInt() ?? 0,
      weekNumber: (json['week_number'] as num?)?.toInt() ?? 0,
      dayNumber: (json['day_number'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String?) ?? '',
      focus: (json['focus'] as String?) ?? '',
      sessionNotes: (json['session_notes'] as String?) ?? '',
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      currentStep: (json['current_step'] as num?)?.toInt() ?? 0,
      sessionFeelIndex: (json['session_feel_index'] as num?)?.toInt() ?? 1,
      exercises: exercises,
    );
  }

  final int trainingPlanID;
  final int weekNumber;
  final int dayNumber;
  final String title;
  final String focus;
  final String sessionNotes;
  final int? durationMinutes;
  final int currentStep;
  final int sessionFeelIndex;
  final List<_WorkoutLogDraftExercise> exercises;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'training_plan_id': trainingPlanID,
      'week_number': weekNumber,
      'day_number': dayNumber,
      'title': title,
      'focus': focus,
      'session_notes': sessionNotes,
      'duration_minutes': durationMinutes,
      'current_step': currentStep,
      'session_feel_index': sessionFeelIndex,
      'exercises': exercises
          .map((_WorkoutLogDraftExercise exercise) => exercise.toJson())
          .toList(growable: false),
    };
  }
}

class _WorkoutLogDraftExercise {
  const _WorkoutLogDraftExercise({
    required this.title,
    required this.notes,
    required this.sets,
  });

  factory _WorkoutLogDraftExercise.fromJson(Map<String, dynamic> json) {
    final Object? setsValue = json['sets'];
    final List<_WorkoutLogDraftSet> sets = setsValue is List
        ? setsValue
            .whereType<Map<String, dynamic>>()
            .map((_WorkoutLogDraftSet.fromJson))
            .toList(growable: false)
        : const <_WorkoutLogDraftSet>[];

    return _WorkoutLogDraftExercise(
      title: (json['title'] as String?) ?? '',
      notes: (json['notes'] as String?) ?? '',
      sets: sets,
    );
  }

  final String title;
  final String notes;
  final List<_WorkoutLogDraftSet> sets;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'title': title,
      'notes': notes,
      'sets': sets.map((_WorkoutLogDraftSet set) => set.toJson()).toList(),
    };
  }
}

class _WorkoutLogDraftSet {
  const _WorkoutLogDraftSet({
    required this.reps,
    required this.value,
    required this.unit,
    required this.loadValue,
    required this.loadUnit,
    required this.completed,
  });

  factory _WorkoutLogDraftSet.fromJson(Map<String, dynamic> json) {
    return _WorkoutLogDraftSet(
      reps: (json['reps'] as num?)?.toDouble(),
      value: (json['value'] as num?)?.toDouble(),
      unit: (json['unit'] as String?) ?? '',
      loadValue: (json['load_value'] as num?)?.toDouble(),
      loadUnit: (json['load_unit'] as String?) ?? '',
      completed: (json['completed'] as bool?) ?? false,
    );
  }

  final double? reps;
  final double? value;
  final String unit;
  final double? loadValue;
  final String loadUnit;
  final bool completed;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'reps': reps,
      'value': value,
      'unit': unit,
      'load_value': loadValue,
      'load_unit': loadUnit,
      'completed': completed,
    };
  }
}

class _WorkoutFieldEditResult {
  const _WorkoutFieldEditResult({
    required this.value,
    required this.fillRemaining,
  });

  final String value;
  final bool fillRemaining;
}

class _WorkoutNumericInput extends StatelessWidget {
  const _WorkoutNumericInput({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String displayValue = value.trim().isEmpty ? '0' : value.trim();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: _surfaceRaised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _outlineSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label.isEmpty ? 'Value' : label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              displayValue,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: value.trim().isEmpty ? _textMuted : _textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutFieldKeyboardSheet extends StatefulWidget {
  const _WorkoutFieldKeyboardSheet({
    required this.title,
    required this.label,
    required this.initialValue,
    required this.allowFillRemaining,
  });

  final String title;
  final String label;
  final String initialValue;
  final bool allowFillRemaining;

  @override
  State<_WorkoutFieldKeyboardSheet> createState() =>
      _WorkoutFieldKeyboardSheetState();
}

class _WorkoutFieldKeyboardSheetState
    extends State<_WorkoutFieldKeyboardSheet> {
  late String _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue.trim();
  }

  void _append(String token) {
    setState(() {
      if (token == '.' && _value.contains('.')) {
        return;
      }
      if (token == '.' && _value.isEmpty) {
        _value = '0.';
        return;
      }
      _value = '$_value$token';
    });
  }

  void _backspace() {
    if (_value.isEmpty) {
      return;
    }
    setState(() {
      _value = _value.substring(0, _value.length - 1);
    });
  }

  void _clear() {
    setState(() {
      _value = '';
    });
  }

  void _submit({required bool fillRemaining}) {
    Navigator.of(context).pop(
      _WorkoutFieldEditResult(
        value: _value.trim(),
        fillRemaining: fillRemaining,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 8, 12, bottomInset + 8),
      child: Material(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.label.isEmpty ? 'Value' : widget.label,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    constraints: const BoxConstraints(minWidth: 84),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _surfaceRaised,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _outlineSoft),
                    ),
                    child: Text(
                      _value.isEmpty ? '0' : _value,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _value.isEmpty ? _textMuted : _textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    _WorkoutKeyboardActionChip(
                      label: 'Clear',
                      onTap: _clear,
                    ),
                    if (widget.allowFillRemaining) ...<Widget>[
                      const SizedBox(width: 8),
                      _WorkoutKeyboardActionChip(
                        label: 'Fill remaining',
                        onTap: () => _submit(fillRemaining: true),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.9,
                physics: const NeverScrollableScrollPhysics(),
                children: <Widget>[
                  for (final String token in <String>[
                    '1',
                    '2',
                    '3',
                    '⌫',
                    '4',
                    '5',
                    '6',
                    '.',
                    '7',
                    '8',
                    '9',
                    '0',
                    '',
                    '',
                    '',
                  ])
                    token.isEmpty
                        ? const SizedBox.shrink()
                        : _WorkoutKeyboardKey(
                            label: token,
                            onTap: token == '⌫'
                                ? _backspace
                                : () => _append(token),
                          ),
                  _WorkoutKeyboardKey(
                    label: 'OK',
                    filled: true,
                    onTap: () => _submit(fillRemaining: false),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkoutKeyboardActionChip extends StatelessWidget {
  const _WorkoutKeyboardActionChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _surfaceRaised,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _outlineSoft),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
      ),
    );
  }
}

class _WorkoutKeyboardKey extends StatelessWidget {
  const _WorkoutKeyboardKey({
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          color: filled ? _accentGreen : _surfaceRaised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: filled ? _accentGreen : _outlineSoft,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: filled ? _bgTop : _textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkoutSetCountButton extends StatelessWidget {
  const _WorkoutSetCountButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Ink(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: enabled ? _surfaceRaised : _surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled ? _outlineSoft : _outline,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? _textPrimary : _textMuted,
        ),
      ),
    );
  }
}

class _ExerciseExplanationLoadingSheet extends StatelessWidget {
  const _ExerciseExplanationLoadingSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _outline),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            SizedBox(height: 16),
            Text(
              'Loading coach explanation...',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseExplanationErrorSheet extends StatelessWidget {
  const _ExerciseExplanationErrorSheet({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _outline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Coach explanation unavailable',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                fontSize: 15,
                height: 1.55,
                color: _textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseExplanationSheet extends StatelessWidget {
  const _ExerciseExplanationSheet({
    required this.title,
    required this.reason,
    required this.support,
    required this.execution,
    required this.movementPattern,
  });

  final String title;
  final String reason;
  final String support;
  final String execution;
  final String movementPattern;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _outline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _outlineSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Why is this here?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              reason,
              style: const TextStyle(
                fontSize: 15,
                height: 1.55,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'What does it support later?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              support,
              style: const TextStyle(
                fontSize: 15,
                height: 1.55,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Execution note',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              execution,
              style: const TextStyle(
                fontSize: 15,
                height: 1.55,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            _DetailPill(label: 'Movement Pattern · $movementPattern'),
          ],
        ),
      ),
    );
  }
}

class _CreateBlockFormResult {
  const _CreateBlockFormResult({
    required this.username,
    required this.trainingExperience,
    required this.primaryGoal,
    required this.durationWeeks,
    required this.measurementSystem,
    required this.preferredDays,
  });

  final String username;
  final String trainingExperience;
  final String primaryGoal;
  final int durationWeeks;
  final String measurementSystem;
  final List<String> preferredDays;

  int get daysPerWeek => preferredDays.length;
}

const String _trainingExperienceBeginner = 'Beginner';
const String _trainingExperienceIntermediate = 'Intermediate';
const String _trainingExperienceAdvanced = 'Advanced';

const String _primaryGoalStrength = 'Strength';
const String _primaryGoalVolume = 'Volume';
const String _primaryGoalLoseWeight = 'Lose weight';

const String _measurementSystemMetric = 'Metric';
const String _measurementSystemImperial = 'Imperial';

const List<String> _weekdayOptions = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

class _PlanOnboardingScreen extends StatefulWidget {
  const _PlanOnboardingScreen({
    required this.initialUsername,
    required this.initialTrainingExperience,
    required this.initialPrimaryGoal,
    required this.initialMeasurementSystem,
    required this.initialPreferredDays,
    required this.busy,
    required this.generating,
    required this.status,
    required this.allowSkip,
    required this.onSubmit,
    this.onImportPastExercises,
    this.onCancel,
  });

  final String initialUsername;
  final String initialTrainingExperience;
  final String initialPrimaryGoal;
  final String initialMeasurementSystem;
  final List<String> initialPreferredDays;
  final bool busy;
  final bool generating;
  final String? status;
  final bool allowSkip;
  final Future<void> Function(_CreateBlockFormResult result) onSubmit;
  final Future<void> Function()? onImportPastExercises;
  final VoidCallback? onCancel;

  @override
  State<_PlanOnboardingScreen> createState() => _PlanOnboardingScreenState();
}

class _PlanOnboardingScreenState extends State<_PlanOnboardingScreen> {
  late final TextEditingController _usernameController;
  int _durationWeeks = 8;
  late String _trainingExperience;
  late String _primaryGoal;
  String _measurementSystem = _measurementSystemMetric;
  String? _nameError;
  late final Set<String> _preferredDays;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.initialUsername);
    _trainingExperience = <String>{
      _trainingExperienceBeginner,
      _trainingExperienceIntermediate,
      _trainingExperienceAdvanced,
    }.contains(widget.initialTrainingExperience)
        ? widget.initialTrainingExperience
        : _trainingExperienceIntermediate;
    _primaryGoal = <String>{
      _primaryGoalStrength,
      _primaryGoalVolume,
      _primaryGoalLoseWeight,
    }.contains(widget.initialPrimaryGoal)
        ? widget.initialPrimaryGoal
        : _primaryGoalStrength;
    _measurementSystem = <String>{
      _measurementSystemMetric,
      _measurementSystemImperial,
    }.contains(widget.initialMeasurementSystem)
        ? widget.initialMeasurementSystem
        : _measurementSystemMetric;
    _preferredDays = widget.initialPreferredDays.isEmpty
        ? <String>{'Mon', 'Tue', 'Thu', 'Fri'}
        : widget.initialPreferredDays.toSet();
    _usernameController.addListener(_handleUsernameChanged);
  }

  @override
  void dispose() {
    _usernameController.removeListener(_handleUsernameChanged);
    _usernameController.dispose();
    super.dispose();
  }

  void _handleUsernameChanged() {
    if (!mounted) {
      return;
    }

    final bool shouldClearError =
        _nameError != null && _usernameController.text.trim().isNotEmpty;
    if (shouldClearError) {
      setState(() {
        _nameError = null;
      });
      return;
    }

    setState(() {});
  }

  void _togglePreferredDay(String day) {
    setState(() {
      if (_preferredDays.contains(day)) {
        if (_preferredDays.length > 1) {
          _preferredDays.remove(day);
        }
      } else {
        _preferredDays.add(day);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool onWelcomeStep = _step == 0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _CoachPill(label: 'Coach Setup'),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: _outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      onWelcomeStep
                          ? 'Tell Your Coach About You'
                          : 'Build Your Block',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      onWelcomeStep
                          ? 'Start with your name so the app feels personal from the first session. Then we will shape the training direction.'
                          : 'Choose your primary goal, experience level, and preferred training days.',
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: _textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    KeyedSubtree(
                      key: ValueKey<int>(_step),
                      child: onWelcomeStep
                          ? _buildWelcomeStep()
                          : _buildPreferencesStep(),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: <Widget>[
                        if (!onWelcomeStep)
                          OutlinedButton(
                            onPressed: widget.busy
                                ? null
                                : () {
                                    setState(() {
                                      _step = 0;
                                    });
                                  },
                            child: const Text('Back'),
                          ),
                        const Spacer(),
                        FilledButton(
                          onPressed: widget.busy
                              ? null
                              : onWelcomeStep
                                  ? _goToNextStep
                                  : _submit,
                          child: Text(
                            onWelcomeStep
                                ? 'Continue'
                                : widget.generating
                                    ? 'Generating Block...'
                                    : 'Generate Block',
                          ),
                        ),
                      ],
                    ),
                    if (widget.status != null) ...<Widget>[
                      const SizedBox(height: 16),
                      _CoachStatusBanner(message: widget.status!),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeStep() {
    return Column(
      key: const ValueKey<String>('welcome-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: _usernameController,
          textCapitalization: TextCapitalization.words,
          autocorrect: false,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _goToNextStep(),
          decoration: const InputDecoration(
            labelText: 'Your name',
            hintText: 'Josef',
            border: OutlineInputBorder(),
          ).copyWith(errorText: _nameError),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surfaceRaised,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _outline),
          ),
          child: const Text(
            'This becomes part of the coach briefing, so the app feels like it is talking to you, not at you.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: _textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreferencesStep() {
    return Column(
      key: const ValueKey<String>('preferences-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _StatusRow(
          label: 'Athlete',
          value: _usernameController.text.trim().isEmpty
              ? 'Unnamed athlete'
              : _usernameController.text.trim(),
        ),
        const SizedBox(height: 12),
        const _DialogSectionLabel('Primary Goal'),
        const SizedBox(height: 8),
        _SingleSelectChips<String>(
          value: _primaryGoal,
          options: const <String>[
            _primaryGoalStrength,
            _primaryGoalVolume,
            _primaryGoalLoseWeight,
          ],
          onSelected: (String value) {
            setState(() {
              _primaryGoal = value;
            });
          },
        ),
        const SizedBox(height: 12),
        const _DialogSectionLabel('Training Experience'),
        const SizedBox(height: 8),
        _SingleSelectChips<String>(
          value: _trainingExperience,
          options: const <String>[
            _trainingExperienceBeginner,
            _trainingExperienceIntermediate,
            _trainingExperienceAdvanced,
          ],
          onSelected: (String value) {
            setState(() {
              _trainingExperience = value;
            });
          },
        ),
        const SizedBox(height: 12),
        const _DialogSectionLabel('Program Length'),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            IconButton.filledTonal(
              onPressed: () => _adjustDurationWeeks(-1),
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _editDurationWeeks,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: _surfaceRaised,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _outlineSoft),
                  ),
                  child: Column(
                    children: <Widget>[
                      Text(
                        _formatDurationWeeks(_durationWeeks),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tap to type a week count',
                        style: TextStyle(
                          fontSize: 13,
                          color: _textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filledTonal(
              onPressed: () => _adjustDurationWeeks(1),
              icon: const Icon(Icons.keyboard_arrow_up_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _DialogSectionLabel('Preferred Days'),
        const SizedBox(height: 8),
        const Text(
          'Choose the days you want to train.',
          style: TextStyle(
            fontSize: 14,
            color: _textMuted,
          ),
        ),
        const SizedBox(height: 8),
        _MultiSelectChips<String>(
          values: _preferredDays,
          options: _weekdayOptions,
          onToggled: _togglePreferredDay,
        ),
        const SizedBox(height: 12),
        const _DialogSectionLabel('Measurement System'),
        const SizedBox(height: 8),
        _SingleSelectChips<String>(
          value: _measurementSystem,
          options: const <String>[
            _measurementSystemMetric,
            _measurementSystemImperial,
          ],
          onSelected: (String value) {
            setState(() {
              _measurementSystem = value;
            });
          },
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surfaceRaised,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _outlineSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Expanded(
                    child: _DialogSectionLabel('Upload Past Exercises'),
                  ),
                  IconButton(
                    tooltip:
                        'Imported history helps the coach generate plans that fit the athlete better.',
                    onPressed: _showPastExerciseImportInfo,
                    icon: const Icon(
                      Icons.help_outline_rounded,
                      size: 18,
                      color: _textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Bring in your previous training history. The coach can use it to generate plans that fit you better.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: _textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: widget.busy ? null : widget.onImportPastExercises,
                child: const Text('Upload Past Exercises'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          height: 1,
          decoration: BoxDecoration(
            color: _outlineSoft,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ],
    );
  }

  void _goToNextStep() {
    if (_usernameController.text.trim().isEmpty) {
      setState(() {
        _nameError = 'Please enter your name before continuing.';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _nameError = null;
      _step = 1;
    });
  }

  Future<void> _submit() async {
    final String username = _usernameController.text.trim();
    if (username.isEmpty) {
      return;
    }

    await widget.onSubmit(
      _CreateBlockFormResult(
        username: username,
        trainingExperience: _trainingExperience,
        primaryGoal: _primaryGoal,
        durationWeeks: _durationWeeks,
        measurementSystem: _measurementSystem,
        preferredDays: _weekdayOptions
            .where(_preferredDays.contains)
            .toList(growable: false),
      ),
    );
  }

  Future<void> _showPastExerciseImportInfo() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _surface,
          title: const Text(
            'Why import past exercises?',
            style: TextStyle(color: _textPrimary),
          ),
          content: const Text(
            'Your training history gives the coach useful context about what you have already done, what you recover from well, and which plans are more likely to fit you.',
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: _textSecondary,
            ),
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  String _formatDurationWeeks(int weeks) {
    final int safeWeeks = weeks.clamp(4, 12);
    return safeWeeks == 1 ? '1 week' : '$safeWeeks weeks';
  }

  void _adjustDurationWeeks(int deltaWeeks) {
    setState(() {
      _durationWeeks = (_durationWeeks + deltaWeeks).clamp(4, 12);
    });
  }

  Future<void> _editDurationWeeks() async {
    final int? weeks = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return _IntegerInputDialog(
          title: 'Program Length',
          labelText: 'Weeks',
          hintText: '8',
          initialValue: _durationWeeks,
          confirmLabel: 'Save',
        );
      },
    );
    if (weeks == null) {
      return;
    }

    setState(() {
      _durationWeeks = weeks.clamp(4, 12);
    });
  }
}

class _DialogSectionLabel extends StatelessWidget {
  const _DialogSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: _textMuted,
      ),
    );
  }
}

class _IntegerInputDialog extends StatefulWidget {
  const _IntegerInputDialog({
    required this.title,
    required this.labelText,
    required this.initialValue,
    required this.confirmLabel,
    this.hintText,
  });

  final String title;
  final String labelText;
  final int initialValue;
  final String confirmLabel;
  final String? hintText;

  @override
  State<_IntegerInputDialog> createState() => _IntegerInputDialogState();
}

class _IntegerInputDialogState extends State<_IntegerInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.initialValue}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _surface,
      title: Text(
        widget.title,
        style: const TextStyle(color: _textPrimary),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: _textPrimary),
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(int.tryParse(_controller.text.trim())),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

class _SingleSelectChips<T> extends StatelessWidget {
  const _SingleSelectChips({
    required this.value,
    required this.options,
    required this.onSelected,
    this.labelBuilder,
  });

  final T value;
  final List<T> options;
  final ValueChanged<T> onSelected;
  final String Function(T value)? labelBuilder;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options
          .map(
            (T option) => ChoiceChip(
              label: Text(labelBuilder?.call(option) ?? '$option'),
              selected: option == value,
              onSelected: (_) => onSelected(option),
              selectedColor: _accentGreen,
              labelStyle: TextStyle(
                color:
                    option == value ? const Color(0xFF07110C) : _textSecondary,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: _surfaceRaised,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: BorderSide(
                  color: option == value ? _accentGreen : _outline,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MultiSelectChips<T> extends StatelessWidget {
  const _MultiSelectChips({
    required this.values,
    required this.options,
    required this.onToggled,
  });

  final Set<T> values;
  final List<T> options;
  final ValueChanged<T> onToggled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options
          .map(
            (T option) => FilterChip(
              label: Text('$option'),
              selected: values.contains(option),
              onSelected: (_) => onToggled(option),
              selectedColor: _accentGreen,
              checkmarkColor: const Color(0xFF07110C),
              labelStyle: TextStyle(
                color: values.contains(option)
                    ? const Color(0xFF07110C)
                    : _textSecondary,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: _surfaceRaised,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: BorderSide(
                  color: values.contains(option) ? _accentGreen : _outline,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _UiException implements Exception {
  const _UiException(this.message);

  final String message;
}

class _BackendConnectivityException implements Exception {
  const _BackendConnectivityException(this.message);

  final String message;
}
