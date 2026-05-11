import 'user_model.dart';

class AuthResponseModel {
  final String token;
  final UserModel user;

  const AuthResponseModel({
    required this.token,
    required this.user,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      token: json['token'] as String? ?? '',
      user: UserModel.fromJson(
        json['user'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}
