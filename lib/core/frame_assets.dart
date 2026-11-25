String? layDuongDanKhung(String? id, String? ten, {bool dangTrangBi = false}) {
  final nhanDang = '${id ?? ''} ${ten ?? ''}'.toLowerCase();
  String? mauKhung;

  if (nhanDang.contains('gold') ||
      nhanDang.contains('yellow') ||
      nhanDang.contains('vàng') ||
      nhanDang.contains('vang')) {
    mauKhung = 'gold';
  } else if (nhanDang.contains('silver') ||
      nhanDang.contains('bạc') ||
      nhanDang.contains('bac') ||
      nhanDang.contains('ice') ||
      nhanDang.contains('băng') ||
      nhanDang.contains('bang') ||
      nhanDang.contains('white') ||
      nhanDang.contains('gray') ||
      nhanDang.contains('grey')) {
    mauKhung = 'silver';
  } else if (nhanDang.contains('fire') ||
      nhanDang.contains('flame') ||
      nhanDang.contains('red') ||
      nhanDang.contains('crimson') ||
      nhanDang.contains('đỏ') ||
      nhanDang.contains('lửa') ||
      nhanDang.contains('lua')) {
    mauKhung = 'fire';
  } else if (nhanDang.contains('neon') ||
      nhanDang.contains('purple') ||
      nhanDang.contains('tím') ||
      nhanDang.contains('tim') ||
      nhanDang.contains('blue') ||
      nhanDang.contains('xanh')) {
    mauKhung = 'neon';
  }

  if (mauKhung == null) return null;
  final duoiAnh = dangTrangBi ? '_overlay.png' : '.jpg';
  return 'assets/images/frames/frame_$mauKhung$duoiAnh';
}
