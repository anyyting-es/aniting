import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Available icon packs for the app.
enum AppIconPack {
  lucide,
  material,
}

/// Riverpod provider for managing the user selected icon pack.
class IconPackNotifier extends Notifier<AppIconPack> {
  static const String _prefKey = 'app_icon_pack';
  static SharedPreferences? _cachedPrefs;

  static void setCachedPrefs(SharedPreferences prefs) {
    _cachedPrefs = prefs;
  }

  static AppIconPack get currentPack {
    final cached = _cachedPrefs;
    if (cached != null) {
      final val = cached.getString(_prefKey);
      if (val == 'material') return AppIconPack.material;
      return AppIconPack.lucide;
    }
    return AppIconPack.lucide;
  }

  @override
  AppIconPack build() {
    final cached = _cachedPrefs;
    if (cached != null) {
      final val = cached.getString(_prefKey);
      if (val == 'material') return AppIconPack.material;
      return AppIconPack.lucide;
    }
    _loadFromPrefs();
    return AppIconPack.lucide;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedPrefs = prefs;
    final val = prefs.getString(_prefKey);
    state = val == 'material' ? AppIconPack.material : AppIconPack.lucide;
  }

  Future<void> setIconPack(AppIconPack pack) async {
    state = pack;
    final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
    _cachedPrefs = prefs;
    await prefs.setString(_prefKey, pack == AppIconPack.material ? 'material' : 'lucide');
  }
}

final iconPackProvider = NotifierProvider<IconPackNotifier, AppIconPack>(IconPackNotifier.new);

/// Semantic Icon mappings across different packs (Lucide web/desktop vs Material).
class AppIcons {
  const AppIcons._();

  static bool _isLucide([AppIconPack? pack]) =>
      (pack ?? IconPackNotifier.currentPack) == AppIconPack.lucide;

  static IconData home([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.home : Icons.home_rounded;

  static IconData manga([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.bookOpen : Icons.menu_book_rounded;

  static IconData explore([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.compass : Icons.explore_rounded;

  static IconData profile([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.user : Icons.person_rounded;

  static IconData settings([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.settings : Icons.settings_rounded;

  static IconData search([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.search : Icons.search_rounded;

  static IconData searchOff([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.searchX : Icons.search_off_rounded;

  static IconData clearAll([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.listX : Icons.clear_all_rounded;

  static IconData play([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.play : Icons.play_arrow_rounded;

  static IconData playCircle([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.playCircle : Icons.play_circle_rounded;

  static IconData pause([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.pause : Icons.pause_rounded;

  static IconData check([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.check : Icons.check_rounded;

  static IconData checkCircle([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.checkCircle : Icons.check_circle_outline_rounded;

  static IconData close([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.x : Icons.close_rounded;

  static IconData refresh([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.refreshCw : Icons.refresh_rounded;

  static IconData trash([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.trash2 : Icons.delete_outline_rounded;

  static IconData folder([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.folder : Icons.folder_outlined;

  static IconData folderFilled([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.folder : Icons.folder_rounded;

  static IconData folderZip([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.archive : Icons.folder_zip_rounded;

  static IconData download([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.download : Icons.download_rounded;

  static IconData downloadOffline([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.downloadCloud : Icons.download_for_offline_rounded;

  static IconData palette([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.palette : Icons.palette_outlined;

  static IconData appearance([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.layoutTemplate : Icons.dashboard_customize_rounded;

  static IconData extension([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.puzzle : Icons.extension_rounded;

  static IconData sliders([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.sliders : Icons.tune_rounded;

  static IconData tv([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.tv : Icons.tv_rounded;

  static IconData stream([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.radio : Icons.stream_rounded;

  static IconData chevronRight([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.chevronRight : Icons.chevron_right_rounded;

  static IconData chevronLeft([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.chevronLeft : Icons.chevron_left_rounded;

  static IconData chevronDown([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.chevronDown : Icons.keyboard_arrow_down_rounded;

  static IconData chevronUp([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.chevronUp : Icons.keyboard_arrow_up_rounded;

  static IconData arrowLeft([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.arrowLeft : Icons.arrow_back_rounded;

  static IconData arrowRight([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.arrowRight : Icons.arrow_forward_rounded;

  static IconData star([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.star : Icons.star_rounded;

  static IconData heart([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.heart : Icons.favorite_rounded;

  static IconData filter([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.filter : Icons.filter_list_rounded;

  static IconData filterAlt([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.filter : Icons.filter_alt_outlined;

  static IconData info([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.info : Icons.info_outline_rounded;

  static IconData sparkles([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.sparkles : Icons.auto_awesome_rounded;

  static IconData volume([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.volume2 : Icons.volume_up_rounded;

  static IconData volumeMute([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.volumeX : Icons.volume_off_rounded;

  static IconData subtitles([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.subtitles : Icons.subtitles_rounded;

  static IconData server([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.server : Icons.dns_rounded;

  static IconData serverOff([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.cloudOff : Icons.cloud_off_rounded;

  static IconData wifiOff([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.wifiOff : Icons.wifi_off_rounded;

  static IconData calendar([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.calendar : Icons.calendar_month_rounded;

  static IconData category([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.layoutGrid : Icons.category_rounded;

  static IconData sort([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.arrowUpDown : Icons.sort_rounded;

  static IconData openInNew([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.externalLink : Icons.open_in_new_rounded;

  static IconData code([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.code : Icons.code_rounded;

  static IconData copy([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.copy : Icons.copy_rounded;

  static IconData history([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.history : Icons.history_rounded;

  static IconData bookmark([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.bookmark : Icons.bookmark_rounded;

  static IconData bookmarkOutline([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.bookmark : Icons.bookmark_border_rounded;

  static IconData bookmarks([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.library : Icons.collections_bookmark_rounded;

  static IconData devices([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.laptop : Icons.devices_rounded;

  static IconData update([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.rotateCw : Icons.system_update_rounded;

  static IconData shield([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.shieldCheck : Icons.policy_rounded;

  static IconData movie([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.film : Icons.movie_filter_rounded;

  static IconData videoLibrary([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.video : Icons.video_library_rounded;

  static IconData error([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.alertCircle : Icons.error_outline_rounded;

  static IconData wavingHand([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.hand : Icons.waving_hand_rounded;

  static IconData restore([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.rotateCcw : Icons.restore_rounded;

  static IconData sync([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.refreshCw : Icons.sync_rounded;

  static IconData radioChecked([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.circleDot : Icons.radio_button_checked_rounded;

  static IconData radioUnchecked([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.circle : Icons.radio_button_unchecked_rounded;

  static IconData darkMode([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.moon : Icons.dark_mode_rounded;

  static IconData lightMode([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.sun : Icons.light_mode_rounded;

  static IconData systemMode([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.monitor : Icons.brightness_auto_rounded;

  static IconData theme([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.palette : Icons.palette_outlined;

  static IconData fastForward([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.fastForward : Icons.fast_forward_rounded;

  static IconData fastRewind([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.rewind : Icons.fast_rewind_rounded;

  static IconData skipNext([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.skipForward : Icons.skip_next_rounded;

  static IconData skipPrevious([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.skipBack : Icons.skip_previous_rounded;

  static IconData forward10([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.rotateCw : Icons.forward_10_rounded;

  static IconData replay10([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.rotateCcw : Icons.replay_10_rounded;

  static IconData fullscreen([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.maximize2 : Icons.fullscreen_rounded;

  static IconData fullscreenExit([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.minimize2 : Icons.fullscreen_exit_rounded;

  static IconData volumeDown([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.volume1 : Icons.volume_down_rounded;

  static IconData volumeLow([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.volume : Icons.volume_mute_rounded;

  static IconData brightnessHigh([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.sun : Icons.brightness_high_rounded;

  static IconData brightnessLow([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.sunDim : Icons.brightness_low_rounded;

  static IconData sidebar([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.panelRight : Icons.view_sidebar_rounded;

  static IconData sidebarOutline([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.panelRightClose : Icons.view_sidebar_outlined;

  static IconData analytics([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.barChart2 : Icons.analytics_outlined;

  static IconData music([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.music : Icons.music_note_outlined;

  static IconData musicQueue([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.listMusic : Icons.queue_music_outlined;

  static IconData speed([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.gauge : Icons.speed_rounded;

  static IconData audio([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.audioLines : Icons.audiotrack_outlined;

  static IconData subtitlesOff([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.subtitles : Icons.subtitles_off_outlined;

  static IconData syncAlt([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.arrowLeftRight : Icons.sync_alt_rounded;

  static IconData power([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.power : Icons.power_settings_new_outlined;

  static IconData touchApp([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.pointer : Icons.touch_app_outlined;

  static IconData eye([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.eye : Icons.remove_red_eye_outlined;

  static IconData arrowDown([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.arrowDown : Icons.arrow_downward_rounded;

  static IconData arrowUp([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.arrowUp : Icons.arrow_upward_rounded;

  static IconData users([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.users : Icons.people_outline_rounded;

  static IconData timer([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.timer : Icons.timer_outlined;

  static IconData clock([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.clock : Icons.schedule_rounded;

  static IconData brokenImage([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.imageOff : Icons.broken_image_rounded;

  static IconData listOrdered([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.listOrdered : Icons.format_list_numbered_rounded;

  static IconData swapVert([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.arrowUpDown : Icons.swap_vert_rounded;

  static IconData fitContain([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.shrink : Icons.fit_screen_rounded;

  static IconData fitCover([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.crop : Icons.crop_free_rounded;

  static IconData fitFill([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.expand : Icons.aspect_ratio_rounded;

  static IconData gradient([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.layers : Icons.gradient_rounded;

  static IconData share([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.share2 : Icons.share_rounded;

  static IconData globe([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.globe : Icons.public_rounded;

  static IconData cloudDownload([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.cloudDownload : Icons.cloud_download_outlined;

  static IconData grid([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.layoutGrid : Icons.image_outlined;

  static IconData list([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.layoutList : Icons.view_agenda_outlined;

  static IconData video([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.video : Icons.smart_display_rounded;

  static IconData voice([AppIconPack? pack]) =>
      _isLucide(pack) ? LucideIcons.mic : Icons.record_voice_over_rounded;
}

