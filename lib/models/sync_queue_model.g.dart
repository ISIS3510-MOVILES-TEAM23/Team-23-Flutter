// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_queue_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SyncQueueItemAdapter extends TypeAdapter<SyncQueueItem> {
  @override
  final int typeId = 0;

  @override
  SyncQueueItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SyncQueueItem(
      operationId: fields[0] as String,
      type: fields[1] as String,
      payload: (fields[2] as Map).cast<String, dynamic>(),
      retryCount: fields[3] as int,
      createdAt: fields[4] as DateTime,
      lastAttemptAt: fields[5] as DateTime?,
      errorMessage: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SyncQueueItem obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.operationId)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.payload)
      ..writeByte(3)
      ..write(obj.retryCount)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.lastAttemptAt)
      ..writeByte(6)
      ..write(obj.errorMessage);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncQueueItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
