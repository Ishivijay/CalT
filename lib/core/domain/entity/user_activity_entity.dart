import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/data/data_source/user_activity_dbo.dart';
import 'package:opennutritracker/core/domain/entity/physical_activity_entity.dart';

class UserActivityEntity extends Equatable {
  final String id;
  final double duration;
  final double burnedKcal;
  final DateTime date;

  final PhysicalActivityEntity physicalActivityEntity;

  /// Optional direct kcal value entered by the user for a Custom activity.
  /// When set, this is the source of truth and [burnedKcal] mirrors it so
  /// the aggregation layer (which sums [burnedKcal] across the day) keeps
  /// working unchanged. See `UserActivityDBO.userKcal` for the persistence
  /// reasoning.
  final double? userKcal;

  /// Provenance — 'manual', 'healthConnect', or 'shared'.
  final String source;

  /// Health Connect record UID for dedup on re-sync. Null for manual/shared.
  final String? externalId;

  const UserActivityEntity(
    this.id,
    this.duration,
    this.burnedKcal,
    this.date,
    this.physicalActivityEntity, {
    this.userKcal,
    this.source = 'manual',
    this.externalId,
  });

  factory UserActivityEntity.fromUserActivityDBO(UserActivityDBO activityDBO) {
    return UserActivityEntity(
      activityDBO.id,
      activityDBO.duration,
      activityDBO.burnedKcal,
      activityDBO.date,
      PhysicalActivityEntity.fromPhysicalActivityDBO(
        activityDBO.physicalActivityDBO,
      ),
      userKcal: activityDBO.userKcal,
      source: activityDBO.source,
      externalId: activityDBO.externalId,
    );
  }

  /// The kcal value to display and aggregate for this activity. Prefers
  /// the user-entered or Health-Connect-sourced value when present,
  /// otherwise falls back to the MET-computed [burnedKcal].
  double get effectiveBurnedKcal => userKcal ?? burnedKcal;

  @override
  List<Object?> get props => [
    id,
    duration,
    burnedKcal,
    date,
    userKcal,
    source,
    externalId,
  ];

  static IconData getIconData() => Icons.directions_run_outlined;
}
