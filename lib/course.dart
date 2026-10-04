import 'package:hive_ce/hive.dart';
part 'course.g.dart';

/// A course on the student's list, stored in Hive. Field numbers are
/// permanent.
@HiveType(typeId: 0)
class Course extends HiveObject {
  /// The course title.
  @HiveField(0)
  final String title;

  /// The course code.
  @HiveField(1)
  final String id;

  /// The course credits.
  @HiveField(2)
  final double credits;

  /// The grade code under the Actual profile; see `GradeCode`.
  @HiveField(3)
  final int grade1;

  /// The grade code under the Expected profile.
  @HiveField(4)
  final int grade2;

  /// The discipline code the course was added under, e.g. "B3A7".
  @HiveField(5)
  final String discipline;

  /// The semester label, e.g. "1 - 1".
  @HiveField(6)
  final String sem;

  /// The requirement category tag; see `Elective.tag`.
  @HiveField(7, defaultValue: "CDC")
  final String elective;

  /// Grades for the compare-only profiles 3 to 5, by profile id. A profile
  /// with no entry is ungraded (-2).
  @HiveField(8, defaultValue: <int, int>{})
  final Map<int, int> more;

  Course({
    required this.title,
    required this.sem,
    required this.id,
    required this.grade1,
    required this.grade2,
    required this.discipline,
    required this.credits,
    required this.elective,
    this.more = const {},
  });

  /// The grade under profile [profile] (1 to 5).
  int gradeFor(int profile) => switch (profile) {
    1 => grade1,
    2 => grade2,
    _ => more[profile] ?? -2,
  };

  /// This course with profile [profile]'s grade set to [grade].
  Course withGrade(int profile, int grade) => copyWith(
    grade1: profile == 1 ? grade : null,
    grade2: profile == 2 ? grade : null,
    more: profile > 2 ? {...more, profile: grade} : null,
  );

  /// A new, unstored copy; [more] carries across unless replaced.
  Course copyWith({
    String? sem,
    String? elective,
    double? credits,
    int? grade1,
    int? grade2,
    Map<int, int>? more,
  }) => Course(
    title: title,
    id: id,
    credits: credits ?? this.credits,
    discipline: discipline,
    sem: sem ?? this.sem,
    elective: elective ?? this.elective,
    grade1: grade1 ?? this.grade1,
    grade2: grade2 ?? this.grade2,
    more: more ?? this.more,
  );
}



/// Disciplinary electives by programme code.
var del = {
 "--" : [],
 "A1" : ["BIO G671", "BIOT F245", "BIOT F344", "BITS F415", "BITS F416", "BITS F417", "BITS F418", "BITS F429", "CHE F315", "CHE F411", "CHE F412", "CHE F413", "CHE F414", "CHE F415", "CHE F416", "CHE F417", "CHE F418", "CHE F419", "CHE F421", "CHE F422", "CHE F423", "CHE F424", "CHE F433", "CHE F471", "CHE F497", "CHE F498", "CHE G511", "CHE G512", "CHE G513", "CHE G522", "CHE G523", "CHE G524", "CHE G526", "CHE G527", "CHE G528", "CHE G529", "CHE G532", "CHE G533", "CHE G551", "CHE G552", "CHE G554", "CHE G556", "CHE G557", "CHE G558", "CHE G568", "CHE G613", "CHE G614", "CHE G616", "CHE G617", "CHE G618", "CHE G619", "CHE G620", "CHE G622", "CHE G641", "CHEM F325", "ME F323", "MST G521"],
 "A2" : ["BITS F313", "CE F323", "CE F324", "CE F325", "CE F345", "CE F411", "CE F412", "CE F413", "CE F415", "CE F416", "CE F417", "CE F419", "CE F420", "CE F421", "CE F422", "CE F423", "CE F425", "CE F426", "CE F427", "CE F428", "CE F429", "CE F430", "CE F431", "CE F432", "CE F433", "CE F434", "CE F435"],
 "A3" : ["BITS F312", "BITS F415", "CS F213", "CS F342", "CS F372", "CS F451", "CS G553", "ECE F312", "ECE F343", "EEE F245", "EEE F246", "EEE F312", "EEE F345", "EEE F346", "EEE F348", "EEE F411", "EEE F414", "EEE F416", "EEE F417", "EEE F418", "EEE F422", "EEE F425", "EEE F426", "EEE F427", "EEE F431", "EEE F432", "EEE F433", "EEE F434", "EEE F435", "EEE F436", "EEE F462", "EEE F472", "EEE F473", "EEE F474", "EEE F475", "EEE F476", "EEE F477", "EEE F478", "EEE G512", "EEE G626"],
 "A4" : ["BITS F415", "ECON F411", "ME F411", "ME F412", "ME F218", "ME F413", "ME F415", "ME F416", "ME F417", "ME F418", "ME F419", "ME F420", "ME F432", "ME F433", "ME F441", "ME F443", "ME F451", "ME F452", "ME F461", "ME F472", "ME F482", "ME F483", "ME F484", "ME F485", "MF F485", "MF F421", "DE G513", "DE G514", "DE G531", "ME F423", "ME G511", "ME G512", "ME G514", "ME G515", "ME G533", "ME G534", "MST G522"],
 "A5" : ["BITS F467", "MATH F212", "PHA F316", "PHA F317", "PHA F413", "PHA F414", "PHA F415", "PHA F416", "PHA F417", "PHA F418", "PHA F419", "PHA F422", "PHA F432", "PHA F441", "PHA F442", "PHA F461", "PHA G546"],
 "A7" : ["BITS F311", "BITS F312", "BITS F343", "BITS F364", "BITS F386", "BITS F452", "BITS F453", "BITS F454", "BITS F463", "BITS F464", "BITS F465", "BITS F466", "CS F314", "CS F315", "CS F316", "CS F317", "CS F320", "CS F401", "CS F402", "CS F407", "CS F413", "CS F415", "CS F422", "CS F424", "CS F425", "CS F426", "CS F427", "CS F428", "CS F429", "CS F430", "CS F431", "CS F432", "CS F433", "CS F441", "CS F444", "CS F446", "CS F468", "CS F469", "CS G513", "CS G519", "CS G520", "CS G527", "IS F311", "IS F341", "IS F462", "MATH F231", "MATH F421", "MATH F441"],
 "A8" : ["BITS F312", "BITS F415", "CS F213", "CS F342", "CS F372", "CS F451", "CS G553", "ECE F312", "ECE F314", "EEE F245", "EEE F246", "EEE F311", "EEE F345", "EEE F346", "EEE F348", "EEE F411", "EEE F417", "EEE F422", "EEE F426", "EEE F427", "EEE F431", "EEE F433", "EEE F434", "EEE F435", "EEE F436", "EEE F472", "EEE F474", "EEE F475", "EEE F476", "EEE F477", "EEE F478", "EEE G512", "EEE G626", "INSTR F413", "INSTR F414", "INSTR F415", "INSTR F419", "INSTR F420", "INSTR F422", "INSTR F432", "INSTR F473"],
 "A9" : ["BIOT F242", "BIOT F345", "BIOT F346", "BIOT F347", "BIOT F352", "BIOT F413", "BIOT F416", "BIOT F417", "BIOT F420", "BIOT F422", "BIOT F423", "BIOT F424", "BITS F467"],
 "AA" : ["BITS F415", "BITS F463", "CS F213", "CS F342", "CS F372", "CS F451", "CS G553", "ECE F216", "ECE F312", "ECE F414", "ECE F416", "ECE F418", "ECE F424", "ECE F428", "ECE F431", "ECE F472", "EEE F245", "EEE F246", "EEE F313", "EEE F345", "EEE F346", "EEE F348", "EEE F411", "EEE F417", "EEE F419", "EEE F420", "EEE F422", "EEE F426", "EEE F429", "EEE F430", "EEE F432", "EEE F435", "EEE F436", "EEE F474", "EEE F475", "EEE F476", "EEE F477", "EEE F478", "EEE G512", "EEE G513", "EEE G626", "INSTR F412"],
 "AB" : ["BITS F415", "ECON F411", "ME F411", "ME F412", "ME F413", "ME F415", "ME F416", "ME F417", "ME F418", "ME F419", "ME F420", "ME F432", "ME F433", "ME F441", "ME F443", "ME F451", "ME F452", "ME F461", "ME F472", "ME F482", "ME F483", "ME F484", "ME F485", "MF F485", "MF F421", "DE G513", "DE G514", "DE G531", "ME F423", "ME G511", "ME G512", "ME G514", "ME G515", "ME G533", "ME G534", "MST G522"],
 "AC" : ["BITS F312", "BITS F327", "BITS F343", "BITS F364", "BITS F441", "BITS F452", "BITS F459", "CS F212", "CS F315", "CS F316", "CS F321", "CS F322", "CS F407", "CS F413", "CS F422", "CS F424", "CS F427", "CS F434", "CS F435", "CS F437", "CS F446", "CS G513", "CS G514", "CS G527", "CS G553", "CS G557", "EEE F245", "EEE F311", "EEE F341", "EEE F348", "EEE F411", "EEE F417", "EEE F422", "EEE F432", "EEE F434", "EEE F435", "EEE G512", "EEE G513", "IS F311", "IS F341", "MEL G621"],
 "AD" : ["BITS F311", "BITS F316", "BITS F386", "BITS F463", "BITS F464", "CS F212", "CS F402", "CS F407", "CS F415", "CS F422", "CS F425", "CS F426", "CS G513", "ECON F354", "IS F311", "MAC F266", "MAC F366", "MAC F367", "MAC F376", "MAC F377", "MAC F411", "MAC F491", "MATH F243", "MATH F315", "MATH F424", "MATH F425", "MATH F426", "MATH F428"],
 "AJ" : [],
 "B1" : ["BIO F216", "BIO F217", "BIO F231", "BIO F314", "BIO F315", "BIO F352", "BIO F411", "BIO F413", "BIO F417", "BIO F418", "BIO F419", "BIO F421", "BIO F431", "BIO F441", "BIO F451", "BIO G512", "BIO G513", "BIO G515", "BIO G522", "BIO G523", "BIO G524", "BIO G525", "BIO G526", "BIO G544", "BIO G545", "BIO G561", "BIO G570", "BIO G612", "BIO G631", "BIO G632", "BIO G642", "BIO G643", "BIO G651", "BIO G661", "BIO G671", "BIOT F345", "BIOT F346", "BIOT F347", "BIOT F416", "BIOT F422", "BIOT F424", "BITS F418", "BITS F467", "CHEM F212", "CHEM F213", "MATH F212"],
 "B2" : ["CHEM F223", "CHEM F320", "CHEM F323", "CHEM F324", "CHEM F325", "CHEM F326", "CHEM F327", "CHEM F328", "CHEM F329", "CHEM F330", "CHEM F333", "CHEM F334", "CHEM F335", "CHEM F336", "CHEM F337", "CHEM F412", "CHEM F413", "CHEM F414", "CHEM F415", "CHEM F416", "CHEM F422", "CHEM F423", "CHEM F430", "CHEM F431", "CHEM G521"],
 "B3" : ["ECON F215", "BITS F314", "ECON F315", "ECON F314", "ECON F345", "ECON F351", "ECON F352", "ECON F353", "ECON F354", "ECON F355", "ECON F356", "ECON F357", "ECON F411", "ECON F412", "ECON F413", "ECON F414", "ECON F415", "ECON F417", "ECON F418", "ECON F419", "ECON F420", "ECON F422", "ECON F434", "ECON F435", "ECON F471", "FIN F314", "FIN F414", "MATH F212", "MATH F242", "MATH F424"],
 "B4" : ["BITS F314", "BITS F343", "BITS F463", "CS F211", "BITS F232", "CS F364", "MATH F231", "MATH F314", "MATH F315", "MATH F316", "MATH F317", "MATH F353", "MATH F354", "MATH F378", "MATH F420", "MATH F421", "MATH F422", "MATH F423", "MATH F424", "MATH F425", "MATH F426", "MATH F427", "MATH F428", "MATH F431", "MATH F432", "MATH F441", "MATH F444", "MATH F445", "MATH F456", "MATH F471", "MATH F481", "MATH F492"],
 "B5" : ["BIO F215", "BITS F316", "BITS F317", "BITS F386", "BITS F416", "BITS F417", "BITS F446", "EEE F426", "MATH F424", "MATH F456", "PHY F215", "PHY F315", "PHY F316", "PHY F317", "PHY F346", "PHY F378", "PHY F379", "PHY F412", "PHY F413", "PHY F414", "PHY F415", "PHY F416", "PHY F417", "PHY F418", "PHY F419", "PHY F420", "PHY F421", "PHY F422", "PHY F423", "PHY F424", "PHY F425", "PHY F426", "PHY F427", "PHY F428", "PHY F431", "PHY F432", "PHY F433", "PHY F434"],
 "B7" : ["SNS F211","SNS F212","SNS F213","SNS F241","SNS F242","SNS F243","SNS F311","SNS F312","SNS F313","SNS F341","SNS F342","SNS F343"],
};
/// Humanity electives outside the HSS and GS prefixes.
var huel = ["BITS F214","BITS F226","BITS F385","BITS F399","BITS F419"];
/// Courses that count in no requirement category.
var nonelist =["ECON F211", "MGTS F211", "BITS F225","MATH F101","BITS F112",'BITS F111','BIO F101','BITS F103','BITS K101','BITS F101','MATH F102','MATH F113','BITS F102','CHEM F101','CS F111','PHA F214','PHA F216','MATH F114',"MATH F101", "BITS F112", "BITS F111", "BIO F101", "BITS F103", "BITS K101", "BITS F101", "MATH F102", "MATH F113", "PHY F101", "EEE F111", "CS F111", "BITS F102", "CHEM F101", "PHA F214", "PHA F216", "PHY F102", "BITS F113", "MATH F114"];