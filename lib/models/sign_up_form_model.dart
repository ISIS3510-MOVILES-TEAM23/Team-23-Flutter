class SignUpForm {
  final String email;
  final String password;
  final String name;
  final String? major;

  SignUpForm({
    required this.email,
    required this.password,
    required this.name,
    this.major,
  });
}

