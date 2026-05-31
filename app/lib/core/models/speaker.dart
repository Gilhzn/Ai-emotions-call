/// The two diarized speakers. A = sales rep/seller, B = customer/prospect.
enum Speaker {
  a,
  b;

  String get wire => this == Speaker.a ? 'A' : 'B';

  String get label => this == Speaker.a ? 'נציג (A)' : 'לקוח (B)';

  static Speaker fromWire(String? s) => s == 'B' ? Speaker.b : Speaker.a;
}
