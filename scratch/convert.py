import re

with open('lib/presentation/widgets/player/viewport/player_viewport.dart', 'r') as f:
    content = f.read()

# Replace class signature
content = content.replace('class PlayerViewport extends ConsumerWidget {', 'class PlayerViewport extends ConsumerStatefulWidget {\n  @override\n  ConsumerState<PlayerViewport> createState() => _PlayerViewportState();\n}\n\nclass _PlayerViewportState extends ConsumerState<PlayerViewport> {')

# Replace build signature
content = content.replace('Widget build(BuildContext context, WidgetRef ref) {', 'Widget build(BuildContext context) {\n    final ref = this.ref;')

# Extract all field names from PlayerViewport class definition
fields = ['isUsingExoPlayer', 'mpvPlayerService', 'fitMode', 'selectedSubtitleTrackId', 'areControlsVisible', 'isTransitioningOrientation', 'onToggleControls', 'onPlayOrPause', 'onSeekRelative', 'onSeekTo', 'onToggleFullscreen', 'isFullscreen', 'isDesktop', 'volume', 'onVolumeChanged', 'brightness', 'onBrightnessChanged', 'isBuffering', 'seekFeedback', 'seekFeedbackKey', 'fallbackNotice', 'isStatsVisible', 'performanceStats', 'onCloseStats', 'canSkipCurrentChapter', 'activeChapter', 'onSkipChapter', 'chapters', 'title', 'episodeTitle', 'videoSource', 'videoUrl', 'onBack', 'onOpenSettings', 'onToggleSidePanel', 'isSidePanelCollapsed', 'positionNotifier', 'bufferNotifier', 'duration', 'isPlaying', 'hasNextEpisode', 'onNextEpisode']

# Add widget. to all fields in the build method
build_start = content.find('Widget build(BuildContext context) {')
before_build = content[:build_start]
build_body = content[build_start:]

for field in fields:
    # use regex to replace field but not when it's already widget.field or part of a longer word
    build_body = re.sub(r'(?<!\w|\.)' + field + r'(?!\w)', 'widget.' + field, build_body)

# Handle the specific controlsMounted logic
init_state_code = """
  bool _controlsMounted = true;

  @override
  void initState() {
    super.initState();
    _controlsMounted = widget.areControlsVisible;
  }

  @override
  void didUpdateWidget(PlayerViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.areControlsVisible && !oldWidget.areControlsVisible) {
      setState(() => _controlsMounted = true);
    }
  }

"""
build_body = init_state_code + build_body

# Replace AnimatedOpacity onEnd
animated_opacity_re = r'AnimatedOpacity\(\s*opacity: \(widget\.areControlsVisible && !widget\.isTransitioningOrientation\) \? 1\.0 : 0\.0,\s*duration: const Duration\(milliseconds: 200\),\s*child: IgnorePointer\('
replacement = r'''AnimatedOpacity(
              opacity: (widget.areControlsVisible && !widget.isTransitioningOrientation) ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              onEnd: () {
                if (!widget.areControlsVisible && mounted) {
                  setState(() => _controlsMounted = false);
                }
              },
              child: IgnorePointer('''
build_body = build_body.replace(re.search(animated_opacity_re, build_body).group(0), replacement) if re.search(animated_opacity_re, build_body) else build_body

# Wrap Top and Bottom bars with _controlsMounted condition manually
lines = build_body.split('\n')
for i, line in enumerate(lines):
    if '// Top Bar with gradient' in line:
        lines[i+1] = lines[i+1].replace('Positioned(', 'if (_controlsMounted) Positioned(')
    elif '// Bottom Bar with gradient' in line:
        lines[i+1] = lines[i+1].replace('Positioned(', 'if (_controlsMounted) Positioned(')

build_body = '\n'.join(lines)

with open('scratch/out.dart', 'w') as f:
    f.write(before_build + build_body)

