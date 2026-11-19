import 'dart:convert';

import 'package:flutter/material.dart';

class ItemVisual extends StatelessWidget {
  const ItemVisual({
    super.key,
    required this.imageUrl,
    required this.type,
    this.code = '',
    this.itemId = '',
    this.size = 48,
  });

  final String imageUrl;
  final String type;
  final String code;
  final String itemId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = _placeholder;
    if (imageUrl.isNotEmpty && imageUrl.length <= 4) {
      return _placeholderWidget(imageUrl);
    }

    if (imageUrl.startsWith('data:image/')) {
      final separator = imageUrl.indexOf(',');
      if (separator > 0) {
        try {
          return _image(
            Image.memory(
              base64Decode(imageUrl.substring(separator + 1)),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _placeholderWidget(placeholder),
            ),
          );
        } on FormatException {
          return _placeholderWidget(placeholder);
        }
      }
      return _placeholderWidget(placeholder);
    }

    final uri = Uri.tryParse(imageUrl);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.hasAuthority) {
      return _image(
        Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _placeholderWidget(placeholder),
        ),
      );
    }

    return _placeholderWidget(placeholder);
  }

  String get _placeholder {
    if (type == 'frame') return '🖼️';
    if (type == 'title') return '🏆';

    switch (code.isNotEmpty ? code : itemId) {
      case 'fifty_fifty':
      case 'item_5050':
        return '✂️';
      case 'extra_time':
      case 'item_extra_time':
        return '⏱️';
      case 'change_question':
      case 'item_change_q':
        return '🔄';
      default:
        return type == 'help' ? '💡' : '✨';
    }
  }

  Widget _image(Widget image) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: image,
    );
  }

  Widget _placeholderWidget(String icon) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(icon, style: TextStyle(fontSize: size * 0.5)),
    );
  }
}
