// packages/core/lib/domain/entities/script.dart

import 'package:flutter/material.dart';

class Script {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ScriptSettings settings;
  final List<ScriptMarker> markers;
  final Map<String, dynamic>? metadata;
  
  Script({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.settings,
    this.markers = const [],
    this.metadata,
  });
  
  // Calculate estimated read time based on average reading speed
  Duration get estimatedReadTime {
    const averageWPM = 150; // Average teleprompter reading speed
    final minutes = wordCount / averageWPM;
    return Duration(minutes: minutes.ceil());
  }
  
  int get wordCount {
    return content.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
  }
  
  int get characterCount => content.length;
  
  Script copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    ScriptSettings? settings,
    List<ScriptMarker>? markers,
    Map<String, dynamic>? metadata,
  }) {
    return Script(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      settings: settings ?? this.settings,
      markers: markers ?? this.markers,
      metadata: metadata ?? this.metadata,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'settings': settings.toJson(),
      'markers': markers.map((m) => m.toJson()).toList(),
      'metadata': metadata,
    };
  }
  
  factory Script.fromJson(Map<String, dynamic> json) {
    return Script(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      settings: ScriptSettings.fromJson(json['settings']),
      markers: (json['markers'] as List?)
          ?.map((m) => ScriptMarker.fromJson(m))
          .toList() ?? [],
      metadata: json['metadata'],
    );
  }
}

class ScriptSettings {
  final double fontSize;
  final String fontFamily;
  final Color textColor;
  final Color backgroundColor;
  final TextAlign textAlign;
  final double lineHeight;
  final EdgeInsets padding;
  final bool mirrorMode;
  final bool showGuide;
  final double guidePosition;
  final Color guideColor;
  final double scrollSpeed;
  
  ScriptSettings({
    this.fontSize = 24.0,
    this.fontFamily = 'Roboto',
    this.textColor = Colors.white,
    this.backgroundColor = Colors.black,
    this.textAlign = TextAlign.center,
    this.lineHeight = 1.5,
    this.padding = const EdgeInsets.all(20),
    this.mirrorMode = false,
    this.showGuide = true,
    this.guidePosition = 0.3,
    this.guideColor = Colors.red,
    this.scrollSpeed = 2.0,
  });
  
  TextStyle get textStyle => TextStyle(
    fontSize: fontSize,
    fontFamily: fontFamily,
    color: textColor,
    height: lineHeight,
  );
  
  Map<String, dynamic> toJson() {
    return {
      'fontSize': fontSize,
      'fontFamily': fontFamily,
      'textColor': textColor.value,
      'backgroundColor': backgroundColor.value,
      'textAlign': textAlign.index,
      'lineHeight': lineHeight,
      'padding': {
        'left': padding.left,
        'top': padding.top,
        'right': padding.right,
        'bottom': padding.bottom,
      },
      'mirrorMode': mirrorMode,
      'showGuide': showGuide,
      'guidePosition': guidePosition,
      'guideColor': guideColor.value,
      'scrollSpeed': scrollSpeed,
    };
  }
  
  factory ScriptSettings.fromJson(Map<String, dynamic> json) {
    return ScriptSettings(
      fontSize: json['fontSize']?.toDouble() ?? 24.0,
      fontFamily: json['fontFamily'] ?? 'Roboto',
      textColor: Color(json['textColor'] ?? Colors.white.value),
      backgroundColor: Color(json['backgroundColor'] ?? Colors.black.value),
      textAlign: TextAlign.values[json['textAlign'] ?? 1],
      lineHeight: json['lineHeight']?.toDouble() ?? 1.5,
      padding: EdgeInsets.fromLTRB(
        json['padding']?['left']?.toDouble() ?? 20,
        json['padding']?['top']?.toDouble() ?? 20,
        json['padding']?['right']?.toDouble() ?? 20,
        json['padding']?['bottom']?.toDouble() ?? 20,
      ),
      mirrorMode: json['mirrorMode'] ?? false,
      showGuide: json['showGuide'] ?? true,
      guidePosition: json['guidePosition']?.toDouble() ?? 0.3,
      guideColor: Color(json['guideColor'] ?? Colors.red.value),
      scrollSpeed: json['scrollSpeed']?.toDouble() ?? 2.0,
    );
  }
  
  ScriptSettings copyWith({
    double? fontSize,
    String? fontFamily,
    Color? textColor,
    Color? backgroundColor,
    TextAlign? textAlign,
    double? lineHeight,
    EdgeInsets? padding,
    bool? mirrorMode,
    bool? showGuide,
    double? guidePosition,
    Color? guideColor,
    double? scrollSpeed,
  }) {
    return ScriptSettings(
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      textColor: textColor ?? this.textColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textAlign: textAlign ?? this.textAlign,
      lineHeight: lineHeight ?? this.lineHeight,
      padding: padding ?? this.padding,
      mirrorMode: mirrorMode ?? this.mirrorMode,
      showGuide: showGuide ?? this.showGuide,
      guidePosition: guidePosition ?? this.guidePosition,
      guideColor: guideColor ?? this.guideColor,
      scrollSpeed: scrollSpeed ?? this.scrollSpeed,
    );
  }
}

class ScriptMarker {
  final String id;
  final int position; // Character position in content
  final String label;
  final MarkerType type;
  final Color? color;
  
  ScriptMarker({
    required this.id,
    required this.position,
    required this.label,
    this.type = MarkerType.general,
    this.color,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'position': position,
      'label': label,
      'type': type.name,
      'color': color?.value,
    };
  }
  
  factory ScriptMarker.fromJson(Map<String, dynamic> json) {
    return ScriptMarker(
      id: json['id'],
      position: json['position'],
      label: json['label'],
      type: MarkerType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => MarkerType.general,
      ),
      color: json['color'] != null ? Color(json['color']) : null,
    );
  }
}

enum MarkerType { general, pause, emphasis, cue, section }

// Repository interface
abstract class ScriptRepository {
  Future<List<Script>> getAllScripts();
  Future<Script?> getScript(String id);
  Future<Script> createScript(ScriptData data);
  Future<Script> updateScript(String id, ScriptData data);
  Future<void> deleteScript(String id);
  Stream<List<Script>> watchScripts();
  Future<List<Script>> searchScripts(String query);
  Future<void> importScript(String filePath);
  Future<void> exportScript(String id, String filePath);
}

class ScriptData {
  final String title;
  final String content;
  final ScriptSettings? settings;
  final List<ScriptMarker>? markers;
  final Map<String, dynamic>? metadata;
  
  ScriptData({
    required this.title,
    required this.content,
    this.settings,
    this.markers,
    this.metadata,
  });
}