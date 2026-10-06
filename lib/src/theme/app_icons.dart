import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hermes_app/src/theme/platform_chrome.dart';

/// An icon with a Material glyph and the SF Symbols-style glyph Apple
/// platforms show instead.
class AppIconSet {
  const AppIconSet(this.material, this.apple);

  final IconData material;
  final IconData apple;

  IconData of(BuildContext context) =>
      platformChromeOf(context).isApple ? apple : material;
}

/// An [Icon] that picks its glyph from [AppIconSet] for the current platform.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });

  final AppIconSet icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Icon(
    icon.of(context),
    size: size,
    color: color,
    semanticLabel: semanticLabel,
  );
}

/// Every icon the app shows, by what it means. Material platforms keep the
/// Material glyph; iOS and macOS get the matching Cupertino one.
abstract final class AppIcons {
  static const error = AppIconSet(
    Icons.error_outline,
    CupertinoIcons.exclamationmark_circle,
  );
  static const errorFilled = AppIconSet(
    Icons.error,
    CupertinoIcons.exclamationmark_circle_fill,
  );
  static const add = AppIconSet(Icons.add, CupertinoIcons.add);
  static const search = AppIconSet(Icons.search, CupertinoIcons.search);
  static const delete = AppIconSet(Icons.delete_outline, CupertinoIcons.delete);
  static const person = AppIconSet(Icons.person_outline, CupertinoIcons.person);
  static const close = AppIconSet(Icons.close, CupertinoIcons.xmark);
  static const expandMore = AppIconSet(
    Icons.expand_more,
    CupertinoIcons.chevron_down,
  );
  static const expandLess = AppIconSet(
    Icons.expand_less,
    CupertinoIcons.chevron_up,
  );
  static const chevronRight = AppIconSet(
    Icons.chevron_right,
    CupertinoIcons.chevron_right,
  );
  static const refresh = AppIconSet(Icons.refresh, CupertinoIcons.refresh);
  static const lock = AppIconSet(Icons.lock_outline, CupertinoIcons.lock);
  static const copy = AppIconSet(Icons.copy, CupertinoIcons.doc_on_doc);
  static const copyOutlined = AppIconSet(
    Icons.content_copy_outlined,
    CupertinoIcons.doc_on_doc,
  );
  static const check = AppIconSet(Icons.check, CupertinoIcons.check_mark);
  static const chat = AppIconSet(
    Icons.chat_bubble_outline,
    CupertinoIcons.chat_bubble,
  );
  static const chatFilled = AppIconSet(
    Icons.chat_bubble,
    CupertinoIcons.chat_bubble_fill,
  );
  static const warning = AppIconSet(
    Icons.warning_amber_outlined,
    CupertinoIcons.exclamationmark_triangle,
  );
  static const warningRounded = AppIconSet(
    Icons.warning_amber_rounded,
    CupertinoIcons.exclamationmark_triangle,
  );
  static const warningPlain = AppIconSet(
    Icons.warning_amber,
    CupertinoIcons.exclamationmark_triangle,
  );
  static const schedule = AppIconSet(Icons.schedule, CupertinoIcons.clock);
  static const scheduleOutlined = AppIconSet(
    Icons.schedule_outlined,
    CupertinoIcons.clock,
  );
  static const time = AppIconSet(Icons.access_time, CupertinoIcons.clock);
  static const file = AppIconSet(
    Icons.insert_drive_file_outlined,
    CupertinoIcons.doc,
  );
  static const info = AppIconSet(
    Icons.info_outline,
    CupertinoIcons.info_circle,
  );
  static const hub = AppIconSet(
    Icons.hub_outlined,
    CupertinoIcons.circle_grid_hex,
  );
  static const extension = AppIconSet(
    Icons.extension_outlined,
    CupertinoIcons.cube_box,
  );
  static const extensionOff = AppIconSet(
    Icons.extension_off_outlined,
    CupertinoIcons.nosign,
  );
  static const edit = AppIconSet(Icons.edit_outlined, CupertinoIcons.pencil);
  static const download = AppIconSet(
    Icons.download_outlined,
    CupertinoIcons.arrow_down_to_line,
  );
  static const install = AppIconSet(
    Icons.system_update_alt,
    CupertinoIcons.arrow_down_to_line,
  );
  static const checkCircle = AppIconSet(
    Icons.check_circle_outline,
    CupertinoIcons.check_mark_circled,
  );
  static const checkCircleFilled = AppIconSet(
    Icons.check_circle,
    CupertinoIcons.check_mark_circled_solid,
  );
  static const attach = AppIconSet(Icons.attach_file, CupertinoIcons.paperclip);
  static const kanban = AppIconSet(
    Icons.view_kanban_outlined,
    CupertinoIcons.rectangle_split_3x1,
  );
  static const kanbanFilled = AppIconSet(
    Icons.view_kanban,
    CupertinoIcons.rectangle_split_3x1,
  );
  static const undo = AppIconSet(Icons.undo, CupertinoIcons.arrow_uturn_left);
  static const redo = AppIconSet(Icons.redo, CupertinoIcons.arrow_uturn_right);
  static const tune = AppIconSet(
    Icons.tune,
    CupertinoIcons.slider_horizontal_3,
  );
  static const stop = AppIconSet(
    Icons.stop_circle_outlined,
    CupertinoIcons.stop_circle,
  );
  static const speed = AppIconSet(
    Icons.speed_outlined,
    CupertinoIcons.speedometer,
  );
  static const bot = AppIconSet(
    Icons.smart_toy_outlined,
    CupertinoIcons.person_crop_square,
  );
  static const shield = AppIconSet(
    Icons.shield_outlined,
    CupertinoIcons.shield,
  );
  static const send = AppIconSet(Icons.send, CupertinoIcons.paperplane);
  static const sendOutlined = AppIconSet(
    Icons.send_outlined,
    CupertinoIcons.paperplane,
  );
  static const sendArrow = AppIconSet(
    Icons.arrow_upward,
    CupertinoIcons.arrow_up,
  );
  static const reasoning = AppIconSet(
    Icons.psychology_outlined,
    CupertinoIcons.lightbulb,
  );
  static const idea = AppIconSet(
    Icons.lightbulb_outline,
    CupertinoIcons.lightbulb,
  );
  static const resume = AppIconSet(
    Icons.play_circle_outline,
    CupertinoIcons.play_circle,
  );
  static const play = AppIconSet(Icons.play_arrow, CupertinoIcons.play_fill);
  static const pause = AppIconSet(Icons.pause, CupertinoIcons.pause_fill);
  static const moreVertical = AppIconSet(
    Icons.more_vert,
    CupertinoIcons.ellipsis,
  );
  static const more = AppIconSet(Icons.more_horiz, CupertinoIcons.ellipsis);
  static const image = AppIconSet(Icons.image_outlined, CupertinoIcons.photo);
  static const brokenImage = AppIconSet(
    Icons.broken_image_outlined,
    CupertinoIcons.photo,
  );
  static const flag = AppIconSet(Icons.flag_outlined, CupertinoIcons.flag);
  static const server = AppIconSet(
    Icons.dns_outlined,
    CupertinoIcons.desktopcomputer,
  );
  static const archive = AppIconSet(
    Icons.archive_outlined,
    CupertinoIcons.archivebox,
  );
  static const sidebar = AppIconSet(
    Icons.view_sidebar_outlined,
    CupertinoIcons.sidebar_left,
  );
  static const inspector = AppIconSet(
    Icons.view_sidebar_outlined,
    CupertinoIcons.sidebar_right,
  );
  static const terminal = AppIconSet(
    Icons.terminal,
    CupertinoIcons.chevron_left_slash_chevron_right,
  );
  static const swap = AppIconSet(
    Icons.swap_horiz,
    CupertinoIcons.arrow_right_arrow_left,
  );
  static const pin = AppIconSet(Icons.push_pin, CupertinoIcons.pin_fill);
  static const unpin = AppIconSet(
    Icons.push_pin_outlined,
    CupertinoIcons.pin_slash,
  );
  static const pinOutline = AppIconSet(
    Icons.push_pin_outlined,
    CupertinoIcons.pin,
  );
  static const power = AppIconSet(Icons.power_outlined, CupertinoIcons.power);
  static const photoLibrary = AppIconSet(
    Icons.photo_library_outlined,
    CupertinoIcons.photo_on_rectangle,
  );
  static const camera = AppIconSet(
    Icons.photo_camera_outlined,
    CupertinoIcons.camera,
  );
  static const personAdd = AppIconSet(
    Icons.person_add_alt,
    CupertinoIcons.person_badge_plus,
  );
  static const password = AppIconSet(Icons.password, CupertinoIcons.lock);
  static const openExternal = AppIconSet(
    Icons.open_in_new,
    CupertinoIcons.arrow_up_right_square,
  );
  static const openBrowser = AppIconSet(
    Icons.open_in_browser,
    CupertinoIcons.globe,
  );
  static const menu = AppIconSet(Icons.menu, CupertinoIcons.line_horizontal_3);
  static const signIn = AppIconSet(
    Icons.login,
    CupertinoIcons.arrow_right_circle,
  );
  static const link = AppIconSet(Icons.link, CupertinoIcons.link);
  static const waiting = AppIconSet(
    Icons.hourglass_empty,
    CupertinoIcons.hourglass,
  );
  static const help = AppIconSet(
    Icons.help_outline,
    CupertinoIcons.question_circle,
  );
  static const shieldWarning = AppIconSet(
    Icons.gpp_maybe_outlined,
    CupertinoIcons.exclamationmark_shield,
  );
  static const handRaised = AppIconSet(
    Icons.front_hand_outlined,
    CupertinoIcons.hand_raised,
  );
  static const filter = AppIconSet(
    Icons.filter_list,
    CupertinoIcons.line_horizontal_3_decrease,
  );
  static const openFile = AppIconSet(
    Icons.file_open_outlined,
    CupertinoIcons.folder,
  );
  static const move = AppIconSet(
    Icons.drive_file_move_outline,
    CupertinoIcons.folder,
  );
  static const dragHandle = AppIconSet(
    Icons.drag_indicator,
    CupertinoIcons.line_horizontal_3,
  );
  static const boxCancelled = AppIconSet(
    Icons.disabled_by_default_outlined,
    CupertinoIcons.xmark_square,
  );
  static const boardMenu = AppIconSet(
    Icons.dashboard_customize_outlined,
    CupertinoIcons.square_grid_2x2,
  );
  static const radioOff = AppIconSet(
    Icons.circle_outlined,
    CupertinoIcons.circle,
  );
  static const radioOn = AppIconSet(Icons.circle, CupertinoIcons.circle_filled);
  static const boxChecked = AppIconSet(
    Icons.check_box,
    CupertinoIcons.checkmark_square_fill,
  );
  static const boxPartial = AppIconSet(
    Icons.indeterminate_check_box,
    CupertinoIcons.minus_square_fill,
  );
  static const boxEmpty = AppIconSet(
    Icons.check_box_outline_blank,
    CupertinoIcons.square,
  );
  static const calendar = AppIconSet(
    Icons.calendar_today,
    CupertinoIcons.calendar,
  );
  static const blocked = AppIconSet(Icons.block, CupertinoIcons.nosign);
  static const magic = AppIconSet(
    Icons.auto_fix_high,
    CupertinoIcons.wand_stars,
  );
  static const sparkle = AppIconSet(
    Icons.auto_awesome,
    CupertinoIcons.sparkles,
  );
  static const dropDown = AppIconSet(
    Icons.arrow_drop_down,
    CupertinoIcons.chevron_down,
  );
  static const dropRight = AppIconSet(
    Icons.arrow_right,
    CupertinoIcons.chevron_right,
  );

  /// Apple platforms have no matching glyph, so both keep the Material one.
  static const toggleOn = AppIconSet(Icons.toggle_on, Icons.toggle_on);
  static const toggleOff = AppIconSet(Icons.toggle_off, Icons.toggle_off);
  static const tree = AppIconSet(
    Icons.account_tree_outlined,
    CupertinoIcons.arrow_branch,
  );
  static const compose = AppIconSet(
    Icons.edit_square,
    CupertinoIcons.square_pencil,
  );
  static const share = AppIconSet(Icons.ios_share, CupertinoIcons.share);
  static const unfold = AppIconSet(
    Icons.unfold_more,
    CupertinoIcons.chevron_up_chevron_down,
  );
  static const history = AppIconSet(Icons.history, CupertinoIcons.clock);
  static const clearFilled = AppIconSet(
    Icons.cancel,
    CupertinoIcons.xmark_circle_fill,
  );

  /// Every set by name, for the catalog and for tests.
  static const all = <String, AppIconSet>{
    'error': error,
    'errorFilled': errorFilled,
    'add': add,
    'search': search,
    'delete': delete,
    'person': person,
    'close': close,
    'expandMore': expandMore,
    'expandLess': expandLess,
    'chevronRight': chevronRight,
    'refresh': refresh,
    'lock': lock,
    'copy': copy,
    'copyOutlined': copyOutlined,
    'check': check,
    'chat': chat,
    'chatFilled': chatFilled,
    'warning': warning,
    'warningRounded': warningRounded,
    'warningPlain': warningPlain,
    'schedule': schedule,
    'scheduleOutlined': scheduleOutlined,
    'time': time,
    'file': file,
    'info': info,
    'hub': hub,
    'extension': extension,
    'extensionOff': extensionOff,
    'edit': edit,
    'download': download,
    'install': install,
    'checkCircle': checkCircle,
    'checkCircleFilled': checkCircleFilled,
    'attach': attach,
    'kanban': kanban,
    'kanbanFilled': kanbanFilled,
    'undo': undo,
    'redo': redo,
    'tune': tune,
    'stop': stop,
    'speed': speed,
    'bot': bot,
    'shield': shield,
    'send': send,
    'sendOutlined': sendOutlined,
    'sendArrow': sendArrow,
    'reasoning': reasoning,
    'idea': idea,
    'resume': resume,
    'play': play,
    'pause': pause,
    'more': more,
    'image': image,
    'brokenImage': brokenImage,
    'flag': flag,
    'server': server,
    'archive': archive,
    'sidebar': sidebar,
    'inspector': inspector,
    'terminal': terminal,
    'swap': swap,
    'pin': pin,
    'unpin': unpin,
    'power': power,
    'photoLibrary': photoLibrary,
    'camera': camera,
    'personAdd': personAdd,
    'password': password,
    'openExternal': openExternal,
    'openBrowser': openBrowser,
    'menu': menu,
    'signIn': signIn,
    'link': link,
    'waiting': waiting,
    'help': help,
    'shieldWarning': shieldWarning,
    'handRaised': handRaised,
    'filter': filter,
    'openFile': openFile,
    'move': move,
    'dragHandle': dragHandle,
    'boxCancelled': boxCancelled,
    'boardMenu': boardMenu,
    'radioOff': radioOff,
    'radioOn': radioOn,
    'boxChecked': boxChecked,
    'boxPartial': boxPartial,
    'boxEmpty': boxEmpty,
    'calendar': calendar,
    'blocked': blocked,
    'magic': magic,
    'sparkle': sparkle,
    'dropDown': dropDown,
    'dropRight': dropRight,
    'moreVertical': moreVertical,
    'toggleOn': toggleOn,
    'toggleOff': toggleOff,
    'tree': tree,
    'history': history,
    'unfold': unfold,
    'compose': compose,
    'share': share,
    'clearFilled': clearFilled,
  };
}
