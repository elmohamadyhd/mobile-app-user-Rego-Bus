import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:safaria/core/network/dio_client.dart';
import 'package:safaria/features/profile/data/profile_api.dart';
import 'package:safaria/features/profile/data/profile_repository_impl.dart';
import 'package:safaria/features/profile/domain/repositories/profile_repository.dart';

final profileApiProvider =
    Provider<ProfileApi>((ref) => ProfileApi(ref.watch(dioProvider)));

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepositoryImpl(ref.watch(profileApiProvider)),
);
