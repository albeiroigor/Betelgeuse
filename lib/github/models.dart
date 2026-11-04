import 'package:flutter/material.dart' show Color;

class GithubUser {
  final String id, login;
  final String? name, avatarUrl, bio;

  const GithubUser({
    required this.id,
    required this.login,
    this.name,
    this.avatarUrl,
    this.bio,
  });

  String get displayName =>
      name?.trim().isNotEmpty == true ? name!.trim() : login;
}

class Proj {
  final String id, title, owner;
  final String? url;
  const Proj(this.id, this.title, this.owner, {this.url});
}

enum FieldKind { singleSelect, iteration, number, other }

class ProjectField {
  final String id, name;
  final FieldKind kind;
  final List<Option> options;

  const ProjectField(this.id, this.name, this.kind, {this.options = const []});

  bool get groupable => options.isNotEmpty;
}

class Option {
  final String id, name;
  final DateTime? start;
  final int? duration;

  const Option(this.id, this.name, {this.start, this.duration});

  bool get isCurrent {
    final from = start;
    final days = duration;
    if (from == null || days == null) return false;
    final now = DateTime.now();
    return !now.isBefore(from) && now.isBefore(from.add(Duration(days: days)));
  }
}

class Label {
  final String name, color;
  final String? id;

  const Label(this.name, this.color, {this.id});

  Color get swatch => Color(int.tryParse('FF$color', radix: 16) ?? 0xFF8B949E);
}

class Milestone {
  final String id, title;

  const Milestone(this.id, this.title);
}

class Item {
  final String id, ref, kind;
  final String? url, avatar, cid;
  final String? createdAt, updatedAt;
  final int? number;
  final int? commentCount;
  final double? estimate;
  final bool hidden;
  List<Label> labels;

  String title;
  String? state;
  List<String> assignees;
  final String? checksState;
  String? optionId;

  Item(
    this.id,
    this.title,
    this.ref,
    this.kind,
    this.state,
    this.url,
    this.avatar,
    this.labels,
    this.optionId,
    this.cid,
    this.hidden, {
    this.assignees = const [],
    this.checksState,
    this.createdAt,
    this.updatedAt,
    this.number,
    this.commentCount,
    this.estimate,
  });

  bool get isDraft => kind == 'DraftIssue';
  bool get canComment => cid != null && !hidden && !isDraft;
}

class Board {
  final String id;
  final String fieldId;
  final String fieldName;
  final FieldKind fieldKind;
  final List<Option> options;
  final List<Item> items;
  final List<ProjectField> fields;
  final ProjectField? estimateField;
  final int totalItems;

  const Board({
    required this.id,
    required this.fieldId,
    required this.fieldName,
    required this.fieldKind,
    required this.options,
    required this.items,
    this.fields = const [],
    this.estimateField,
    this.totalItems = 0,
  });

  Option? get currentIteration =>
      options.where((option) => option.isCurrent).firstOrNull;
}
