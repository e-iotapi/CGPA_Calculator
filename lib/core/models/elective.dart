/// The requirement category a course counts toward. [tag] is the string
/// stored on `Course.elective` and in the master course list; never change it.
enum Elective {
  cdc1('CDC1'),
  cdc2('CDC2'),
  del1('Disciplinary Elective1'),
  del2('Disciplinary Elective2'),
  humanity('Humanity Elective'),
  open('Open Elective');

  const Elective(this.tag);
  final String tag;

  static Elective? fromTag(String tag) =>
      values.where((e) => e.tag == tag).firstOrNull;
}
