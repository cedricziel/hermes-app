/// The uniform type identifier a promised file declares, from the extension of
/// its [name].
///
/// The receiver uses it to decide whether it accepts the file; the name it
/// gets is the one the item proposes. A file of an unknown type goes out as
/// `public.data`, which any file drop target takes.
String dragFileType(String name) {
  final dot = name.lastIndexOf('.');
  final extension = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  return _byExtension[extension] ?? 'public.data';
}

const _byExtension = <String, String>{
  'pdf': 'com.adobe.pdf',
  'png': 'public.png',
  'jpg': 'public.jpeg',
  'jpeg': 'public.jpeg',
  'gif': 'com.compuserve.gif',
  'webp': 'org.webmproject.webp',
  'heic': 'public.heic',
  'tif': 'public.tiff',
  'tiff': 'public.tiff',
  'bmp': 'com.microsoft.bmp',
  'svg': 'public.svg-image',
  'txt': 'public.plain-text',
  'log': 'public.plain-text',
  'md': 'net.daringfireball.markdown',
  'markdown': 'net.daringfireball.markdown',
  'csv': 'public.comma-separated-values-text',
  'json': 'public.json',
  'html': 'public.html',
  'htm': 'public.html',
  'zip': 'public.zip-archive',
  'doc': 'com.microsoft.word.doc',
  'docx': 'org.openxmlformats.wordprocessingml.document',
  'xls': 'com.microsoft.excel.xls',
  'xlsx': 'org.openxmlformats.spreadsheetml.sheet',
  'pptx': 'org.openxmlformats.presentationml.presentation',
  'epub': 'org.idpf.epub-container',
  'mp3': 'public.mp3',
  'm4a': 'com.apple.m4a-audio',
  'wav': 'com.microsoft.waveform-audio',
  'mp4': 'public.mpeg-4',
  'mov': 'com.apple.quicktime-movie',
};
