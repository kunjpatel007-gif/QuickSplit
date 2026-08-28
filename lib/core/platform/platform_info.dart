import 'dart:io';

class PlatformInfo {
  static bool get isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;
  
  static bool get supportsCamera => isMobile;
  
  static bool get supportsNfc => Platform.isAndroid;
  
  static bool get supportsBackgroundTasks => isMobile;
  
  static bool get supportsHomeWidget => Platform.isAndroid;
}
